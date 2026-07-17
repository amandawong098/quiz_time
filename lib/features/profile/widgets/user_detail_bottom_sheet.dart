import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/models/quiz_models.dart';
import '../../learn/models/lesson_models.dart';
import '../../learn/models/flashcard_models.dart';
import '../../../data/models/friendship_models.dart';
import '../../../data/repositories/friendship_repository.dart';

class UserDetailBottomSheet extends StatefulWidget {
  final String userId;
  final String initialName;
  final String? initialAvatarUrl;

  const UserDetailBottomSheet({
    super.key,
    required this.userId,
    required this.initialName,
    this.initialAvatarUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String name,
    String? avatarUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserDetailBottomSheet(
        userId: userId,
        initialName: name,
        initialAvatarUrl: avatarUrl,
      ),
    );
  }

  @override
  State<UserDetailBottomSheet> createState() => _UserDetailBottomSheetState();
}

class _UserDetailBottomSheetState extends State<UserDetailBottomSheet> {
  bool _isLoading = true;
  UserProfile? _profile;
  List<LessonCourse> _courses = [];
  List<Quiz> _quizzes = [];
  List<FlashcardDeck> _decks = [];
  String? _friendshipStatus; // 'none', 'friends', 'sent_pending', 'received_pending'
  bool _isFriendshipActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;

      // Fetch profile and all contributions in parallel
      final List<Future<dynamic>> futures = [
        supabase.from('profiles').select('*').eq('id', widget.userId).single(),
        supabase.from('lesson_courses').select('*').eq('creator_id', widget.userId).order('created_at', ascending: false),
        supabase.from('quizzes').select('*').eq('creator_id', widget.userId).order('created_at', ascending: false),
        supabase.from('flashcard_decks').select('*').eq('creator_id', widget.userId).order('created_at', ascending: false),
      ];

      // Only query friendship status if we are looking at someone else's profile
      if (currentUserId != null && currentUserId != widget.userId) {
        futures.add(
          supabase
              .from('friendships')
              .select('*')
              .or('and(sender_id.eq.$currentUserId,receiver_id.eq.${widget.userId}),and(sender_id.eq.${widget.userId},receiver_id.eq.$currentUserId)')
              .maybeSingle()
        );
      }

      final results = await Future.wait(futures);

      String? friendshipStatus;
      if (currentUserId != null && currentUserId != widget.userId && results.length > 4) {
        final friendshipResult = results[4] as Map<String, dynamic>?;
        if (friendshipResult == null) {
          friendshipStatus = 'none';
        } else {
          final status = friendshipResult['status'] as String;
          final senderId = friendshipResult['sender_id'] as String;
          if (status == 'accepted') {
            friendshipStatus = 'friends';
          } else if (status == 'pending') {
            if (senderId == currentUserId) {
              friendshipStatus = 'sent_pending';
            } else {
              friendshipStatus = 'received_pending';
            }
          } else {
            friendshipStatus = 'none';
          }
        }
      } else {
        friendshipStatus = null; // viewing own profile
      }

