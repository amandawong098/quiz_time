import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/widgets/byte_mascot.dart';
import '../../../core/widgets/cosmic_background.dart';
import '../../../core/widgets/notification_badge.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/friendship_repository.dart';
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
  String _userRole = 'learner';
  bool get _isAdmin =>
      _userRole.toLowerCase() == 'admin' ||
      (mounted && context.read<AuthRepository>().isAdmin);
  String _userLeague = 'Stargazer';
  int _userXp = 0;
  int _userWeeklyXp = 0;

  bool _isFriendsOnly = true;
  List<LeaderboardUser> _allLeagueUsers = [];
  Set<String> _friendIds = {};

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
      context.read<FriendshipRepository>().refreshProfileAndNotifications();
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
            .select('league, xp, weekly_xp, role')
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _userRole = res['role'] as String? ?? 'learner';
            _userLeague = res['league'] as String? ?? 'Stargazer';
            _userXp = (res['xp'] as num? ?? 0).toInt();
            _userWeeklyXp = (res['weekly_xp'] as num? ?? 0).toInt();
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadLeaderboard() async {
    final friendshipRepo = context.read<FriendshipRepository>();
    final data = await _repository.getLeaderboard(_selectedLeague);
    _allLeagueUsers = data;

    if (_currentUserId != null) {
      try {
        final friends = await friendshipRepo.getFriends();
        _friendIds = friends.map((f) => f.id).toSet();
      } catch (_) {}
    }

    _applyFilter();
  }

  void _applyFilter() {
    if (!mounted) return;
    final currentId = _currentUserId;
    if (_isFriendsOnly) {
      final allowedIds = {
        ..._friendIds,
        ?currentId,
      };
      setState(() {
        _users = _allLeagueUsers
            .where((u) => allowedIds.contains(u.id))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _users = List.from(_allLeagueUsers);
        _isLoading = false;
      });
    }
  }

  void _onToggleFilter(bool friendsOnly) {
    if (_isFriendsOnly == friendsOnly) return;
    SoundService.instance.playTabSwitch();
    _isFriendsOnly = friendsOnly;
    _applyFilter();
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
    if (_isAdmin) return false;
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
    final leagueTheme = CosmicLeagueThemeData.forLeague(_selectedLeague);

    return Scaffold(
      backgroundColor: leagueTheme.backgroundGradient.first,
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        flexibleSpace: const CosmicAppBarFlexibleSpace(seed: 33),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              if (val == 'test_reset') {
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _isLoading = true);
                final success =
                    await _repository.checkAndResetWeeklyLeagues(force: true);
                if (mounted) {
                  messenger.showSnackBar(
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
      body: CosmicLeagueFullBackground(
        league: _selectedLeague,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Column(
                children: [
                  // Top Summary Bar (Frosted Glass over Full Cosmic Background)
                  if (_isAdmin)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.admin_panel_settings_rounded,
                              color: leagueTheme.primaryAccent,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Administrator View',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Viewing learner rankings. Admins do not participate in leaderboard rankings.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // XP Pills Row
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.amber.withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.emoji_events, color: Colors.amber, size: 15),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_userXp XP',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: leagueTheme.primaryAccent.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          color: leagueTheme.primaryAccent,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_userWeeklyXp Weekly XP',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterToggle(leagueTheme.primaryAccent),
                        ],
                      ),
                    ),

                  // League Badges & Selected League Header directly on the Full Cosmic Background
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 12),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: _leaguesOrder.map((name) {
                              final isSelected = _selectedLeague == name;
                              final isLocked = _isLeagueLocked(name);
                              return GestureDetector(
                                onTap: () {
                                  SoundService.instance.playTabSwitch();
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
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: leagueTheme.primaryAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedLeague,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getTimeRemaining(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rankings list directly over the Full Cosmic Background
                  Expanded(
                    child: _users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const ByteMascot(
                                  size: 112,
                                  mood: ByteMascotMood.curious,
                                  darkThemeContext: true,
                                  tapMessages: [
                                    'Nothing on the radar here yet! 📡',
                                    'Try switching to Global to spot more explorers! 🌍',
                                    'Earn Weekly XP to climb the cosmic ranks! 🚀',
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _isFriendsOnly
                                      ? 'No friends in this league yet'
                                      : 'No users in this league yet.',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_isFriendsOnly) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Switch to Global to view all learners',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
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
    final isMe = !_isAdmin && user.id == _currentUserId;
    final totalCount = _users.length;
    final config = _getLeagueConfig(_selectedLeague);
    final promoCount = (totalCount * config.promotionPct).ceil();
    final demoCount = (totalCount * config.demotionPct).ceil();
    final leagueTheme = CosmicLeagueThemeData.forLeague(_selectedLeague);

    Color rankColor = Colors.white.withValues(alpha: 0.75);
    if (totalCount >= 3) {
      if (rank <= promoCount) {
        rankColor = const Color(0xFF69F0AE);
      } else if (rank > totalCount - demoCount && _selectedLeague != 'Stargazer') {
        rankColor = const Color(0xFFFF8A80);
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: isMe ? 0.38 : 0.26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? leagueTheme.primaryAccent.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.18),
          width: isMe ? 1.8 : 1.0,
        ),
        boxShadow: isMe
            ? [
                BoxShadow(
                  color: leagueTheme.primaryAccent.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            rankIndicator,
            const SizedBox(width: 16),
            // Byte Avatar
            GestureDetector(
              onTap: () => UserDetailBottomSheet.show(
                context,
                userId: user.id,
                name: user.name,
                avatarUrl: user.avatarUrl,
              ),
              child: UserByteAvatar(
                avatarUrl: user.avatarUrl,
                isCurrentUser: isMe,
                radius: 20,
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
                    color: Colors.white,
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
                color: user.weeklyXp > 0
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
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
    final isPromo = color == Colors.green;
    final badgeTextColor = isPromo ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: badgeTextColor.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: badgeTextColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: badgeTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: badgeTextColor, size: 18),
            ],
          ),
        ),
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
            ? [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 8)]
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

  Widget _buildFilterToggle(Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Friends Only Tab
          GestureDetector(
            onTap: () => _onToggleFilter(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isFriendsOnly ? accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Friends only',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _isFriendsOnly ? FontWeight.bold : FontWeight.w600,
                  color: _isFriendsOnly ? CosmicColors.deepVoid : Colors.white,
                ),
              ),
            ),
          ),
          // Global Tab
          GestureDetector(
            onTap: () => _onToggleFilter(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: !_isFriendsOnly ? accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Global',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: !_isFriendsOnly ? FontWeight.bold : FontWeight.w600,
                  color: !_isFriendsOnly ? CosmicColors.deepVoid : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
