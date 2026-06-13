import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/app_router.dart';

class ChallengeInvitationDialog extends StatefulWidget {
  final String challengeId;
  final String hostName;
  final String quizTitle;
  final String quizId;
  final bool shuffle;

  const ChallengeInvitationDialog({
    super.key,
    required this.challengeId,
    required this.hostName,
    required this.quizTitle,
    required this.quizId,
    this.shuffle = false,
  });

  @override
  State<ChallengeInvitationDialog> createState() => _ChallengeInvitationDialogState();
}

class _ChallengeInvitationDialogState extends State<ChallengeInvitationDialog> {
  int _secondsRemaining = 10;
  Timer? _timer;
  bool _isResponding = false;
  bool _accepted = false;
  RealtimeChannel? _statusChannel;
  int _startSecondsRemaining = 3;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _unsubscribeChallengeStatus();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        _handleTimeout();
      }
    });
  }

  Future<void> _handleTimeout() async {
    if (_isResponding || _accepted) return;
    setState(() => _isResponding = true);
    
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client
            .from('quiz_challenge_players')
            .update({'status': 'timeout'})
            .eq('challenge_id', widget.challengeId)
            .eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('Error setting timeout status: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _respond(bool accept) async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    _timer?.cancel();

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client
          .from('quiz_challenge_players')
          .update({'status': accept ? 'accepted' : 'rejected'})
          .eq('challenge_id', widget.challengeId)
          .eq('user_id', userId);

      if (accept) {
        setState(() {
          _accepted = true;
          _isResponding = false;
        });
        _subscribeChallengeStatus();
      } else {
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error responding to challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to respond: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _subscribeChallengeStatus() {
    final client = Supabase.instance.client;
    
    _statusChannel = client.channel('public:quiz_challenges:status_${widget.challengeId}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'quiz_challenges',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: widget.challengeId,
        ),
        callback: (payload) {
          final newStatus = payload.newRecord['status'] as String;
          if (newStatus == 'started') {
            _unsubscribeChallengeStatus();
            if (mounted) {
              setState(() {
                _starting = true;
              });
              _startQuizTimer();
            }
          } else if (newStatus == 'cancelled') {
            _unsubscribeChallengeStatus();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Challenge cancelled by host.')),
              );
              Navigator.of(context).pop();
            }
          }
        },
      )
      ..subscribe();
  }

  void _startQuizTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startSecondsRemaining > 1) {
        setState(() {
          _startSecondsRemaining--;
        });
      } else {
        _timer?.cancel();
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog
          appRouter.go('/quiz/${widget.quizId}/take?challengeId=${widget.challengeId}');
        }
      }
    });
  }

  void _unsubscribeChallengeStatus() {
    if (_statusChannel != null) {
      Supabase.instance.client.removeChannel(_statusChannel!);
      _statusChannel = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Joining Challenge!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flash_on, color: Colors.amber, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Get Ready!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Starting quiz in $_startSecondsRemaining...',
              style: const TextStyle(fontSize: 16, color: Colors.deepPurple, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (_accepted) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Invitation Accepted'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 16),
            Text(
              'Waiting for host to start the quiz...',
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.flash_on, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(child: Text('Quiz Challenge!')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.hostName} has challenged you to play:',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            widget.quizTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple),
            textAlign: TextAlign.center,
          ),
          if (widget.shuffle) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shuffle, size: 16, color: Colors.deepPurple),
                  SizedBox(width: 6),
                  Text(
                    'Shuffle Questions Mode is ON',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, color: Colors.redAccent, size: 20),
              const SizedBox(width: 6),
              Text(
                'Responding in $_secondsRemaining seconds...',
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        OutlinedButton(
          onPressed: _isResponding ? null : () => _respond(false),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.redAccent),
            foregroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Reject'),
        ),
        ElevatedButton(
          onPressed: _isResponding ? null : () => _respond(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
