import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/friendship_models.dart';
import '../../../data/repositories/friendship_repository.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class MultiplayerInviteDialog extends StatefulWidget {
  final String quizId;
  final String quizTitle;
  final bool shuffle;

  const MultiplayerInviteDialog({
    super.key,
    required this.quizId,
    required this.quizTitle,
    this.shuffle = false,
  });

  @override
  State<MultiplayerInviteDialog> createState() => _MultiplayerInviteDialogState();
}

enum InviteState { selecting, waiting, starting, cancelled }

class _MultiplayerInviteDialogState extends State<MultiplayerInviteDialog> {
  InviteState _inviteState = InviteState.selecting;
  bool _isLoadingFriends = true;
  List<UserProfile> _availableFriends = [];
  final Set<UserProfile> _selectedFriends = {};
  
  String? _challengeId;
  int _inviteSecondsRemaining = 10;
  int _startSecondsRemaining = 3;
  Timer? _countdownTimer;
  RealtimeChannel? _playersChannel;
  List<Map<String, dynamic>> _playerStatuses = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableFriends();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _unsubscribePlayers();
    super.dispose();
  }

  Future<void> _loadAvailableFriends() async {
    try {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null) return;

      final friends = await context.read<FriendshipRepository>().getFriends();
      final friendIds = friends.map((f) => f.id).toList();

      if (friendIds.isEmpty) {
        if (mounted) {
          setState(() {
            _availableFriends = [];
            _isLoadingFriends = false;
          });
        }
        return;
      }

      // Query database for recent presence
      final response = await client
          .from('profiles')
          .select('*')
          .inFilter('id', friendIds);

      final now = DateTime.now().toUtc();
      final filtered = (response as List).map((e) => UserProfile.fromJson(e)).where((profile) {
        final rawRow = response.firstWhere((r) => r['id'] == profile.id);
        final lastSeenStr = rawRow['last_seen_at'] as String?;
        final isPlaying = rawRow['is_playing'] as bool? ?? false;

        if (lastSeenStr == null || isPlaying) return false;

        final lastSeen = DateTime.parse(lastSeenStr).toUtc();
        final diffSeconds = now.difference(lastSeen).inSeconds.abs();
        
        // Online if seen in the last 20 seconds
        return diffSeconds <= 20;
      }).toList();

      if (mounted) {
        setState(() {
          _availableFriends = filtered;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading available friends: $e');
      if (mounted) {
        setState(() => _isLoadingFriends = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load friends: $e')),
        );
      }
    }
  }

  Future<void> _sendChallenge() async {
    if (_selectedFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one friend to invite.')),
      );
      return;
    }

    setState(() {
      _inviteState = InviteState.waiting;
    });

    try {
      final client = Supabase.instance.client;
      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // 1. Create quiz_challenges row
      final challenge = await client.from('quiz_challenges').insert({
        'quiz_id': widget.quizId,
        'host_id': currentUserId,
        'status': 'pending',
        'shuffle': widget.shuffle,
      }).select().single();

      _challengeId = challenge['id'] as String;

      // 2. Insert host + invited players
      final List<Map<String, dynamic>> playersToInsert = [];
      playersToInsert.add({
        'challenge_id': _challengeId,
        'user_id': currentUserId,
        'status': 'accepted', // Host is pre-accepted
      });

      for (var f in _selectedFriends) {
        playersToInsert.add({
          'challenge_id': _challengeId,
          'user_id': f.id,
          'status': 'pending',
        });
      }

      await client.from('quiz_challenge_players').insert(playersToInsert);

      // Initialize status tracking
      _playerStatuses = _selectedFriends.map((f) => {
        'name': f.name,
        'status': 'pending',
        'id': f.id,
      }).toList();

      // 3. Subscribe to realtime updates on players
      _subscribePlayers();

      // 4. Start 10 seconds timer
      _startInviteTimer();
    } catch (e) {
      debugPrint('Error creating challenge: $e');
      if (mounted) {
        setState(() => _inviteState = InviteState.selecting);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send challenge: $e')),
        );
      }
    }
  }

  void _subscribePlayers() {
    final client = Supabase.instance.client;
    _playersChannel = client.channel('public:quiz_challenge_players:challenge_${_challengeId!}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'quiz_challenge_players',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'challenge_id',
          value: _challengeId!,
        ),
        callback: (payload) {
          final updatedUserId = payload.newRecord['user_id'] as String;
          final newStatus = payload.newRecord['status'] as String;

          setState(() {
            for (var p in _playerStatuses) {
              if (p['id'] == updatedUserId) {
                p['status'] = newStatus;
              }
            }
          });
        },
      )
      ..subscribe();
  }

  void _unsubscribePlayers() {
    if (_playersChannel != null) {
      Supabase.instance.client.removeChannel(_playersChannel!);
      _playersChannel = null;
    }
  }

  void _startInviteTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_inviteSecondsRemaining > 1) {
        setState(() {
          _inviteSecondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
        await _finalizeInvitations();
      }
    });
  }

  Future<void> _finalizeInvitations() async {
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null || _challengeId == null) return;

    try {
      // 1. Timeout any player still pending
      await client
          .from('quiz_challenge_players')
          .update({'status': 'timeout'})
          .eq('challenge_id', _challengeId!)
          .eq('status', 'pending');

      // 2. Query actual accepted players
      final playersResponse = await client
          .from('quiz_challenge_players')
          .select('*, profiles!user_id(name)')
          .eq('challenge_id', _challengeId!);

      final acceptedPlayers = (playersResponse as List)
          .where((p) => p['status'] == 'accepted')
          .toList();

      // At least 2 players are needed (Host + at least 1 friend)
      if (acceptedPlayers.length > 1) {
        await client
            .from('quiz_challenges')
            .update({'status': 'started'})
            .eq('id', _challengeId!);

        setState(() {
          _inviteState = InviteState.starting;
        });
        _startQuizTimer();
      } else {
        // Cancel challenge
        await client
            .from('quiz_challenges')
            .update({'status': 'cancelled'})
            .eq('id', _challengeId!);

        setState(() {
          _inviteState = InviteState.cancelled;
        });
      }
    } catch (e) {
      debugPrint('Error finalizing invitations: $e');
    }
  }

  void _startQuizTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSecondsRemaining > 1) {
        setState(() {
          _startSecondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
        _unsubscribePlayers();

        if (mounted) {
          Navigator.of(context).pop(); // Close dialog
          context.pushReplacement('/quiz/${widget.quizId}/take?challengeId=$_challengeId');
        }
      }
    });
  }

  Future<void> _cancelChallenge() async {
    _countdownTimer?.cancel();
    _unsubscribePlayers();

    if (_challengeId != null) {
      try {
        await Supabase.instance.client
            .from('quiz_challenges')
            .update({'status': 'cancelled'})
            .eq('id', _challengeId!);
      } catch (e) {
        debugPrint('Error cancelling challenge: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildSelectingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Invite online and available friends to join you in this quiz challenge!',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (_isLoadingFriends)
          const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
        else if (_availableFriends.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: const Column(
              children: [
                Icon(Icons.people_outline_rounded, color: Colors.grey, size: 40),
                SizedBox(height: 12),
                Text(
                  'No friends are currently online and free.',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Column(
                children: _availableFriends.map((friend) {
                  final isSelected = _selectedFriends.contains(friend);
                  return CheckboxListTile(
                    title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(friend.email, style: const TextStyle(fontSize: 12)),
                    value: isSelected,
                    activeColor: Colors.deepPurple,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedFriends.add(friend);
                        } else {
                          _selectedFriends.remove(friend);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWaitingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              'Waiting for responses: $_inviteSecondsRemaining s',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Invitation status:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._playerStatuses.map((p) {
          IconData icon;
          Color color;
          switch (p['status']) {
            case 'accepted':
              icon = Icons.check_circle_rounded;
              color = Colors.green;
              break;
            case 'rejected':
              icon = Icons.cancel_rounded;
              color = Colors.red;
              break;
            case 'timeout':
              icon = Icons.hourglass_disabled_rounded;
              color = Colors.grey;
              break;
            default:
              icon = Icons.hourglass_top_rounded;
              color = Colors.orange;
          }
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text(
              (p['status'] as String).toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStartingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
        const SizedBox(height: 16),
        const Text(
          'Challenge Accepted!',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          'Starting quiz in $_startSecondsRemaining...',
          style: const TextStyle(fontSize: 16, color: Colors.deepPurple, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCancelledView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
        const SizedBox(height: 16),
        const Text(
          'Challenge Cancelled',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nobody accepted your quiz invitation.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String title;
    List<Widget> actions = [];
    Widget body;

    switch (_inviteState) {
      case InviteState.selecting:
        title = 'Invite Friends';
        body = _buildSelectingView();
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _selectedFriends.isEmpty ? null : _sendChallenge,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            child: const Text('Send Challenge'),
          ),
        ];
        break;
      case InviteState.waiting:
        title = 'Challenging Players';
        body = _buildWaitingView();
        actions = [
          TextButton(
            onPressed: _cancelChallenge,
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Cancel Challenge'),
          ),
        ];
        break;
      case InviteState.starting:
        title = 'Starting Quiz';
        body = _buildStartingView();
        break;
      case InviteState.cancelled:
        title = 'No Competitors';
        body = _buildCancelledView();
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ];
        break;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: body,
      actions: actions,
      actionsAlignment: MainAxisAlignment.end,
    );
  }
}
