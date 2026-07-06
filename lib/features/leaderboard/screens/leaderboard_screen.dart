import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/notification_badge.dart';
import '../../../data/repositories/leaderboard_repository.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  static bool isSandboxEnv = false;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardRepository _repository = LeaderboardRepository();
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  bool _isLoading = true;
  bool _isResetting = false;

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

  bool _isTestMode = false;
  final Map<String, List<LeaderboardUser>> _sandboxUsersByLeague = {};
  String _sandboxUserLeague = 'Stargazer';
  int _sandboxUserWeeklyXp = 0;
  int _sandboxUserXp = 0;
  int _sandboxDummyCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
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
    if (_isTestMode) {
      await _ensureSandboxLeagueLoaded(_selectedLeague);
      final data = List<LeaderboardUser>.from(
        _sandboxUsersByLeague[_selectedLeague] ?? const [],
      )..sort(_compareLeaderboardUsers);
      setState(() {
        _users = data;
        _isLoading = false;
      });
      return;
    }

    final data = await _repository.getLeaderboard(_selectedLeague);
    setState(() {
      _users = data;
      _isLoading = false;
    });
  }

  int _compareLeaderboardUsers(LeaderboardUser a, LeaderboardUser b) {
    final xpCompare = b.weeklyXp.compareTo(a.weeklyXp);
    if (xpCompare != 0) return xpCompare;
    return a.id.compareTo(b.id);
  }

  Future<void> _ensureSandboxLeagueLoaded(String league) async {
    if (_sandboxUsersByLeague.containsKey(league)) return;
    final data = await _repository.getLeaderboard(league);
    _sandboxUsersByLeague[league] = List<LeaderboardUser>.from(data)
      ..sort(_compareLeaderboardUsers);
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
    final userConf = _getLeagueConfig(
      _isTestMode ? _sandboxUserLeague : _userLeague,
    );
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

  Future<void> _triggerWeeklyReset() async {
    if (!_isTestMode) return;

    setState(() => _isResetting = true);
    try {
      final String oldLeague = _sandboxUserLeague;

      for (final league in _leaguesOrder) {
        await _ensureSandboxLeagueLoaded(league);
      }

      final updates = <String, String>{};
      for (final league in _leaguesOrder) {
        final users = List<LeaderboardUser>.from(
          _sandboxUsersByLeague[league] ?? const [],
        )..sort(_compareLeaderboardUsers);
        if (users.isEmpty) continue;

        final config = _getLeagueConfig(league);
        final promoCount = (users.length * config.promotionPct).ceil();
        final demoCount = (users.length * config.demotionPct).ceil();

        for (var i = 0; i < users.length; i++) {
          final user = users[i];
          var newLeague = league;

          if (i < promoCount && user.weeklyXp >= config.minWeeklyXp) {
            final currentIndex = _leaguesOrder.indexOf(league);
            if (currentIndex >= 0 && currentIndex < _leaguesOrder.length - 1) {
              newLeague = _leaguesOrder[currentIndex + 1];
            }
          } else if (i >= users.length - demoCount &&
              league != _leaguesOrder.first &&
              user.weeklyXp < config.minWeeklyXp) {
            final currentIndex = _leaguesOrder.indexOf(league);
            if (currentIndex > 0) {
              newLeague = _leaguesOrder[currentIndex - 1];
            }
          }

          updates[user.id] = newLeague;
        }
      }

      final nextByLeague = <String, List<LeaderboardUser>>{
        for (final league in _leaguesOrder) league: <LeaderboardUser>[],
      };

      for (final users in _sandboxUsersByLeague.values) {
        for (final user in users) {
          final newLeague = updates[user.id] ?? user.league;
          final resetUser = user.copyWith(league: newLeague, weeklyXp: 0);
          nextByLeague.putIfAbsent(newLeague, () => <LeaderboardUser>[]).add(resetUser);
        }
      }

      for (final league in nextByLeague.keys) {
        nextByLeague[league]!.sort(_compareLeaderboardUsers);
      }

      _sandboxUsersByLeague
        ..clear()
        ..addAll(nextByLeague);

      if (_currentUserId != null) {
        _sandboxUserLeague = updates[_currentUserId] ?? _sandboxUserLeague;
        _sandboxUserWeeklyXp = 0;
      }

      _selectedLeague = _sandboxUserLeague;
      await _loadLeaderboard();

      if (!mounted) return;
      _showResetResultDialog(oldLeague, _sandboxUserLeague);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to simulate reset: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  void _showResetResultDialog(String oldLeague, String newLeague) {
    final int oldRankIdx = _leaguesOrder.indexOf(oldLeague);
    final int newRankIdx = _leaguesOrder.indexOf(newLeague);

    showDialog(
      context: context,
      builder: (context) {
        String title;
        String content;
        IconData icon;
        Color color;

        if (newRankIdx > oldRankIdx) {
          title = 'Sandbox Promotion';
          content = 'Simulation result: you would move from $oldLeague to $newLeague. Your real league was not changed.';
          icon = Icons.emoji_events;
          color = Colors.amber;
        } else if (newRankIdx < oldRankIdx) {
          title = 'Sandbox Demotion';
          content = 'Simulation result: you would move from $oldLeague to $newLeague. Your real league was not changed.';
          icon = Icons.trending_down;
          color = Colors.red;
        } else {
          title = 'Sandbox Week Ended';
          content = 'Simulation result: you would remain in $newLeague. Your real weekly XP and league were not changed.';
          icon = Icons.hourglass_empty;
          color = Colors.blue;
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addDummyUsers() async {
    setState(() => _isLoading = true);
    try {
      await _ensureSandboxLeagueLoaded(_selectedLeague);
      final users = List<LeaderboardUser>.from(
        _sandboxUsersByLeague[_selectedLeague] ?? const [],
      );

      for (var i = 1; i <= 5; i++) {
        _sandboxDummyCounter++;
        users.add(
          LeaderboardUser(
            id: 'sandbox-dummy-$_sandboxDummyCounter',
            name: 'Sandbox User $_sandboxDummyCounter',
            weeklyXp: i * 15,
            xp: i * 100,
            league: _selectedLeague,
          ),
        );
      }

      users.sort(_compareLeaderboardUsers);
      _sandboxUsersByLeague[_selectedLeague] = users;
      await _loadLeaderboard();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added 5 sandbox users to $_selectedLeague.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding sandbox users: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearDummyUsers() async {
    setState(() => _isLoading = true);
    try {
      for (final entry in _sandboxUsersByLeague.entries) {
        entry.value.removeWhere((user) => user.id.startsWith('sandbox-dummy-'));
        entry.value.sort(_compareLeaderboardUsers);
      }
      await _loadLeaderboard();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cleared sandbox users.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing sandbox users: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _adjustUserWeeklyXp(String userId, int change) async {
    try {
      await _ensureSandboxLeagueLoaded(_selectedLeague);
      final users = List<LeaderboardUser>.from(
        _sandboxUsersByLeague[_selectedLeague] ?? const [],
      );
      final userIndex = users.indexWhere((u) => u.id == userId);
      if (userIndex == -1) return;

      final target = users[userIndex];
      final newWeeklyXp = (target.weeklyXp + change).clamp(0, 1000).toInt();
      users[userIndex] = target.copyWith(weeklyXp: newWeeklyXp);
      users.sort(_compareLeaderboardUsers);
      _sandboxUsersByLeague[_selectedLeague] = users;

      if (userId == _currentUserId) {
        _sandboxUserWeeklyXp = newWeeklyXp;
      }

      await _loadLeaderboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update sandbox XP: $e')),
      );
    }
  }

  Future<void> _enterTestMode() async {
    setState(() => _isLoading = true);
    try {
      _sandboxUsersByLeague.clear();
      _sandboxUserLeague = _userLeague;
      _sandboxUserWeeklyXp = _userWeeklyXp;
      _sandboxUserXp = _userXp;
      _sandboxDummyCounter = 0;

      for (final league in _leaguesOrder) {
        final data = await _repository.getLeaderboard(league);
        _sandboxUsersByLeague[league] = List<LeaderboardUser>.from(data)
          ..sort(_compareLeaderboardUsers);
      }

      setState(() {
        _isTestMode = true;
        LeaderboardScreen.isSandboxEnv = true;
        _selectedLeague = _sandboxUserLeague;
      });
      await _loadLeaderboard();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sandbox mode started. Real stats are protected.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTestMode = false;
        LeaderboardScreen.isSandboxEnv = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting sandbox: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exitTestMode() async {
    setState(() {
      _isTestMode = false;
      LeaderboardScreen.isSandboxEnv = false;
      _isLoading = true;
      _sandboxUsersByLeague.clear();
      _selectedLeague = _userLeague;
    });

    await _loadUserProfile();
    _selectedLeague = _userLeague;
    await _loadLeaderboard();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sandbox closed. Real stats were unchanged.')),
    );
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
          IconButton(
            icon: Icon(
              _isTestMode ? Icons.bug_report : Icons.bug_report_outlined,
              color: _isTestMode ? Colors.red : Colors.grey,
            ),
            tooltip: 'Toggle Test Mode',
            onPressed: () {
              if (_isTestMode) {
                _exitTestMode();
              } else {
                _enterTestMode();
              }
            },
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
                                  '${_isTestMode ? _sandboxUserXp : _userXp} XP',
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
                                  '${_isTestMode ? _sandboxUserWeeklyXp : _userWeeklyXp} Weekly XP',
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
                      // Reset simulation or Normal refresh button
                      if (_isTestMode)
                        Row(
                          children: [
                            if (_isResetting)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.deepPurple),
                                tooltip: 'Simulate Weekly Reset',
                                onPressed: _triggerWeeklyReset,
                              ),
                            const SizedBox(width: 2),
                            const Text(
                              'Reset Sim',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
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

                // Bottom Testing Console Panel
                if (_isTestMode) _buildTestConsolePanel(),
              ],
            ),
    );
  }

  Widget _buildTestConsolePanel() {
    return Container(
      color: Colors.deepPurple.shade50.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.group_add, size: 16),
            label: const Text('Add 5 Sandbox Users', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: _addDummyUsers,
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepPurple,
              side: const BorderSide(color: Colors.deepPurple),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Clear Sandbox Users', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: _clearDummyUsers,
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
            CircleAvatar(
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
            const SizedBox(width: 16),
            // Name
            Expanded(
              child: Text(
                user.name,
                style: TextStyle(
                  fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ),
            // Weekly XP
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isTestMode) ...[
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 20),
                    onPressed: () => _adjustUserWeeklyXp(user.id, -10),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
                Text(
                  '${user.weeklyXp} XP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: user.weeklyXp > 0 ? Colors.black87 : Colors.grey,
                  ),
                ),
                if (_isTestMode) ...[
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: Colors.green.shade400, size: 20),
                    onPressed: () => _adjustUserWeeklyXp(user.id, 10),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ],
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