      if (mounted) {
        setState(() {
          _profile = UserProfile.fromJson(results[0] as Map<String, dynamic>);
          _courses = (results[1] as List).map((c) => LessonCourse.fromJson(c as Map<String, dynamic>)).toList();
          _quizzes = (results[2] as List).map((q) => Quiz.fromJson(q as Map<String, dynamic>)).toList();
          _decks = (results[3] as List).map((d) => FlashcardDeck.fromJson(d as Map<String, dynamic>)).toList();
          _friendshipStatus = friendshipStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user profile: $e')),
        );
      }
    }
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsList() {
    if (_courses.isEmpty) {
      return _buildEmptyState('No created lessons', Icons.menu_book_rounded);
    }
    return ListView.builder(
      itemCount: _courses.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final course = _courses[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.blue, size: 20),
          ),
          title: Text(course.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: course.description != null
              ? Text(course.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))
              : null,
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
          onTap: () {
            Navigator.pop(context); // Close bottom sheet
            context.push('/?selectedCourseId=${course.id}');
          },
        );
      },
    );
  }

  Widget _buildQuizzesList() {
    if (_quizzes.isEmpty) {
      return _buildEmptyState('No created quizzes', Icons.assignment_turned_in_rounded);
    }
    return ListView.builder(
      itemCount: _quizzes.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final quiz = _quizzes[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.assignment_turned_in_rounded, color: Colors.amber.shade900, size: 20),
          ),
          title: Text(quiz.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('${quiz.questionCount} Questions', style: const TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
          onTap: () {
            Navigator.pop(context); // Close bottom sheet
            context.push('/quiz/${quiz.id}');
          },
        );
      },
    );
  }

  Widget _buildDecksList() {
    if (_decks.isEmpty) {
      return _buildEmptyState('No created flashcard decks', Icons.style_rounded);
    }
    return ListView.builder(
      itemCount: _decks.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final deck = _decks[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.style_rounded, color: Colors.deepPurple, size: 20),
          ),
          title: Text(deck.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('${deck.cardCount} Cards', style: const TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
          onTap: () {
            Navigator.pop(context); // Close bottom sheet
            context.push('/flashcard-deck/${deck.id}/details');
          },
        );
      },
    );
  }

  Widget _buildFriendshipSection() {
    if (_friendshipStatus == null) {
      return const SizedBox.shrink(); // Viewing own profile, or not loaded yet
    }

    if (_isFriendshipActionLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final repo = context.read<FriendshipRepository>();

    Future<void> handleAction(Future<void> Function() action, String successMsg) async {
      setState(() {
        _isFriendshipActionLoading = true;
      });
      try {
        await action();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg)),
        );
        // Reload data to reflect state
        await _loadUserData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isFriendshipActionLoading = false;
          });
        }
      }
    }

    switch (_friendshipStatus) {
      case 'none':
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => handleAction(
                () => repo.sendFriendRequest(widget.userId),
                'Friend request sent!',
              ),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text(
                'Send Friend Request',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        );
      case 'sent_pending':
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => handleAction(
                () => repo.cancelFriendRequest(widget.userId),
                'Friend request cancelled.',
              ),
              icon: const Icon(Icons.close_rounded, color: Colors.grey),
              label: const Text(
                'Cancel Request',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        );
      case 'received_pending':
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => handleAction(
                      () => repo.declineFriendRequest(widget.userId),
                      'Friend request declined.',
                    ),
                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                    label: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.redAccent.shade100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => handleAction(
                      () => repo.acceptFriendRequest(widget.userId),
                      'Friend request accepted!',
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'friends':
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Unfriend User?'),
                    content: Text('Are you sure you want to remove ${_profile?.name ?? widget.initialName} from your friends?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Unfriend', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await handleAction(
                    () => repo.unfriend(widget.userId),
                    'Unfriended ${_profile?.name ?? widget.initialName}.',
                  );
                }
              },
              icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
              label: const Text(
                'Unfriend',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent.shade100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _profile?.avatarUrl ?? widget.initialAvatarUrl;
    final name = _profile?.name ?? widget.initialName;
    final league = _profile?.league ?? 'Stargazer';
    final weeklyXp = _profile?.weeklyXp ?? 0;
    final lifetimeXp = _profile?.xp ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // User Avatar
          CircleAvatar(
            radius: 36,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
            backgroundColor: Colors.deepPurple.shade100,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? const Icon(Icons.person, size: 36, color: Colors.deepPurple)
                : null,
          ),
          const SizedBox(height: 12),
          // User Name
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // League Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.shade100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, size: 14, color: Colors.deepPurple),
                const SizedBox(width: 4),
                Text(
                  league.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // XP Stats row
          Row(
            children: [
              // Lifetime XP (Left)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple.shade700, Colors.indigo.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Lifetime XP',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$lifetimeXp XP',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Weekly XP (Right)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.deepPurple.shade100, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Weekly XP',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.deepPurple.shade700,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$weeklyXp XP',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          // Created Contributions section
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Contributions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          if (_isLoading)
            const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            SizedBox(
              height: 250,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                      tabs: [
                        Tab(text: 'Lessons (${_courses.length})'),
                        Tab(text: 'Quizzes (${_quizzes.length})'),
                        Tab(text: 'Flashcards (${_decks.length})'),
                      ],
                      labelColor: Colors.deepPurple,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.deepPurple,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      padding: EdgeInsets.zero,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildLessonsList(),
                          _buildQuizzesList(),
                          _buildDecksList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildFriendshipSection(),
          ],
        ],
      ),
    );
  }
}
