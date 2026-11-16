import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/widgets/byte_mascot.dart';

/// Backwards-compatible wrapper that renders `UserByteAvatar` anywhere a framed
/// avatar is used.
class CosmicAvatarFrame extends StatelessWidget {
  final String? avatarUrl;
  final ByteAppearance? appearanceOverride;
  final double radius;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  const CosmicAvatarFrame({
    super.key,
    this.avatarUrl,
    this.appearanceOverride,
    this.radius = 44,
    this.isCurrentUser = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return UserByteAvatar(
      avatarUrl: avatarUrl,
      appearanceOverride: appearanceOverride,
      radius: radius,
      isCurrentUser: isCurrentUser,
      onTap: onTap,
    );
  }
}

/// Chunky 3D-beveled game button used throughout the Byte Mini-Game HUD.
class GameBevelButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color topColor;
  final Color bottomColor;
  final Color bevelColor;
  final Color borderColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GameBevelButton({
    super.key,
    required this.child,
    this.onTap,
    this.topColor = const Color(0xFF8B5CF6),
    this.bottomColor = const Color(0xFF6D28D9),
    this.bevelColor = const Color(0xFF4C1D95),
    this.borderColor = const Color(0xFFC4B5FD),
    this.borderRadius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });

  @override
  State<GameBevelButton> createState() => _GameBevelButtonState();
}

