import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/cosmic_background.dart';
import '../gamification_service.dart';
import '../widgets/space_cabin_widget.dart';

class SpaceCabinScreen extends StatefulWidget {
  final String? visitedUserId;
  final String? visitedUserName;

  const SpaceCabinScreen({
    super.key,
    this.visitedUserId,
    this.visitedUserName,
  });

  @override
  State<SpaceCabinScreen> createState() => _SpaceCabinScreenState();
}

class _SpaceCabinScreenState extends State<SpaceCabinScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoadingVisitor = false;
  UserCosmicState? _visitorState;

  bool get _isVisitorMode =>
      widget.visitedUserId != null && widget.visitedUserId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (_isVisitorMode) {
      _loadVisitorCabin();
    } else {
      GamificationService.instance.loadForCurrentUser();
    }
  }

  Future<void> _loadVisitorCabin() async {
    setState(() => _isLoadingVisitor = true);
    final loaded = await GamificationService.instance
        .fetchUserCosmicState(widget.visitedUserId!);
    if (mounted) {
      setState(() {
        _visitorState = loaded;
        _isLoadingVisitor = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openMysteryPodDialog(GamificationService service) async {
    if (service.spendableXp < GamificationService.mysteryPodCostXp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Need ${GamificationService.mysteryPodCostXp} Spendable XP to open a Mystery Star-Pod! Complete quizzes or daily missions to earn more.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final result = await service.spinMysteryPod();
    if (!mounted || result == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final item = result.item;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: const Color(0xFF1A103C),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.rarityColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.rarityColor),
                  ),
                  child: Text(
                    result.wasDuplicate
                        ? '✨ STARLIGHT JACKPOT!'
                        : '🎉 NEW ${item.rarityLabel} UNLOCKED!',
                    style: TextStyle(
                      color: item.rarityColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: item.previewColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.rarityColor.withValues(alpha: 0.55),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    item.emoji,
                    style: const TextStyle(fontSize: 42),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.wasDuplicate
                      ? 'You already owned ${item.name}, so the Star-Pod awarded you a +${result.duplicateBonusXp} Spendable XP Jackpot (+15 net profit)!'
                      : '${item.description}\n\nAutomatically equipped for you!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Awesome!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDailyMissionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<GamificationService>(
          builder: (context, service, _) {
            final s = service.state;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('🎯', style: TextStyle(fontSize: 22)),
                            SizedBox(width: 8),
                            Text(
                              'Daily Missions & Trophies',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF311B92),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '⚡ ${service.spendableXp} XP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Complete daily goals to earn bonus Spendable XP without affecting your Leaderboard rank!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...GamificationService.dailyMissions.map((m) {
                      final progress = service.getMissionProgress(m.id);
                      final claimed = service.isMissionClaimedToday(m.id);
                      final canClaim = progress >= m.targetCount && !claimed;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: claimed
                              ? Colors.green.shade50
                              : Colors.deepPurple.shade50.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: claimed
                                ? Colors.green.shade200
                                : Colors.deepPurple.shade100,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(m.emoji, style: const TextStyle(fontSize: 26)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    m.subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reward: +${m.rewardXp} Spendable XP',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (claimed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Claimed ✓',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else if (canClaim)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () async {
                                  await service.claimDailyMission(m);
                                },
                                child: Text(
                                  'Claim +${m.rewardXp}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              Text(
                                '${progress.clamp(0, m.targetCount)}/${m.targetCount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 24),
                    const Text(
                      '🏆 Cabin Trophy Shelf',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF311B92),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTrophyChip(
                          emoji: '🛸',
                          title: 'Cabin Owner',
                          unlocked: true,
                        ),
                        _buildTrophyChip(
                          emoji: '🥇',
                          title: 'Collector (7+ Items)',
                          unlocked: s.unlockedIds.length >= 7,
                        ),
                        _buildTrophyChip(
                          emoji: '🌟',
                          title: 'Astro-Byte Bond (45+)',
                          unlocked: s.byteBondXp >= 45,
                        ),
                        _buildTrophyChip(
                          emoji: '👑',
                          title: 'Hyper-Byte Master (120+)',
                          unlocked: s.byteBondXp >= 120,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrophyChip({
    required String emoji,
    required String title,
    required bool unlocked,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: unlocked ? Colors.amber.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? Colors.amber.shade400 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            unlocked ? emoji : '🔒',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: unlocked ? Colors.amber.shade900 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isVisitorMode) {
      return _buildVisitorScreen(context);
    }

    return Consumer<GamificationService>(
      builder: (context, service, _) {
        final s = service.state;
        final spendable = service.spendableXp;
        final claimableMissionsCount = GamificationService.dailyMissions
            .where(
              (m) =>
                  service.getMissionProgress(m.id) >= m.targetCount &&
                  !service.isMissionClaimedToday(m.id),
            )
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Byte\'s Space Cabin'),
            flexibleSpace: const CosmicAppBarFlexibleSpace(seed: 108),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD54F),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          '$spendable Spendable XP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Top Interactive Space Cabin + Mini-Game Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    InteractiveSpaceCabinWidget(
                      cosmicState: s,
                      ownerName: 'You',
                    ),
                    const SizedBox(height: 10),
                    // 4 Quick Mini-Game Buttons Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildMiniGameActionButton(
                            emoji: '🔋',
                            label: service.canFreeFeedToday
                                ? 'Energize (FREE!)'
                                : 'Energize (${GamificationService.energizeByteCostXp} XP)',
                            gradient: const [
                              Color(0xFF059669),
                              Color(0xFF10B981),
                            ],
                            onTap: () async {
                              final res = await service.energizeByte();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message),
                                  backgroundColor: res.success
                                      ? Colors.teal.shade700
                                      : Colors.redAccent,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildMiniGameActionButton(
                            emoji: '🎵',
                            label: 'Play Tune',
                            gradient: const [
                              Color(0xFF2563EB),
                              Color(0xFF38BDF8),
                            ],
                            onTap: () async {
                              final msg = await service.playWithByte();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  backgroundColor: Colors.indigo,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildMiniGameActionButton(
                            emoji: '🎲',
                            label:
                                'Mystery Pod (${GamificationService.mysteryPodCostXp} XP)',
                            gradient: const [
                              Color(0xFF9333EA),
                              Color(0xFFEC4899),
                            ],
                            onTap: () => _openMysteryPodDialog(service),
                          ),
                          const SizedBox(width: 8),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _buildMiniGameActionButton(
                                emoji: '🎯',
                                label: 'Missions & Trophies',
                                gradient: const [
                                  Color(0xFFD97706),
                                  Color(0xFFF59E0B),
                                ],
                                onTap: _showDailyMissionsSheet,
                              ),
                              if (claimableMissionsCount > 0)
                                Positioned(
                                  top: -5,
                                  right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$claimableMissionsCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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

              // 3-Tab Cosmic Customization Shop
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.deepPurple.shade700,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                  tabs: const [
                    Tab(text: '👑 Byte Outfits'),
                    Tab(text: '🛸 Cabin Decor'),
                    Tab(text: '✨ Profile Flair'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildShopCategoryList(
                      service,
                      const [
                        CosmicItemCategory.hat,
                        CosmicItemCategory.visor,
                      ],
                    ),
                    _buildShopCategoryList(
                      service,
                      const [
                        CosmicItemCategory.windowTheme,
                        CosmicItemCategory.gadget,
                      ],
                    ),
                    _buildShopCategoryList(
                      service,
                      const [
                        CosmicItemCategory.avatarFrame,
                        CosmicItemCategory.titleBadge,
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitorScreen(BuildContext context) {
    final ownerName = widget.visitedUserName ?? 'Explorer';
    final state = _visitorState ?? const UserCosmicState();

    return Scaffold(
      appBar: AppBar(
        title: Text('$ownerName\'s Space Cabin'),
        flexibleSpace: const CosmicAppBarFlexibleSpace(seed: 108),
      ),
      body: _isLoadingVisitor
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InteractiveSpaceCabinWidget(
                    cosmicState: state,
                    ownerName: ownerName,
                    isVisitor: true,
                  ),
                  const SizedBox(height: 16),
                  if (state.equippedTitle != 'title_none') ...[
                    Center(
                      child: CosmicTitleBadgeWidget(
                        titleId: state.equippedTitle,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Text('👋', style: TextStyle(fontSize: 20)),
                    label: Text(
                      'High-Five $ownerName\'s Byte! (+10 Bonus XP)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: () async {
                      final res =
                          await GamificationService.instance.highFiveUserRoom(
                        targetUserId: widget.visitedUserId!,
                        currentTargetState: state,
                      );
                      if (!context.mounted) return;
                      if (res.success) {
                        setState(() {
                          _visitorState =
                              state.copyWith(roomLikes: res.newLikes);
                        });
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor: res.success
                              ? Colors.deepPurple
                              : Colors.orange.shade800,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✨ $ownerName\'s Cabin Loadout',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '• Evolution: ${state.byteStageTitle}\n'
                            '• Unlocked Cosmic Items: ${state.unlockedIds.length}\n'
                            '• Active Gadgets: ${state.activeGadgets.isEmpty ? "None placed yet" : state.activeGadgets.length} (Tap them above!)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMiniGameActionButton({
    required String emoji,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.30),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopCategoryList(
    GamificationService service,
    List<CosmicItemCategory> categories,
  ) {
    final s = service.state;
    final items = GamificationService.catalog
        .where((i) => categories.contains(i.category))
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final isUnlocked = s.unlockedIds.contains(item.id);
        final bool isEquipped = switch (item.category) {
          CosmicItemCategory.hat => s.equippedHat == item.id,
          CosmicItemCategory.visor => s.equippedVisor == item.id,
          CosmicItemCategory.windowTheme => s.equippedWindow == item.id,
          CosmicItemCategory.gadget => s.activeGadgets.contains(item.id),
          CosmicItemCategory.avatarFrame => s.equippedFrame == item.id,
          CosmicItemCategory.titleBadge => s.equippedTitle == item.id,
        };

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEquipped
                  ? Colors.deepPurple
                  : (isUnlocked ? Colors.deepPurple.shade100 : Colors.grey.shade200),
              width: isEquipped ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: item.previewColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(item.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.rarityColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.rarityLabel,
                            style: TextStyle(
                              color: item.rarityColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isUnlocked)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEquipped
                        ? Colors.green.shade600
                        : Colors.deepPurple.shade50,
                    foregroundColor:
                        isEquipped ? Colors.white : Colors.deepPurple,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => service.equipItem(item),
                  child: Text(
                    isEquipped
                        ? (item.category == CosmicItemCategory.gadget
                            ? 'Placed ✓'
                            : 'Equipped ✓')
                        : (item.category == CosmicItemCategory.gadget
                            ? 'Place'
                            : 'Equip'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: service.spendableXp >= item.costXp
                        ? Colors.deepPurple
                        : Colors.grey.shade300,
                    foregroundColor: service.spendableXp >= item.costXp
                        ? Colors.white
                        : Colors.grey.shade600,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final ok = await service.purchaseItem(item);
                    if (!context.mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '🎉 Unlocked & equipped ${item.name}!',
                          ),
                          backgroundColor: Colors.deepPurple,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Need ${item.costXp} Spendable XP (you have ${service.spendableXp} XP).',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  child: Text(
                    '⚡ ${item.costXp} XP',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
