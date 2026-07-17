import 'package:flutter/material.dart';
import '../router/app_router.dart';

class NotificationOverlay {
  static void show({
    required String title,
    required String message,
    String? type,
    Map<String, dynamic>? data,
  }) {
    final overlayState = rootNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => NotificationPopupWidget(
        title: title,
        message: message,
        type: type,
        data: data,
        onDismiss: () {
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        },
      ),
    );

    overlayState.insert(overlayEntry);

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

class NotificationPopupWidget extends StatefulWidget {
  final String title;
  final String message;
  final String? type;
  final Map<String, dynamic>? data;
  final VoidCallback onDismiss;

  const NotificationPopupWidget({
    super.key,
    required this.title,
    required this.message,
    this.type,
    this.data,
    required this.onDismiss,
  });

  @override
  State<NotificationPopupWidget> createState() => _NotificationPopupWidgetState();
}

class _NotificationPopupWidgetState extends State<NotificationPopupWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Positioned(
          top: mediaQuery.padding.top + 10 + _slideAnimation.value,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () async {
          await _dismiss();
          final topicId = widget.data?['topic_id'] as String?;
          final type = widget.type;
          if (topicId != null &&
              (type == 'discussion_upvote' ||
               type == 'comment_upvote' ||
               type == 'discussion_reply' ||
               type == 'comment_reply')) {
            appRouter.push('/discussion/$topicId');
          } else {
            appRouter.push('/me/friends');
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade900.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                onPressed: _dismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