class _GameBevelButtonState extends State<GameBevelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final double pressOffset = _pressed ? 3.0 : 0.0;
    final double shadowDepth = _pressed ? 1.5 : 4.5;

    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        transform: Matrix4.translationValues(0, pressOffset, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [widget.topColor, widget.bottomColor],
          ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: widget.borderColor, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: widget.bevelColor,
              offset: Offset(0, shadowDepth),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: Offset(0, shadowDepth + 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Circular floating game action orb (like Shopee Pets side action icons).
class GameFloatingActionOrb extends StatelessWidget {
  final String emoji;
  final String label;
  final String? badgeText;
  final Color badgeColor;
  final Color glowColor;
  final VoidCallback onTap;

  const GameFloatingActionOrb({
    super.key,
    required this.emoji,
    required this.label,
    this.badgeText,
    this.badgeColor = const Color(0xFF10B981),
    this.glowColor = const Color(0xFF38BDF8),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glowColor.withValues(alpha: 0.45),
                      const Color(0xFF1E1B4B).withValues(alpha: 0.92),
                    ],
                  ),
                  border: Border.all(
                    color: glowColor.withValues(alpha: 0.85),
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.38),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                    const BoxShadow(
                      color: Color(0xFF090514),
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 25)),
                ),
              ),
              // Glossy top crescent reflection
              Positioned(
                top: 4,
                child: Container(
                  width: 30,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (badgeText != null)
                Positioned(
                  top: -5,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      badgeText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen 2D Game World Canvas that renders the selected Stage World,
/// animated stars/nebula/grid, and the 3D Holographic Stage Pedestal under Byte.
class GameStageWorldCanvas extends StatefulWidget {
  final String stageId;
  final Offset pedestalCenterFraction;

  const GameStageWorldCanvas({
    super.key,
    required this.stageId,
    this.pedestalCenterFraction = const Offset(0.5, 0.50),
  });

  @override
  State<GameStageWorldCanvas> createState() => _GameStageWorldCanvasState();
}

class _GameStageWorldCanvasState extends State<GameStageWorldCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _worldController;

  @override
  void initState() {
    super.initState();
    _worldController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _worldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _worldController,
      builder: (context, _) {
        return CustomPaint(
          painter: _GameStageWorldPainter(
            stageId: widget.stageId,
            phase: _worldController.value,
            pedestalCenterFraction: widget.pedestalCenterFraction,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _GameStageWorldPainter extends CustomPainter {
  final String stageId;
  final double phase;
  final Offset pedestalCenterFraction;

  _GameStageWorldPainter({
    required this.stageId,
    required this.phase,
    required this.pedestalCenterFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double px = w * pedestalCenterFraction.dx;
    final double py = h * pedestalCenterFraction.dy;

    List<Color> skyColors;
    Color pedestalGlow;
    Color pedestalCore;

    switch (stageId) {
      case 'stage_mars':
        skyColors = const [
          Color(0xFF1F0505),
          Color(0xFF5C1111),
          Color(0xFF9A3412),
          Color(0xFF2A0808),
        ];
        pedestalGlow = const Color(0xFFFB923C);
        pedestalCore = const Color(0xFFFDE047);
        break;
      case 'stage_saturn':
        skyColors = const [
          Color(0xFF041322),
          Color(0xFF0C3B5E),
          Color(0xFF0284C7),
          Color(0xFF061A2E),
        ];
        pedestalGlow = const Color(0xFF38BDF8);
        pedestalCore = const Color(0xFFE0F2FE);
        break;
      case 'stage_cyber':
        skyColors = const [
          Color(0xFF090418),
          Color(0xFF2E094E),
          Color(0xFF831843),
          Color(0xFF11052C),
        ];
        pedestalGlow = const Color(0xFFF43F5E);
        pedestalCore = const Color(0xFF00E5FF);
        break;
      case 'stage_supernova':
        skyColors = const [
          Color(0xFF1C0D02),
          Color(0xFF6B3406),
          Color(0xFFB45309),
          Color(0xFF291303),
        ];
        pedestalGlow = const Color(0xFFFACC15);
        pedestalCore = const Color(0xFFFFFFFF);
        break;
      case 'stage_nebula':
      default:
        skyColors = const [
          Color(0xFF090418),
          Color(0xFF1E0B4C),
          Color(0xFF3B1582),
          Color(0xFF12072B),
        ];
        pedestalGlow = const Color(0xFF8B5CF6);
        pedestalCore = const Color(0xFF00E5FF);
        break;
    }

    // 1. Full-Screen Sky Gradient
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: skyColors,
          stops: const [0.0, 0.35, 0.72, 1.0],
        ).createShader(Offset.zero & size),
    );

    // 2. Twinkling Starfield across upper sky
    final rng = Random(77);
    for (int i = 0; i < 42; i++) {
      final double sx = rng.nextDouble() * w;
      final double sy = rng.nextDouble() * h * 0.65;
      final double twinkle =
          0.30 + 0.70 * (0.5 + 0.5 * sin(phase * 2 * pi + i * 0.8));
      final double r = 1.0 + (i % 3) * 0.7;
      canvas.drawCircle(
        Offset(sx, sy),
        r,
        Paint()..color = Colors.white.withValues(alpha: twinkle * 0.85),
      );
    }

    // 3. Stage-Specific World Scenery
    if (stageId == 'stage_mars') {
      // Twin moons of Mars
      canvas.drawCircle(
        Offset(w * 0.22, h * 0.16),
        22,
        Paint()..color = const Color(0xFFFED7AA).withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        Offset(w * 0.78, h * 0.22),
        12,
        Paint()..color = const Color(0xFFFDBA74).withValues(alpha: 0.7),
      );
      // Martian dunes horizon
      final Path dunes = Path()
        ..moveTo(0, py + 10)
        ..quadraticBezierTo(w * 0.28, py - 35, w * 0.55, py + 5)
        ..quadraticBezierTo(w * 0.80, py + 35, w, py - 20)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        dunes,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7C2D12), Color(0xFF3B0A0A)],
          ).createShader(Rect.fromLTWH(0, py - 40, w, h - py + 40)),
      );
    } else if (stageId == 'stage_saturn') {
      // Giant Ringed Saturn in top-right sky
      final Offset saturnCenter = Offset(w * 0.75, h * 0.18);
      canvas.save();
      canvas.translate(saturnCenter.dx, saturnCenter.dy);
      canvas.rotate(-0.3);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 120, height: 32),
        Paint()
          ..color = const Color(0xFF7DD3FC).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8,
      );
      canvas.drawCircle(
        Offset.zero,
        28,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFDE68A), Color(0xFF38BDF8)],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 28)),
      );
      canvas.restore();
    } else if (stageId == 'stage_cyber') {
      // Synthwave Retro Sun & 3D Perspective Grid Floor
      final Offset sunCenter = Offset(px, py - 45);
      canvas.drawCircle(
        sunCenter,
        75,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFACC15), Color(0xFFF43F5E), Color(0xFF9333EA)],
          ).createShader(Rect.fromCircle(center: sunCenter, radius: 75)),
      );
      // Perspective floor grid lines below horizon
      final Paint gridPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
        ..strokeWidth = 1.4;
      final double horizonY = py - 10;
      for (int i = -6; i <= 6; i++) {
        canvas.drawLine(
          Offset(px + i * 18.0, horizonY),
          Offset(px + i * 95.0, h),
          gridPaint,
        );
      }
      for (int r = 1; r <= 6; r++) {
        final double gy = horizonY + pow(r / 6.0, 1.6) * (h - horizonY);
        canvas.drawLine(Offset(0, gy), Offset(w, gy), gridPaint);
      }
    } else if (stageId == 'stage_supernova') {
      // Rotating golden supernova rays behind Byte
      canvas.save();
      canvas.translate(px, py - 70);
      canvas.rotate(phase * 2 * pi * 0.25);
      for (int i = 0; i < 12; i++) {
        canvas.rotate(pi / 6);
        final Path ray = Path()
          ..moveTo(0, 0)
          ..lineTo(-18, -220)
          ..lineTo(18, -220)
          ..close();
        canvas.drawPath(
          ray,
          Paint()..color = const Color(0xFFFACC15).withValues(alpha: 0.09),
        );
      }
      canvas.restore();
    }

    // 4. Spotlight Beam shining down onto the Holographic Stage Pedestal
    final Path beam = Path()
      ..moveTo(px - 55, 0)
      ..lineTo(px + 55, 0)
      ..lineTo(px + 135, py + 15)
      ..lineTo(px - 135, py + 15)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            pedestalGlow.withValues(alpha: 0.0),
            pedestalGlow.withValues(alpha: 0.14),
            pedestalCore.withValues(alpha: 0.22),
          ],
        ).createShader(Rect.fromLTWH(px - 140, 0, 280, py + 20)),
    );

    // 5. 3D Holographic Stage Pedestal under Byte
    final double pulse = 0.92 + 0.08 * sin(phase * 4 * pi);

    // Pedestal outer energy ring
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(px, py + 18),
        width: 220 * pulse,
        height: 54 * pulse,
      ),
      Paint()
        ..color = pedestalGlow.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Metallic 3D Pedestal Base Tier
    final Rect baseOval = Rect.fromCenter(
      center: Offset(px, py + 24),
      width: 196,
      height: 46,
    );
    canvas.drawOval(
      baseOval,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF311068)],
        ).createShader(baseOval),
    );
    canvas.drawOval(
      baseOval,
      Paint()
        ..color = pedestalGlow.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // Glowing Inner Hologram Pad
    final Rect innerOval = Rect.fromCenter(
      center: Offset(px, py + 16),
      width: 154,
      height: 34,
    );
    canvas.drawOval(
      innerOval,
      Paint()
        ..shader = RadialGradient(
          colors: [
            pedestalCore.withValues(alpha: 0.85),
            pedestalGlow.withValues(alpha: 0.55),
            const Color(0xFF1E1B4B),
          ],
        ).createShader(innerOval),
    );
    canvas.drawOval(
      innerOval,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _GameStageWorldPainter oldDelegate) {
    return oldDelegate.stageId != stageId ||
        oldDelegate.phase != phase ||
        oldDelegate.pedestalCenterFraction != pedestalCenterFraction;
  }
}
