class UserProfile {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final int xp;
  final int weeklyXp;
  final String league;

  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.xp,
    required this.weeklyXp,
    required this.league,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? 'Anonymous',
      avatarUrl: json['avatar_url'] as String?,
      xp: json['xp'] as int? ?? 0,
      weeklyXp: json['weekly_xp'] as int? ?? 0,
      league: json['league'] as String? ?? 'Stargazer',
    );
  }
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final bool isRead;
  final String? type;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.isRead,
    this.type,
    this.data,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      type: json['type'] as String?,
      data: json['data'] != null ? json['data'] as Map<String, dynamic> : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }
}
