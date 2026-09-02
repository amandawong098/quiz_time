import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/friendship_repository.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/notification_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;

  Future<void> _deleteAccount() async {
    bool deleteContributions = true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text(
                  'Delete Account',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deleting your account is permanent. Please choose how to handle your created content (Lessons, Quizzes, Flashcards, and Discussions):',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<bool>(
                    value: true,
                    groupValue: deleteContributions,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.deepPurple,
                    title: const Text(
                      'Delete account & remove all my contributions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'All quizzes, flashcards, lessons, and discussions created by you will be permanently deleted.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => deleteContributions = val);
                      }
                    },
                  ),
                  RadioListTile<bool>(
                    value: false,
                    groupValue: deleteContributions,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.deepPurple,
                    title: const Text(
                      'Delete account but keep my public contributions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Your public content remains available for the community under "Deleted User". Private drafts will be deleted.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => deleteContributions = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Colors.amber.shade900,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tip: If you only want to keep specific contributions, click Cancel first to manually delete unwanted items before deleting your account.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Delete Account',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        await context
            .read<AuthRepository>()
            .deleteAccount(deleteContributions: deleteContributions);
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog(e.toString());
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildManageOptionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isDummy,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade800
              : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDummy ? Colors.grey : Colors.deepPurple),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDummy ? Colors.grey.shade600 : null,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: isDummy
            ? () {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    content: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white),
                        const SizedBox(width: 10),
                        Text('$title feature is coming soon!'),
                      ],
                    ),
                  ),
                );
              }
            : onTap,
      ),
    );
  }

  Map<String, dynamic> _getLeagueStyle(String league) {
    MaterialColor baseColor;
    IconData icon;

    switch (league) {
      case 'Stargazer':
        baseColor = Colors.amber;
        icon = Icons.star;
        break;
      case 'Explorer':
        baseColor = Colors.deepPurple;
        icon = Icons.explore;
        break;
      case 'Voyager':
        baseColor = Colors.green;
        icon = Icons.public;
        break;
      case 'Stellar Scholar':
        baseColor = Colors.indigo;
        icon = Icons.school;
        break;
      case 'Galactic Sage':
        baseColor = Colors.purple;
        icon = Icons.psychology;
        break;
      case 'Cosmic Legend':
        baseColor = Colors.cyan;
        icon = Icons.auto_awesome;
        break;
      default:
        baseColor = Colors.blue;
        icon = Icons.shield;
    }
    return {
      'bg': baseColor.shade50,
      'border': baseColor.shade200,
      'text': baseColor.shade900,
      'iconColor': baseColor,
      'labelColor': baseColor.shade700,
      'icon': icon,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;
    final profile = context.watch<FriendshipRepository>().currentUserProfile;
    final leagueStyle = _getLeagueStyle(profile?.league ?? 'Stargazer');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [NotificationIconBadge()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await context.read<FriendshipRepository>().refreshProfileAndNotifications();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          backgroundImage: user?.userMetadata?['avatar_url'] != null
                              ? NetworkImage(user!.userMetadata!['avatar_url'])
                              : null,
                          child: user?.userMetadata?['avatar_url'] == null
                              ? const Icon(Icons.person, size: 50, color: Colors.deepPurple)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () async {
                              final result = await context.push('/me/edit');
                              if (result == true) {
                                setState(() {});
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user?.userMetadata?['name'] ?? 'User Name',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (context.watch<AuthRepository>().isAdmin)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade900],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.amber,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'System Administrator',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Full content authoring & moderation hub access',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Lifetime XP
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                                const SizedBox(height: 4),
                                Text(
                                  '${profile?.xp ?? user?.userMetadata?['xp'] ?? 0}',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Lifetime XP',
                                  style: TextStyle(
                                    color: Colors.amber.shade700,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Weekly XP
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.deepPurple.shade200),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.deepPurple, size: 14),
                                const SizedBox(height: 4),
                                Text(
                                  '${profile?.weeklyXp ?? user?.userMetadata?['weekly_xp'] ?? 0}',
                                  style: TextStyle(
                                    color: Colors.deepPurple.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Weekly XP',
                                  style: TextStyle(
                                    color: Colors.deepPurple.shade700,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Current League
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: leagueStyle['bg'],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: leagueStyle['border']),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  leagueStyle['icon'] as IconData,
                                  color: leagueStyle['iconColor'] as Color,
                                  size: 16,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile?.league ?? 'Stargazer',
                                  style: TextStyle(
                                    color: leagueStyle['text'] as Color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Current League',
                                  style: TextStyle(
                                    color: leagueStyle['labelColor'] as Color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  const Text(
                    'Manage Your Content',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildManageOptionItem(
                    context: context,
                    icon: Icons.menu_book_rounded,
                    title: 'My Lessons',
                    isDummy: false,
                    onTap: () => context.push('/my-lessons'),
                  ),
                  const SizedBox(height: 12),
                  _buildManageOptionItem(
                    context: context,
                    icon: Icons.style_rounded,
                    title: 'My Flashcards',
                    isDummy: false,
                    onTap: () => context.push('/my-flashcards'),
                  ),
                  const SizedBox(height: 12),
                  _buildManageOptionItem(
                    context: context,
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'My Quizzes',
                    isDummy: false,
                    onTap: () => context.push('/my-quizzes'),
                  ),
                  const SizedBox(height: 12),
                  _buildManageOptionItem(
                    context: context,
                    icon: Icons.forum_rounded,
                    title: 'My Discussions',
                    isDummy: false,
                    onTap: () => context.push('/my-discussions'),
                  ),
                  if (!context.watch<AuthRepository>().isAdmin) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),
                    const Text(
                      'Manage Your Network',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildManageOptionItem(
                      context: context,
                      icon: Icons.group_rounded,
                      title: 'My Friends',
                      isDummy: false,
                      onTap: () => context.push('/me/friends'),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  const Text(
                    'Manage Your Account',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepPurple.shade100),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        context.watch<AuthRepository>().isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.school_rounded,
                        color: Colors.deepPurple,
                      ),
                      title: Text(
                        'Account Role: ${context.watch<AuthRepository>().isAdmin ? "Administrator" : "Learner"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Toggle switch to test Admin vs Learner permissions',
                        style: TextStyle(fontSize: 11),
                      ),
                      trailing: Switch(
                        value: context.watch<AuthRepository>().isAdmin,
                        activeThumbColor: Colors.deepPurple,
                        onChanged: (val) async {
                          final newRole = val ? 'admin' : 'learner';
                          await context.read<AuthRepository>().updateUserRole(newRole);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Switched account role to "$newRole".'),
                                backgroundColor: Colors.deepPurple,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await context.read<AuthRepository>().signOut();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }
}
