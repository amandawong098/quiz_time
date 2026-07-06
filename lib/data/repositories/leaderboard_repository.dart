import 'package:supabase_flutter/supabase_flutter.dart';

class LeagueConfig {
  final String league;
  final int rankOrder;
  final int minWeeklyXp;
  final double promotionPct;
  final double demotionPct;

  LeagueConfig({
    required this.league,
    required this.rankOrder,
    required this.minWeeklyXp,
    required this.promotionPct,
    required this.demotionPct,
  });

  factory LeagueConfig.fromJson(Map<String, dynamic> json) {
    return LeagueConfig(
      league: json['league'] as String,
      rankOrder: (json['rank_order'] as num).toInt(),
      minWeeklyXp: (json['min_weekly_xp'] as num).toInt(),
      promotionPct: (json['promotion_pct'] as num).toDouble(),
      demotionPct: (json['demotion_pct'] as num).toDouble(),
    );
  }
}

class LeaderboardUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final int weeklyXp;
  final int xp;
  final String league;

  LeaderboardUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.weeklyXp,
    required this.xp,
    required this.league,
  });

  LeaderboardUser copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    int? weeklyXp,
    int? xp,
    String? league,
  }) {
    return LeaderboardUser(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      xp: xp ?? this.xp,
      league: league ?? this.league,
    );
  }

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) {
    return LeaderboardUser(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Anonymous',
      avatarUrl: json['avatar_url'] as String?,
      weeklyXp: (json['weekly_xp'] as num? ?? 0).toInt(),
      xp: (json['xp'] as num? ?? 0).toInt(),
      league: json['league'] as String? ?? 'Stargazer',
    );
  }
}

class LeaderboardRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all users in a specific league, sorted by weekly_xp desc, then updated_at asc, then id
  Future<List<LeaderboardUser>> getLeaderboard(String league) async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, name, avatar_url, weekly_xp, xp, league')
          .eq('league', league)
          .order('weekly_xp', ascending: false)
          .order('updated_at', ascending: true);

      return (response as List)
          .map((json) => LeaderboardUser.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch all league configurations
  Future<List<LeagueConfig>> getLeagueConfigs() async {
    try {
      final response = await _client
          .from('league_configs')
          .select('league, rank_order, min_weekly_xp, promotion_pct, demotion_pct')
          .order('rank_order', ascending: true);

      return (response as List)
          .map((json) => LeagueConfig.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

}
