import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/widgets/byte_mascot.dart';
import '../gamification_service.dart';
import '../widgets/space_cabin_widget.dart';

class SpaceCabinScreen extends StatefulWidget {
  final String? visitedUserId;
  final String? visitedUserName;
  final String? visitedUserAvatarUrl;

  const SpaceCabinScreen({
    super.key,
    this.visitedUserId,
    this.visitedUserName,
    this.visitedUserAvatarUrl,
  });

  bool get isVisitorMode => visitedUserId != null;

  @override
  State<SpaceCabinScreen> createState() => _SpaceCabinScreenState();
}

class _SpaceCabinScreenState extends State<SpaceCabinScreen>
    with SingleTickerProviderStateMixin {
  CosmicItemCategory _selectedCategory = CosmicItemCategory.costume;
  CosmicShopItem? _previewLockedItem;
  bool _dockMinimized = false;

  UserCosmicState? _visitedState;
  bool _loadingVisited = false;

  // Celebration bounce when unlocking a new item
  late final AnimationController _celebrateController;
  String? _stageBannerText;

  @override
  void initState() {
    super.initState();
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GamificationService>().loadForCurrentUser();
      if (widget.isVisitorMode) {
        _loadVisitedUserCabin();
      }
      SoundService.instance.startMiniGameMusic();
    });
  }

  @override
  void dispose() {
    SoundService.instance.stopMiniGameMusic();
    _celebrateController.dispose();
    super.dispose();
  }

  Future<void> _loadVisitedUserCabin() async {
    setState(() => _loadingVisited = true);
    final state = await GamificationService.instance.fetchOtherUserCosmicState(
      widget.visitedUserId!,
      fallbackAvatarUrl: widget.visitedUserAvatarUrl,
    );
    if (mounted) {
      setState(() {
        _visitedState = state;
        _loadingVisited = false;
      });
    }
  }

  void _triggerStageBanner(String text) {
    setState(() {
      _stageBannerText = text;
    });
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted && _stageBannerText == text) {
        setState(() {
          _stageBannerText = null;
        });
      }
    });
  }

  Future<void> _handleItemTileTap(
    GamificationService service,
    CosmicShopItem item,
  ) async {
    SoundService.instance.playOptionSelect();
    if (service.isOwned(item.id)) {
      setState(() {
        _previewLockedItem = null;
      });
      await service.equipItem(item);
      _triggerStageBanner('✨ Equipped ${item.name}!');
    } else {
      // Live preview locked item right on the stage!
      setState(() {
        _previewLockedItem = item;
      });
      _triggerStageBanner('👀 Previewing ${item.name} (${item.costXp} XP)');
    }
  }

  Future<void> _handleUnlockPreviewedItem(
    GamificationService service,
    CosmicShopItem item,
  ) async {
    if (service.spendableXp < item.costXp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Need ${item.costXp} Spendable XP (You have ${service.spendableXp} XP). Complete lessons, flashcards, or quizzes to earn more! 🚀',
          ),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    final prevMult = service.state.quizXpMultiplier;
    final ok = await service.purchaseAndEquip(item);
    if (!mounted) return;
    if (ok) {
      SoundService.instance.playQuizComplete();
      setState(() {
        _previewLockedItem = null;
      });
      _celebrateController.forward(from: 0.0);
      final newMult = service.state.quizXpMultiplier;
      if (newMult > prevMult) {
        _triggerStageBanner(
          '🎉 UNLOCKED ${item.name.toUpperCase()}! QUIZ BOOST UPGRADED TO ${newMult}x!',
        );
      } else {
        _triggerStageBanner('🎉 UNLOCKED & EQUIPPED: ${item.name.toUpperCase()}!');
      }
    }
  }

  void _openSpendableXpGuideDialog(GamificationService service) {
    SoundService.instance.playOptionSelect();
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFACC15),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFACC15).withValues(alpha: 0.25),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('⚡', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text(
                          'SPENDABLE XP GUIDE',
                          style: TextStyle(
                            color: Color(0xFFFACC15),
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Available Spendable XP:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${service.spendableXp} XP',
                        style: const TextStyle(
                          color: Color(0xFFFACC15),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildGuideRow(
                  '💡',
                  'What is Spendable XP?',
                  'It is your XP budget for customizing Byte. Spending it here NEVER lowers your Leaderboard or Lifetime XP!',
                ),
                const SizedBox(height: 10),
                _buildGuideRow(
                  '📚',
                  'How to Earn More',
                  'Complete lessons, flashcards, and quizzes to earn Lifetime XP — every point you earn also adds to your Spendable XP.',
                ),
                const SizedBox(height: 10),
                _buildGuideRow(
                  '🎭',
                  'What It Is Used For',
                  'Unlock Suits, Body Paints, Visor Eyes, and Stage Worlds for Byte. Unlocking items also increases your permanent Quiz XP Boost!',
                ),
                const SizedBox(height: 18),
                Center(
                  child: GameBevelButton(
                    topColor: const Color(0xFFFACC15),
                    bottomColor: const Color(0xFFEAB308),
                    bevelColor: const Color(0xFFA16207),
                    borderColor: const Color(0xFFFEF08A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 10,
                    ),
                    onTap: () => Navigator.pop(ctx),
                    child: const Text(
                      'GOT IT!',
                      style: TextStyle(
                        color: Color(0xFF1E1B4B),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
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

  void _openCollectionBoostDialog(GamificationService service) {
    SoundService.instance.playOptionSelect();
    final state = service.state;
    final unlocked = state.unlockedPaidCount;
    final tiers = [
      (label: '0–1 Unlocks', mult: '1.0x', desc: 'Starter Rate', min: 0),
      (label: '2–4 Unlocks', mult: '1.1x', desc: '+10% Quiz XP', min: 2),
      (label: '5–8 Unlocks', mult: '1.2x', desc: '+20% Quiz XP', min: 5),
      (label: '9–13 Unlocks', mult: '1.3x', desc: '+30% Quiz XP', min: 9),
      (label: '14+ Unlocks', mult: '1.5x', desc: '+50% MAX', min: 14),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF38BDF8),
                width: 2.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('🚀', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text(
                          'COLLECTION XP BOOST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Unlocking Byte outfits & worlds permanently boosts the XP you earn from quizzes — wear whatever look you want!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                ...tiers.map((t) {
                  final reached = unlocked >= t.min;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: reached
                          ? const Color(0xFF10B981).withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: reached
                            ? const Color(0xFF34D399)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                reached ? '✅' : '🔒',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  t.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${t.mult} (${t.desc})',
                          style: TextStyle(
                            color: reached
                                ? const Color(0xFF34D399)
                                : const Color(0xFF38BDF8),
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 6),
                Text(
                  'Your Collection: $unlocked / ${state.unlockedPaidCount + GamificationService.catalog.where((i) => i.costXp > 0 && !service.isOwned(i.id)).length} items unlocked',
                  style: const TextStyle(
                    color: Color(0xFFFACC15),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideRow(String emoji, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GamificationService>();
    final bool isVisitor = widget.isVisitorMode;
    final UserCosmicState activeState =
        isVisitor ? (_visitedState ?? const UserCosmicState()) : service.state;

    // Live stage appearance: if user tapped a locked item, try it on live!
    final ByteAppearance stageAppearance =
        (!isVisitor && _previewLockedItem != null)
            ? _previewLockedItem!.previewOn(activeState.appearance)
            : activeState.appearance;

    final double pedestalYFraction =
        (isVisitor || _dockMinimized) ? 0.62 : 0.45;

    final int unlockedCount = activeState.unlockedPaidCount;
    final int? nextGoal = activeState.nextBoostThreshold;

    return Scaffold(
      backgroundColor: const Color(0xFF090418),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ===================================================================
          // 1. FULL-BLEED 2D GAME WORLD & HOLOGRAPHIC PEDESTAL CANVAS
          // ===================================================================
          GameStageWorldCanvas(
            stageId: stageAppearance.stageId,
            pedestalCenterFraction: Offset(0.5, pedestalYFraction),
          ),

          // ===================================================================
          // 2. CENTER INTERACTIVE BYTE CHARACTER ON STAGE
          // ===================================================================
          Align(
            alignment: Alignment(
              0,
              (pedestalYFraction - 0.5) * 2.0 - 0.16,
            ),
            child: _loadingVisited
                ? const CircularProgressIndicator(color: Color(0xFF00E5FF))
                : AnimatedBuilder(
                    animation: _celebrateController,
                    builder: (context, child) {
                      final double angle = _celebrateController.isAnimating
                          ? sin(_celebrateController.value * 4 * pi) * 0.14
                          : 0.0;
                      final double scale = _celebrateController.isAnimating
                          ? 1.0 + 0.12 * sin(_celebrateController.value * pi)
                          : 1.0;

                      return Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: angle,
                          child: ByteMascot(
                            size: (isVisitor || _dockMinimized) ? 230 : 190,
                            mood: activeState.hasActiveBoost
                                ? ByteMascotMood.happy
                                : ByteMascotMood.idle,
                            darkThemeContext: true,
                            appearance: stageAppearance,
                            useCurrentUserAppearance: false,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ===================================================================
          // 3. FLOATING STAGE FEEDBACK TOAST BANNER
          // ===================================================================
          if (_stageBannerText != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 28,
              right: 28,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFACC15),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    _stageBannerText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),

          // ===================================================================
          // 4. TOP GAME HUD BAR (Exit Button, Collection XP Boost, Spendable XP)
          // ===================================================================
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // 3D Game Exit Button
                    GameBevelButton(
                      topColor: const Color(0xFFF43F5E),
                      bottomColor: const Color(0xFFE11D48),
                      bevelColor: const Color(0xFF881337),
                      borderColor: const Color(0xFFFDA4AF),
                      borderRadius: 14,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'EXIT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Mini-Game Music Toggle Button
                    AnimatedBuilder(
                      animation: SoundService.instance,
                      builder: (context, _) {
                        final musicOn = SoundService.instance.miniGameMusicEnabled;
                        return GameBevelButton(
                          topColor: musicOn
                              ? const Color(0xFF6D28D9)
                              : const Color(0xFF475569),
                          bottomColor: musicOn
                              ? const Color(0xFF5B21B6)
                              : const Color(0xFF334155),
                          bevelColor: musicOn
                              ? const Color(0xFF3B0764)
                              : const Color(0xFF1E293B),
                          borderColor: musicOn
                              ? const Color(0xFFC4B5FD)
                              : const Color(0xFF94A3B8),
                          borderRadius: 14,
                          padding: const EdgeInsets.all(8),
                          onTap: () => SoundService.instance.toggleMiniGameMusic(),
                          child: Icon(
                            musicOn
                                ? Icons.music_note_rounded
                                : Icons.music_off_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),

                    // Center Collection XP Boost Meter (Tap for Tier Guide)
                    Expanded(
                      child: GestureDetector(
                        onTap: isVisitor
                            ? null
                            : () => _openCollectionBoostDialog(service),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0F172A).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: activeState.hasActiveBoost
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF38BDF8),
                              width: 1.8,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFF090514),
                                offset: Offset(0, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      isVisitor
                                          ? '${widget.visitedUserName ?? "Explorer"}\'s Byte'
                                          : (activeState.hasActiveBoost
                                              ? '🚀 ${activeState.quizXpMultiplier}x QUIZ XP (+${activeState.boostPercent}%)'
                                              : '🚀 QUIZ BOOST ${activeState.quizXpMultiplier}x'),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: activeState.hasActiveBoost
                                            ? const Color(0xFF34D399)
                                            : Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    nextGoal != null
                                        ? '$unlockedCount/$nextGoal'
                                        : 'MAX',
                                    style: const TextStyle(
                                      color: Color(0xFFFACC15),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: activeState.boostProgress,
                                  minHeight: 6,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    activeState.hasActiveBoost
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF38BDF8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Right Spendable XP Pill (Tap for Guide Popup)
                    if (!isVisitor)
                      GestureDetector(
                        onTap: () => _openSpendableXpGuideDialog(service),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF311068), Color(0xFF1E1B4B)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFACC15),
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFF090514),
                                offset: Offset(0, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'SPENDABLE XP',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  Text(
                                    '⚡ ${service.spendableXp}',
                                    style: const TextStyle(
                                      color: Color(0xFFFACC15),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFFFACC15),
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ===================================================================
          // 5. BOTTOM GAME WARDROBE DOCK (OR READ-ONLY VISITOR BAR)
          // ===================================================================
          Align(
            alignment: Alignment.bottomCenter,
            child: isVisitor
                ? _buildVisitorBottomBar()
                : _buildOwnerWardrobeDock(service),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorBottomBar() {
    final name = widget.visitedUserName ?? 'Explorer';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B5CF6),
              width: 1.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('👀', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Viewing $name\'s Byte Stage',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerWardrobeDock(GamificationService service) {
    final items = GamificationService.catalog
        .where((i) => i.category == _selectedCategory)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating "UNLOCK THIS LOOK" Button if previewing a locked item
        if (_previewLockedItem != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 18, right: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: GameBevelButton(
                    topColor: const Color(0xFF10B981),
                    bottomColor: const Color(0xFF059669),
                    bevelColor: const Color(0xFF064E3B),
                    borderColor: const Color(0xFF6EE7B7),
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    onTap: () => _handleUnlockPreviewedItem(
                      service,
                      _previewLockedItem!,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔓', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'UNLOCK ${_previewLockedItem!.name.toUpperCase()} • ${_previewLockedItem!.costXp} XP',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GameBevelButton(
                  topColor: const Color(0xFF475569),
                  bottomColor: const Color(0xFF334155),
                  bevelColor: const Color(0xFF0F172A),
                  borderColor: const Color(0xFF94A3B8),
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  onTap: () {
                    SoundService.instance.playOptionSelect();
                    setState(() => _previewLockedItem = null);
                  },
                  child: const Icon(
                    Icons.replay_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

        // Minimize / Expand Wardrobe Handle Pill
        SafeArea(
          top: false,
          bottom: _dockMinimized,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: 16,
                bottom: _dockMinimized ? 14 : 6,
              ),
              child: GestureDetector(
                onTap: () {
                  SoundService.instance.playTabSwitch();
                  setState(() => _dockMinimized = !_dockMinimized);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _dockMinimized
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _dockMinimized ? 'OPEN WARDROBE' : 'STAGE VIEW',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Main Game Dock Container
        if (!_dockMinimized)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xF51A0E36),
                  Color(0xFA0D061F),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: const Border(
                top: BorderSide(color: Color(0xFF8B5CF6), width: 2.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 4 Game Category Tabs
                    Row(
                      children: [
                        _buildCategoryTab(
                          CosmicItemCategory.costume,
                          '🎭',
                          'SUITS',
                        ),
                        const SizedBox(width: 6),
                        _buildCategoryTab(
                          CosmicItemCategory.body,
                          '🎨',
                          'PAINT',
                        ),
                        const SizedBox(width: 6),
                        _buildCategoryTab(
                          CosmicItemCategory.eye,
                          '👀',
                          'EYES',
                        ),
                        const SizedBox(width: 6),
                        _buildCategoryTab(
                          CosmicItemCategory.stage,
                          '🪐',
                          'WORLD',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Horizontal Live-Preview Game Cards Carousel
                    SizedBox(
                      height: 146,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _buildGameWardrobeCard(service, item);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryTab(
    CosmicItemCategory category,
    String emoji,
    String label,
  ) {
    final bool selected = _selectedCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          SoundService.instance.playTabSwitch();
          setState(() {
            _selectedCategory = category;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC4B5FD)
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 1.8 : 1.0,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0xFF4C1D95),
                      offset: Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameWardrobeCard(
    GamificationService service,
    CosmicShopItem item,
  ) {
    final bool owned = service.isOwned(item.id);
    final bool equipped = service.isEquipped(item);
    final bool isPreviewing = _previewLockedItem?.id == item.id;

    // Build a live mini Byte appearance showing this specific item on the user's Byte!
    final ByteAppearance cardPreview = item.previewOn(service.state.appearance);

    final Color borderColor = equipped
        ? const Color(0xFF34D399)
        : (isPreviewing
            ? const Color(0xFFFACC15)
            : item.rarityColor.withValues(alpha: 0.55));

    return GestureDetector(
      onTap: () => _handleItemTileTap(service, item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 108,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: equipped
                ? [
                    const Color(0xFF065F46).withValues(alpha: 0.65),
                    const Color(0xFF064E3B).withValues(alpha: 0.85),
                  ]
                : (isPreviewing
                    ? [
                        const Color(0xFF78350F).withValues(alpha: 0.7),
                        const Color(0xFF451A03).withValues(alpha: 0.9),
                      ]
                    : [
                        const Color(0xFF2E1065).withValues(alpha: 0.75),
                        const Color(0xFF0F172A).withValues(alpha: 0.92),
                      ]),
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: (equipped || isPreviewing) ? 2.4 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Live Drawn Mini Byte Avatar Preview!
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserByteAvatar(
                  appearanceOverride: cardPreview,
                  radius: 30,
                ),
                if (!owned)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: item.rarityColor,
                          width: 1.4,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFFFACC15),
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),

            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),

            // Bottom Status / Cost Pill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: equipped
                    ? const Color(0xFF10B981)
                    : (owned
                        ? Colors.white.withValues(alpha: 0.14)
                        : const Color(0xFFFACC15).withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                equipped
                    ? 'EQUIPPED'
                    : (owned ? 'WEAR' : '${item.costXp} XP'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: equipped
                      ? const Color(0xFF052E16)
                      : (owned ? Colors.white : const Color(0xFFFACC15)),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
