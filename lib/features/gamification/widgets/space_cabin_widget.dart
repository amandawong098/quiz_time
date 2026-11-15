import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/widgets/byte_mascot.dart';
import '../gamification_service.dart';

/// Renders a user's profile avatar with their equipped Cosmic Avatar Frame.
class CosmicAvatarFrame extends StatelessWidget {
  final String? avatarUrl;
  final String frameId;
  final double radius;
  final VoidCallback? onEditTap;

  const CosmicAvatarFrame({
    super.key,
    required this.avatarUrl,
    this.frameId = 'frame_default',
    this.radius = 44,
    this.onEditTap,
  });

  List<Color> _frameColors() {
    switch (frameId) {
      case 'frame_orbit':
        return const [Color(0xFF00E5FF), Color(0xFF38BDF8), Color(0xFF1D4ED8)];
      case 'frame_neon':
        return const [Color(0xFFF472B6), Color(0xFFD946EF), Color(0xFF7E22CE)];
      case 'frame_plasma':
        return const [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF047857)];
      case 'frame_supernova':
        return const [
          Color(0xFFFBBF24),
          Color(0xFFEC4899),
          Color(0xFF00E5FF),
          Color(0xFFFBBF24),
        ];
      default:
        return const [Color(0xFFFFD54F), Color(0xFFB388FF)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _frameColors();
    final isSpecial = frameId != 'frame_default';

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(isSpecial ? 4.5 : 3.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [...colors, colors.first]),
            boxShadow: isSpecial
                ? [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.55),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFF140D2E),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: (avatarUrl == null || avatarUrl!.isEmpty)
                  ? Icon(Icons.person, size: radius, color: Colors.white)
                  : null,
            ),
          ),
        ),
        if (frameId == 'frame_supernova')
          const Positioned(
            top: -12,
            child: Text('👑', style: TextStyle(fontSize: 20)),
          ),
        if (onEditTap != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: onEditTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD54F),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF140D2E),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.edit,
                  size: 15,
                  color: Color(0xFF140D2E),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Renders the user's equipped Cosmic Title badge pill.
class CosmicTitleBadgeWidget extends StatelessWidget {
  final String titleId;
  final bool compact;

  const CosmicTitleBadgeWidget({
    super.key,
    required this.titleId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (titleId == 'title_none' || titleId.isEmpty) {
      return const SizedBox.shrink();
    }
    final item = GamificationService.itemById(titleId);
    if (item == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: item.previewColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: item.previewColors.first.withValues(alpha: 0.40),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        item.name,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Interactive Byte's Space Cabin scene used in both the owner's Space Cabin Hub
/// and when visiting a friend's Space Cabin.
class InteractiveSpaceCabinWidget extends StatefulWidget {
  final UserCosmicState cosmicState;
  final String ownerName;
  final bool isVisitor;
  final VoidCallback? onGadgetTapped;

  const InteractiveSpaceCabinWidget({
    super.key,
    required this.cosmicState,
    required this.ownerName,
    this.isVisitor = false,
    this.onGadgetTapped,
  });

  @override
  State<InteractiveSpaceCabinWidget> createState() =>
      _InteractiveSpaceCabinWidgetState();
}

class _InteractiveSpaceCabinWidgetState
    extends State<InteractiveSpaceCabinWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;
  String? _activePopupText;
  String? _pulsingGadgetId;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  void _triggerGadgetInteraction(String id, String message) {
    SoundService.instance.playMascotChirp();
    setState(() {
      _pulsingGadgetId = id;
      _activePopupText = message;
    });
    widget.onGadgetTapped?.call();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _activePopupText == message) {
        setState(() {
          _pulsingGadgetId = null;
          _activePopupText = null;
        });
      }
    });
  }

  List<Color> _cabinBackgroundGradient(String windowId) {
    switch (windowId) {
      case 'win_mars':
        return const [
          Color(0xFF450A0A),
          Color(0xFF7F1D1D),
          Color(0xFF1F122B),
        ];
      case 'win_saturn':
        return const [
          Color(0xFF1E1B4B),
          Color(0xFF451A03),
          Color(0xFF171332),
        ];
      case 'win_cyber':
        return const [
          Color(0xFF3B0764),
          Color(0xFF701A75),
          Color(0xFF0F172A),
        ];
      case 'win_supernova':
        return const [
          Color(0xFF064E3B),
          Color(0xFF3B0764),
          Color(0xFF0F172A),
        ];
      default:
        return const [
          Color(0xFF0F0A26),
          Color(0xFF1E1446),
          Color(0xFF130D2E),
        ];
    }
  }

