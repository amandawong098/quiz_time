import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/friendship_models.dart';
import '../../core/widgets/notification_overlay.dart';
import '../../features/quiz/screens/take_quiz_screen.dart';
import '../../core/router/app_router.dart';
import '../../features/quiz/widgets/challenge_invitation_dialog.dart';

class FriendshipRepository extends ChangeNotifier with WidgetsBindingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _challengeChannel;
  Timer? _heartbeatTimer;
  int _unreadCount = 0;
  List<AppNotification> _notifications = [];
  UserProfile? _currentUserProfile;
  bool _localNotificationsInitialized = false;
  Future<void>? _localNotificationsInitFuture;

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  FriendshipRepository() {
    WidgetsBinding.instance.addObserver(this);
    _initLocalNotifications();
    _supabase.auth.onAuthStateChange.listen((state) async {
      if (state.session != null) {
        await _loadCurrentUserProfile();
        _subscribeToNotifications();
        _subscribeToChallenges();
        _startHeartbeat();
        await _loadUnreadCount();
        await _loadNotifications();
      } else {
        _unsubscribeFromNotifications();
        _unsubscribeFromChallenges();
        _stopHeartbeat();
        _unreadCount = 0;
        _notifications.clear();
        _currentUserProfile = null;
        notifyListeners();
      }
    });

    // Handle initial state if user is already logged in when constructed
    if (_supabase.auth.currentUser != null) {
      _loadCurrentUserProfile().then((_) {
        _subscribeToNotifications();
        _subscribeToChallenges();
        _startHeartbeat();
        _loadUnreadCount();
        _loadNotifications();
      });
    }
  }

  String get _currentUserId => _supabase.auth.currentUser!.id;
  int get unreadCount => _unreadCount;
  List<AppNotification> get notifications => _notifications;
  UserProfile? get currentUserProfile => _currentUserProfile;

  Future<void> refreshProfileAndNotifications() async {
    await _loadCurrentUserProfile();
    await _loadUnreadCount();
    await _loadNotifications();
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', _currentUserId)
          .single();
      _currentUserProfile = UserProfile.fromJson(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading current user profile: $e');
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', _currentUserId)
          .eq('is_read', false);
      _unreadCount = (response as List).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', _currentUserId)
          .order('created_at', ascending: false);
      _notifications = (response as List)
          .map((e) => AppNotification.fromJson(e))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  void _subscribeToNotifications() {
    _unsubscribeFromNotifications();
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _notificationChannel = _supabase.channel('public:notifications:user_$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) async {
          final newNotification = AppNotification.fromJson(payload.newRecord);
          
          // Re-load to ensure accurate lists
          await _loadUnreadCount();
          await _loadNotifications();

          final state = WidgetsBinding.instance.lifecycleState;
          final isAppInForeground = state == AppLifecycleState.resumed || state == null;

          if (isAppInForeground) {
            // Show real-time overlay notification popup unless they are taking a quiz
            if (!TakeQuizScreen.isActive) {
              NotificationOverlay.show(
                title: newNotification.title,
                message: newNotification.message,
              );
            }
          } else {
            // Show system-level local notification
            _showLocalSystemNotification(newNotification);
          }
        },
      )
      ..subscribe();
  }

  void _unsubscribeFromNotifications() {
    if (_notificationChannel != null) {
      _supabase.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _currentUserId)
          .eq('is_read', false);
      _unreadCount = 0;
      await _loadNotifications();
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      
      _notifications.removeWhere((n) => n.id == notificationId);
      await _loadUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // --- FRIENDSHIP DATABASE ACTIONS ---

  Future<List<UserProfile>> getFriends() async {
    final response = await _supabase
        .from('friendships')
        .select('*, sender:profiles!sender_id(*), receiver:profiles!receiver_id(*)')
        .eq('status', 'accepted')
        .or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId');

    final List<UserProfile> friends = [];
    for (var row in response as List) {
      final sender = row['sender'];
      final receiver = row['receiver'];
      if (row['sender_id'] == _currentUserId) {
        if (receiver != null) {
          friends.add(UserProfile.fromJson(receiver));
        }
      } else {
        if (sender != null) {
          friends.add(UserProfile.fromJson(sender));
        }
      }
    }
    return friends;
  }

  Future<List<UserProfile>> getIncomingRequests() async {
    final response = await _supabase
        .from('friendships')
        .select('*, sender:profiles!sender_id(*)')
        .eq('status', 'pending')
        .eq('receiver_id', _currentUserId);

    return (response as List)
        .where((row) => row['sender'] != null)
        .map((row) => UserProfile.fromJson(row['sender'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserProfile>> getSentRequests() async {
    final response = await _supabase
        .from('friendships')
        .select('*, receiver:profiles!receiver_id(*)')
        .eq('status', 'pending')
        .eq('sender_id', _currentUserId);

    return (response as List)
        .where((row) => row['receiver'] != null)
        .map((row) => UserProfile.fromJson(row['receiver'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserProfile>> getDiscoverNewFriends() async {
    final friendships = await _supabase
        .from('friendships')
        .select('sender_id, receiver_id')
        .or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId');

    final Set<String> excludedUserIds = {_currentUserId};
    for (var row in friendships as List) {
      excludedUserIds.add(row['sender_id'] as String);
      excludedUserIds.add(row['receiver_id'] as String);
    }

    final response = await _supabase
        .from('profiles')
        .select('*');

    return (response as List)
        .map((e) => UserProfile.fromJson(e))
        .where((profile) => !excludedUserIds.contains(profile.id))
        .toList();
  }

  Future<void> sendFriendRequest(String receiverId) async {
    await _supabase.from('friendships').insert({
      'sender_id': _currentUserId,
      'receiver_id': receiverId,
      'status': 'pending',
    });

    final senderName = _currentUserProfile?.name ?? 'Someone';
    await _supabase.from('notifications').insert({
      'user_id': receiverId,
      'title': 'Friend Request Received',
      'message': '$senderName has sent you a friend request.',
      'is_read': false,
    });
  }

  Future<void> acceptFriendRequest(String senderId) async {
    await _supabase
        .from('friendships')
        .update({'status': 'accepted', 'updated_at': DateTime.now().toIso8601String()})
        .eq('sender_id', senderId)
        .eq('receiver_id', _currentUserId);

    final receiverName = _currentUserProfile?.name ?? 'Someone';
    await _supabase.from('notifications').insert({
      'user_id': senderId,
      'title': 'Friend Request Accepted',
      'message': '$receiverName accepted your friend request.',
      'is_read': false,
    });
  }

  Future<void> declineFriendRequest(String senderId) async {
    await _supabase
        .from('friendships')
        .delete()
        .eq('sender_id', senderId)
        .eq('receiver_id', _currentUserId);

    final receiverName = _currentUserProfile?.name ?? 'Someone';
    await _supabase.from('notifications').insert({
      'user_id': senderId,
      'title': 'Friend Request Declined',
      'message': '$receiverName declined your friend request.',
      'is_read': false,
    });
  }

  Future<void> cancelFriendRequest(String receiverId) async {
    await _supabase
        .from('friendships')
        .delete()
        .eq('sender_id', _currentUserId)
        .eq('receiver_id', receiverId)
        .eq('status', 'pending');
  }

  Future<void> unfriend(String friendId) async {
    await _supabase
        .from('friendships')
        .delete()
        .or('and(sender_id.eq.$_currentUserId,receiver_id.eq.$friendId),and(sender_id.eq.$friendId,receiver_id.eq.$_currentUserId)');
  }

  Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitFuture != null) return _localNotificationsInitFuture;

    _localNotificationsInitFuture = _initLocalNotificationsInternal();
    return _localNotificationsInitFuture;
  }

  Future<void> _initLocalNotificationsInternal() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    try {
      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          appRouter.go('/me/friends');
        },
      );

      final androidImplementation = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      final iosImplementation = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      _localNotificationsInitialized = true;
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  Future<void> _showLocalSystemNotification(AppNotification notification) async {
    if (!_localNotificationsInitialized) {
      await _initLocalNotifications();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'friend_requests_channel',
      'Friend Requests',
      channelDescription: 'Notifications for friend requests and network updates',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    try {
      final int id = notification.id.hashCode;
      await _localNotificationsPlugin.show(
        id: id,
        title: notification.title,
        body: notification.message,
        notificationDetails: platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopHeartbeat();
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      _sendHeartbeat();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('profiles')
          .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error sending heartbeat: $e');
    }
  }

  Future<void> setUserPlaying(bool isPlaying) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('profiles')
          .update({'is_playing': isPlaying})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error setting is_playing = $isPlaying: $e');
    }
  }

  void _subscribeToChallenges() {
    _unsubscribeFromChallenges();
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _challengeChannel = _supabase.channel('public:quiz_challenge_players:user_$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'quiz_challenge_players',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) async {
          final newPlayerRecord = payload.newRecord;
          final status = newPlayerRecord['status'] as String;
          final challengeId = newPlayerRecord['challenge_id'] as String;

          if (status == 'pending') {
            try {
              final challengeData = await _supabase
                  .from('quiz_challenges')
                  .select('*, quizzes(title), profiles!host_id(name)')
                  .eq('id', challengeId)
                  .single();

              final quizTitle = challengeData['quizzes']['title'] as String;
              final hostName = challengeData['profiles']['name'] as String;
              final quizId = challengeData['quiz_id'] as String;
              final shuffle = challengeData['shuffle'] as bool? ?? false;

              _showInvitationDialog(challengeId, hostName, quizTitle, quizId, shuffle);
            } catch (e) {
              debugPrint('Error loading challenge details: $e');
            }
          }
        },
      )
      ..subscribe();
  }

  void _unsubscribeFromChallenges() {
    if (_challengeChannel != null) {
      _supabase.removeChannel(_challengeChannel!);
      _challengeChannel = null;
    }
  }

  void _showInvitationDialog(
      String challengeId, String hostName, String quizTitle, String quizId, bool shuffle) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChallengeInvitationDialog(
        challengeId: challengeId,
        hostName: hostName,
        quizTitle: quizTitle,
        quizId: quizId,
        shuffle: shuffle,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribeFromNotifications();
    _unsubscribeFromChallenges();
    _stopHeartbeat();
    super.dispose();
  }
}
