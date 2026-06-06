import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/friendship_repository.dart';
import '../../data/models/friendship_models.dart';
import '../router/app_router.dart';

class NotificationIconBadge extends StatelessWidget {
  const NotificationIconBadge({super.key});

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<FriendshipRepository>(
          builder: (context, repo, child) {
            final list = repo.notifications;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(
                              child: Text(
                                'No notifications yet.',
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            )
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final AppNotification n = list[index];
                                final timeStr = '${n.createdAt.day}/${n.createdAt.month}/${n.createdAt.year}';
                                final isUnread = !n.isRead;

                                return Dismissible(
                                  key: Key(n.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20.0),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (direction) {
                                    repo.deleteNotification(n.id);
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    color: isUnread ? Colors.deepPurple.shade800 : null,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isUnread ? Colors.deepPurple.shade900 : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isUnread ? Colors.white : Colors.deepPurple,
                                        child: Icon(
                                          Icons.notifications,
                                          color: isUnread ? Colors.deepPurple.shade800 : Colors.white,
                                        ),
                                      ),
                                      title: Text(
                                        n.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isUnread ? Colors.white : null,
                                        ),
                                      ),
                                      subtitle: Text(
                                        n.message,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isUnread ? Colors.white70 : null,
                                        ),
                                      ),
                                      trailing: Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isUnread ? Colors.white60 : Colors.grey.shade500,
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        appRouter.go('/me/friends');
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (context.mounted) {
        context.read<FriendshipRepository>().markAllNotificationsRead();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<FriendshipRepository>().unreadCount;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _showNotificationsBottomSheet(context),
        ),
        if (unread > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unread > 9 ? '9+' : unread.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