  Color _visorAccentColor(String visorId) {
    switch (visorId) {
      case 'visor_gold':
        return const Color(0xFFFFD54F);
      case 'visor_magenta':
        return const Color(0xFFF472B6);
      case 'visor_emerald':
        return const Color(0xFF34D399);
      case 'visor_rainbow':
        return const Color(0xFFE879F9);
      default:
        return const Color(0xFF00E5FF);
    }
  }

  Widget _buildHatOverlay(String hatId) {
    switch (hatId) {
      case 'hat_crown':
        return const Text('👑', style: TextStyle(fontSize: 30));
      case 'hat_grad':
        return const Text('🎓', style: TextStyle(fontSize: 30));
      case 'hat_wizard':
        return const Text('🧙', style: TextStyle(fontSize: 30));
      case 'hat_headphones':
        return const Text('🎧', style: TextStyle(fontSize: 28));
      case 'hat_astro':
        return Container(
          width: 58,
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF38BDF8), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.7),
                blurRadius: 10,
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.cosmicState;
    final bgGradient = _cabinBackgroundGradient(s.equippedWindow);
    final visorColor = _visorAccentColor(s.equippedVisor);
    final unlockedCount = s.unlockedIds.length;

    return Container(
      height: 285,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: visorColor.withValues(alpha: 0.45),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: bgGradient.first.withValues(alpha: 0.55),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Animated Space Window & Cabin Floor Painter
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ambientController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SpaceCabinScenePainter(
                      progress: _ambientController.value,
                      windowTheme: s.equippedWindow,
                      visorColor: visorColor,
                    ),
                  );
                },
              ),
            ),

            // 2. Top Cabin Status Bar (Stage + Trophy Shelf + Likes)
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Byte Evolution Stage & Trophy Shelf
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          s.byteStageTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (unlockedCount >= 7) ...[
                          const SizedBox(width: 6),
                          const Text('🥇', style: TextStyle(fontSize: 12)),
                        ],
                        if (s.byteBondXp >= 45) ...[
                          const SizedBox(width: 2),
                          const Text('🌟', style: TextStyle(fontSize: 12)),
                        ],
                      ],
                    ),
                  ),

                  // Room High-Fives / Likes Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👋', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          '${s.roomLikes} High-Fives',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Interactive Room Gadgets (Left & Right sides of Cabin)
            if (s.activeGadgets.contains('gad_lava_lamp'))
              Positioned(
                left: 18,
                bottom: 58,
                child: _buildInteractiveGadget(
                  id: 'gad_lava_lamp',
                  emoji: '🧪',
                  label: 'Plasma Lamp',
                  color: const Color(0xFFEC4899),
                  onTap: () => _triggerGadgetInteraction(
                    'gad_lava_lamp',
                    '🫧 Zero-G plasma bubbles floating!',
                  ),
                ),
              ),
            if (s.activeGadgets.contains('gad_arcade'))
              Positioned(
                left: 22,
                top: 68,
                child: _buildInteractiveGadget(
                  id: 'gad_arcade',
                  emoji: '🕹️',
                  label: 'Arcade',
                  color: const Color(0xFFF59E0B),
                  onTap: () => _triggerGadgetInteraction(
                    'gad_arcade',
                    '🎵 Retro cosmic high-score unlocked!',
                  ),
                ),
              ),
            if (s.activeGadgets.contains('gad_hologram'))
              Positioned(
                right: 22,
                top: 68,
                child: _buildInteractiveGadget(
                  id: 'gad_hologram',
                  emoji: '🌐',
                  label: 'Star Map',
                  color: const Color(0xFF00E5FF),
                  onTap: () => _triggerGadgetInteraction(
                    'gad_hologram',
                    '🌌 3D sector map scanning nearby galaxies!',
                  ),
                ),
              ),
            if (s.activeGadgets.contains('gad_robopet'))
              Positioned(
                right: 18,
                bottom: 58,
                child: _buildInteractiveGadget(
                  id: 'gad_robopet',
                  emoji: '🐾',
                  label: 'Astro-Pup',
                  color: const Color(0xFFF43F5E),
                  onTap: () => _triggerGadgetInteraction(
                    'gad_robopet',
                    '🐶 Astro-Pup did a zero-gravity backflip! ❤️',
                  ),
                ),
              ),

            // 4. Center Customized Byte Mascot with Visor Aura & Hat
            Positioned(
              top: 48,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Custom Visor / Core Aura Ring behind Byte
                      Container(
                        width: s.byteStage == 3
                            ? 150
                            : (s.byteStage == 2 ? 138 : 126),
                        height: s.byteStage == 3
                            ? 150
                            : (s.byteStage == 2 ? 138 : 126),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              visorColor.withValues(alpha: 0.36),
                              visorColor.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      ByteMascot(
                        size: s.byteStage == 3
                            ? 128
                            : (s.byteStage == 2 ? 118 : 110),
                        mood: s.isSupercharged
                            ? ByteMascotMood.happy
                            : ByteMascotMood.idle,
                        initialBubbleText: _activePopupText,
                        darkThemeContext: true,
                      ),
                      // Equipped Hat overlay
                      if (s.equippedHat != 'hat_none')
                        Positioned(
                          top: -4,
                          child: IgnorePointer(
                            child: _buildHatOverlay(s.equippedHat),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // 5. Bottom Energy & XP Multiplier Bar inside Cabin
            Positioned(
              bottom: 10,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.50),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: s.isSupercharged
                        ? const Color(0xFFFFD54F).withValues(alpha: 0.65)
                        : Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      s.isSupercharged
                          ? Icons.bolt_rounded
                          : Icons.battery_charging_full_rounded,
                      size: 16,
                      color: s.isSupercharged
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFF00E5FF),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Energy ${s.byteEnergy}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: s.byteEnergy / 100.0,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            s.isSupercharged
                                ? const Color(0xFFFFD54F)
                                : const Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: s.isSupercharged
                            ? const Color(0xFFFFD54F).withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s.isSupercharged ? '⚡ 1.5x XP ACTIVE' : '80% for 1.5x XP',
                        style: TextStyle(
                          color: s.isSupercharged
                              ? const Color(0xFFFFD54F)
                              : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
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

  Widget _buildInteractiveGadget({
    required String id,
    required String emoji,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isPulsing = _pulsingGadgetId == id;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isPulsing ? 1.22 : 1.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.elasticOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.75),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpaceCabinScenePainter extends CustomPainter {
  final double progress;
  final String windowTheme;
  final Color visorColor;

  _SpaceCabinScenePainter({
    required this.progress,
    required this.windowTheme,
    required this.visorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw Panoramic Spaceship Window Frame in upper-center
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.42),
        width: w * 0.58,
        height: h * 0.52,
      ),
      const Radius.circular(24),
    );

    final windowBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(windowRect, windowBorderPaint);

    // 2. Twinkling stars inside the window
    final rng = Random(42);
    final starPaint = Paint()..color = Colors.white;
    for (int i = 0; i < 24; i++) {
      final sx = w * 0.12 + rng.nextDouble() * (w * 0.76);
      final sy = h * 0.12 + rng.nextDouble() * (h * 0.58);
      final twinkle = 0.35 + 0.65 * sin(progress * 2 * pi + i);
      starPaint.color = Colors.white.withValues(alpha: twinkle.clamp(0.1, 1.0));
      canvas.drawCircle(Offset(sx, sy), 1.2 + (i % 2) * 0.8, starPaint);
    }

    // 3. Theme-specific celestial bodies in window
    if (windowTheme == 'win_mars') {
      final marsPaint = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFF87171), Color(0xFF991B1B)],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.66, h * 0.28), radius: 22),
        );
      canvas.drawCircle(Offset(w * 0.66, h * 0.28), 22, marsPaint);
    } else if (windowTheme == 'win_saturn') {
      final saturnCenter = Offset(w * 0.65, h * 0.30);
      final ringPaint = Paint()
        ..color = const Color(0xFFFBBF24).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.save();
      canvas.translate(saturnCenter.dx, saturnCenter.dy);
      canvas.rotate(-0.35);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 54, height: 16),
        ringPaint,
      );
      canvas.restore();
      final planetPaint = Paint()..color = const Color(0xFFF59E0B);
      canvas.drawCircle(saturnCenter, 14, planetPaint);
    } else if (windowTheme == 'win_supernova') {
      final auroraPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF34D399).withValues(alpha: 0.28),
            const Color(0xFFA855F7).withValues(alpha: 0.28),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.6));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.28),
          width: w * 0.52,
          height: 55,
        ),
        auroraPaint,
      );
    }

    // 4. Spaceship Cabin Metallic Deck Floor & Glowing Holo-Pad under Byte
    final deckPath = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.14, h * 0.74)
      ..lineTo(w * 0.86, h * 0.74)
      ..lineTo(w, h)
      ..close();
    final deckPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.black.withValues(alpha: 0.35),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, h * 0.74, w, h * 0.26));
    canvas.drawPath(deckPath, deckPaint);

    // Glowing levitation pad ellipse beneath Byte
    final padOval = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.77),
      width: 112,
      height: 22,
    );
    final padPaint = Paint()
      ..color = visorColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawOval(padOval, padPaint);

    final padRingPaint = Paint()
      ..color = visorColor.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(padOval, padRingPaint);
  }

  @override
  bool shouldRepaint(covariant _SpaceCabinScenePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.windowTheme != windowTheme ||
        oldDelegate.visorColor != visorColor;
  }
}
