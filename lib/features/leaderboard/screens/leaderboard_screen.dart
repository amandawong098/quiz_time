import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/notification_badge.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../profile/widgets/user_detail_bottom_sheet.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardRepository _repository = LeaderboardRepository();
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  bool _isLoading = true;

  // Selected view league
  String _selectedLeague = 'Stargazer';

  // Current logged in user info
  String _userLeague = 'Stargazer';
  int _userXp = 0;
  int _userWeeklyXp = 0;

  List<LeaderboardUser> _users = [];
  List<LeagueConfig> _configs = [];

  final List<String> _leaguesOrder = [
    'Stargazer',
    'Explorer',
    'Voyager',
    'Stellar Scholar',
    'Galactic Sage',
    'Cosmic Legend',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final didReset = await _repository.checkAndResetWeeklyLeagues();
    if (didReset && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weekly leaderboard reset completed! Check your mailbox.'),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
    await _loadUserProfile();
    _configs = await _repository.getLeagueConfigs();
    if (_configs.isEmpty) {
      // Fallback local configs if database not yet migrated
      _configs = [
        LeagueConfig(league: 'Stargazer', rankOrder: 1, minWeeklyXp: 10, promotionPct: 0.20, demotionPct: 0.10),
        LeagueConfig(league: 'Explorer', rankOrder: 2, minWeeklyXp: 20, promotionPct: 0.20, demotionPct: 0.10),
        LeagueConfig(league: 'Voyager', rankOrder: 3, minWeeklyXp: 30, promotionPct: 0.20, demotionPct: 0.10),
        LeagueConfig(league: 'Stellar Scholar', rankOrder: 4, minWeeklyXp: 40, promotionPct: 0.20, demotionPct: 0.10),
        LeagueConfig(league: 'Galactic Sage', rankOrder: 5, minWeeklyXp: 50, promotionPct: 0.20, demotionPct: 0.10),
        LeagueConfig(league: 'Cosmic Legend', rankOrder: 6, minWeeklyXp: 60, promotionPct: 0.20, demotionPct: 0.10),
      ];
    }
    // Default select user's current league
    _selectedLeague = _userLeague;
    await _loadLeaderboard();
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('league, xp, weekly_xp')
            .eq('id', user.id)
            .single();
        setState(() {
          _userLeague = res['league'] as String? ?? 'Stargazer';
          _userXp = (res['xp'] as num? ?? 0).toInt();
          _userWeeklyXp = (res['weekly_xp'] as num? ?? 0).toInt();
        });
      } catch (_) {}
    }
  }

  Future<void> _loadLeaderboard() async {
    final data = await _repository.getLeaderboard(_selectedLeague);
    setState(() {
      _users = data;
      _isLoading = false;
    });
  }

  LeagueConfig _getLeagueConfig(String leagueName) {
    return _configs.firstWhere(
      (c) => c.league == leagueName,
      orElse: () => LeagueConfig(
        league: leagueName,
        rankOrder: 1,
        minWeeklyXp: 10,
        promotionPct: 0.20,
        demotionPct: 0.10,
      ),
    );
  }

  bool _isLeagueLocked(String leagueName) {
    final userConf = _getLeagueConfig(_userLeague);
    final targetConf = _getLeagueConfig(leagueName);
    return targetConf.rankOrder > userConf.rankOrder;
  }

  String _getTimeRemaining() {
    final now = DateTime.now();
    int daysUntilSunday = DateTime.sunday - now.weekday;
    if (daysUntilSunday <= 0) {
      daysUntilSunday += 7;
    }
    final nextSunday = DateTime(now.year, now.month, now.day + daysUntilSunday);
    final difference = nextSunday.difference(now);

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    return 'Ends in ${days}d, ${hours}h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              if (val == 'test_reset') {
                setState(() => _isLoading = true);
                final success =
                    await _repository.checkAndResetWeeklyLeagues(force: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Weekly reset completed! Check your mailbox notifications.'
                            : 'Failed to run weekly reset.',
                      ),
                      backgroundColor:
                          success ? Colors.deepPurple : Colors.red,
                    ),
                  );
                  await _loadUserProfile();
                  _selectedLeague = _userLeague;
                  await _loadLeaderboard();
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'test_reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text('Simulate Weekly Reset'),
                  ],
                ),
              ),
            ],
          ),
          const NotificationIconBadge(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top XP Summary Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // XP Pills Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '$_userXp XP',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.deepPurple, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '$_userWeeklyXp Weekly XP',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // League Badges tab bar container
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _leaguesOrder.map((name) {
                        final isSelected = _selectedLeague == name;
                        final isLocked = _isLeagueLocked(name);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLeague = name;
                              _isLoading = true;
                            });
                            _loadLeaderboard();
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: _buildLeagueBadgeIcon(name, isLocked, isSelected),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Selected League Details Header
                Container(
                  color: Colors.white,
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                  child: Column(
                    children: [
                      Text(
                        _selectedLeague,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            _getTimeRemaining(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Rankings list
                Expanded(
                  child: _users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No users in this league yet.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                       : ListView(
                          padding: const EdgeInsets.all(16),
                          children: _buildLeaderboardItems(),
                        ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildLeaderboardItems() {
    final List<Widget> items = [];
    final totalCount = _users.length;
    final config = _getLeagueConfig(_selectedLeague);

    final promoCount = (totalCount * config.promotionPct).ceil();
    final demoCount = (totalCount * config.demotionPct).ceil();

    final showDividers = totalCount >= 3;

    for (int i = 0; i < totalCount; i++) {
      final user = _users[i];
      final rank = i + 1;

      items.add(_buildUserRow(user, rank));

      if (showDividers) {
        // Promotion (Level-up zone) divider AFTER the last promoted user row
        if (rank == promoCount) {
          items.add(_buildZoneDivider(
            label: 'Level-up zone',
            color: Colors.green,
            icon: Icons.keyboard_double_arrow_up,
          ));
        }

        // Demotion (Level-down zone) divider BEFORE the first demoted user row
        if (i + 1 == totalCount - demoCount && demoCount > 0 && _selectedLeague != 'Stargazer') {
          items.add(_buildZoneDivider(
            label: 'Level-down zone',
            color: Colors.red,
            icon: Icons.keyboard_double_arrow_down,
          ));
        }
      }
    }

    return items;
  }

  Widget _buildUserRow(LeaderboardUser user, int rank) {
    final isMe = user.id == _currentUserId;
    final totalCount = _users.length;
    final config = _getLeagueConfig(_selectedLeague);
    final promoCount = (totalCount * config.promotionPct).ceil();
    final demoCount = (totalCount * config.demotionPct).ceil();

    Color rankColor = Colors.grey.shade500;
    if (totalCount >= 3) {
      if (rank <= promoCount) {
        rankColor = Colors.green.shade700;
      } else if (rank > totalCount - demoCount && _selectedLeague != 'Stargazer') {
        rankColor = Colors.red.shade700;
      }
    }

    final rankIndicator = SizedBox(
      width: 28,
      child: Text(
        '$rank',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: rankColor,
        ),
      ),
    );

    return Card(
      elevation: isMe ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isMe
            ? const BorderSide(color: Colors.deepPurple, width: 2)
            : BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            rankIndicator,
            const SizedBox(width: 16),
            // Avatar
            GestureDetector(
              onTap: () => UserDetailBottomSheet.show(
                context,
                userId: user.id,
                name: user.name,
                avatarUrl: user.avatarUrl,
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.deepPurple.shade100,
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            // Name
            Expanded(
              child: GestureDetector(
                onTap: () => UserDetailBottomSheet.show(
                  context,
                  userId: user.id,
                  name: user.name,
                  avatarUrl: user.avatarUrl,
                ),
                child: Text(
                  user.name,
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            // Weekly XP
            Text(
              '${user.weeklyXp} XP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: user.weeklyXp > 0 ? Colors.black87 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneDivider({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: color, size: 18),
        ],
      ),
    );
  }

  Widget _buildLeagueBadgeIcon(String name, bool isLocked, bool isSelected) {
    Color badgeColor;
    IconData icon;

    switch (name) {
      case 'Stargazer':
        badgeColor = Colors.amber.shade600;
        icon = Icons.star;
        break;
      case 'Explorer':
        badgeColor = Colors.deepPurple;
        icon = Icons.explore;
        break;
      case 'Voyager':
        badgeColor = Colors.green.shade600;
        icon = Icons.public;
        break;
      case 'Stellar Scholar':
        badgeColor = Colors.indigo.shade700;
        icon = Icons.school;
        break;
      case 'Galactic Sage':
        badgeColor = Colors.purple.shade800;
        icon = Icons.psychology;
        break;
      case 'Cosmic Legend':
        badgeColor = Colors.cyan.shade700;
        icon = Icons.auto_awesome;
        break;
      default:
        badgeColor = Colors.grey;
        icon = Icons.emoji_events;
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isLocked ? Colors.grey.shade300 : badgeColor,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: Colors.green, width: 3)
            : Border.all(color: Colors.transparent, width: 3),
        boxShadow: isSelected
            ? [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8)]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            color: isLocked ? Colors.grey.shade500 : Colors.white,
            size: 28,
          ),
          if (isLocked)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  color: Colors.grey.shade700,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
