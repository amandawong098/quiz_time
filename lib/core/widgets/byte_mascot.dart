import 'dart:math';
import 'package:flutter/material.dart';
import '../services/sound_service.dart';

enum ByteMascotMood {
  idle,
  happy,
  curious,
}

/// "Byte" the Astro-Bot Mascot with continuous subtle zero-gravity floating,
/// natural blinking, orbiting star particle, and interactive tap-to-chirp/wave.
class ByteMascot extends StatefulWidget {
  final double size;
  final ByteMascotMood mood;
  final List<String>? tapMessages;
  final String? initialBubbleText;
  final bool darkThemeContext;

  const ByteMascot({
    super.key,
    this.size = 110,
    this.mood = ByteMascotMood.idle,
    this.tapMessages,
    this.initialBubbleText,
    this.darkThemeContext = false,
  });

  @override
  State<ByteMascot> createState() => _ByteMascotState();
}

class _ByteMascotState extends State<ByteMascot>
    with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _tapController;

  int _messageIndex = -1;
  String? _activeBubbleText;

  static const List<String> _defaultMessages = [
    'Beep boop! Ready to explore the cosmos? ✨',
    'Every quiz brings you closer to Cosmic Legend! 🚀',
    'Tip: Keep your streak alive for bonus points! 🔥',
    'Byte is cheering for you, Stargazer! 🌟',
  ];

  @override
  void initState() {
    super.initState();
    _activeBubbleText = widget.initialBubbleText;

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
  }

  @override
  void didUpdateWidget(covariant ByteMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialBubbleText != oldWidget.initialBubbleText &&
        _messageIndex == -1) {
      _activeBubbleText = widget.initialBubbleText;
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    SoundService.instance.playMascotChirp();
    _tapController.forward(from: 0.0);

    final messages = (widget.tapMessages != null &&
            widget.tapMessages!.isNotEmpty)
        ? widget.tapMessages!
        : _defaultMessages;

    setState(() {
      _messageIndex = (_messageIndex + 1) % messages.length;
      _activeBubbleText = messages[_messageIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Optional Interactive Speech Bubble
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _activeBubbleText != null
              ? Container(
                  key: ValueKey<String>(_activeBubbleText!),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  constraints: const BoxConstraints(maxWidth: 260),
                  decoration: BoxDecoration(
                    color: widget.darkThemeContext
                        ? const Color(0xFF1F1147).withValues(alpha: 0.92)
                        : Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.darkThemeContext
                          ? const Color(0xFFFFD54F).withValues(alpha: 0.65)
                          : Colors.deepPurple.shade200,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    _activeBubbleText!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.darkThemeContext
                          ? Colors.white
                          : Colors.deepPurple.shade900,
                      height: 1.25,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Interactive Mascot Canvas
        GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedBuilder(
              animation: Listenable.merge([_idleController, _tapController]),
              builder: (context, _) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _ByteAstroBotPainter(
                    idlePhase: _idleController.value,
                    tapProgress: _tapController.value,
                    mood: widget.mood,
                    darkThemeContext: widget.darkThemeContext,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ByteAstroBotPainter extends CustomPainter {
  final double idlePhase;
  final double tapProgress;
  final ByteMascotMood mood;
  final bool darkThemeContext;

  _ByteAstroBotPainter({
    required this.idlePhase,
    required this.tapProgress,
    required this.mood,
    required this.darkThemeContext,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w * 0.5;

    final bool isExcited =
        (tapProgress > 0.0 && tapProgress < 1.0) || mood == ByteMascotMood.happy;

    // Smooth zero-gravity bobbing (-4.5% to +4.5% of height)
    final double idleBob = sin(idlePhase * 2 * pi) * (h * 0.042);
    // Tap jump arc
    final double tapJump = tapProgress > 0.0
        ? -sin(tapProgress * pi) * (h * 0.11)
        : 0.0;
    final double dy = idleBob + tapJump;

    // Gentle head/body tilt when excited or curious
    double tiltAngle = sin(idlePhase * 2 * pi) * 0.035;
    if (mood == ByteMascotMood.curious) {
      tiltAngle += 0.06 * sin(idlePhase * 2 * pi);
    }
    if (tapProgress > 0.0 && tapProgress < 1.0) {
      tiltAngle += sin(tapProgress * 2 * pi) * 0.12;
    }

    // 1. Floating shadow / cosmic pad underneath Byte
    final double shadowScale =
        (1.0 - ((-dy) / (h * 0.25))).clamp(0.65, 1.15);
    final Paint shadowPaint = Paint()
      ..color = (darkThemeContext
              ? const Color(0xFF7C4DFF)
              : Colors.deepPurple)
          .withValues(alpha: 0.22 * shadowScale)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, h * 0.91),
        width: w * 0.42 * shadowScale,
        height: h * 0.07 * shadowScale,
      ),
      shadowPaint,
    );

    // 2. Soft background aura glow behind Byte
    final Paint auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7C4DFF).withValues(alpha: isExcited ? 0.30 : 0.16),
          const Color(0xFF7C4DFF).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset(cx, h * 0.48 + dy), radius: w * 0.46),
      );
    canvas.drawCircle(Offset(cx, h * 0.48 + dy), w * 0.46, auraPaint);

    canvas.save();
    canvas.translate(cx, h * 0.50 + dy);
    canvas.rotate(tiltAngle);

    // 3. Antenna on top of helmet
    final double antennaSway = sin(idlePhase * 2 * pi + 1.1) * (w * 0.025);
    final Paint stemPaint = Paint()
      ..color = const Color(0xFFB39DDB)
      ..strokeWidth = w * 0.032
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Path stemPath = Path()
      ..moveTo(0, -h * 0.26)
      ..quadraticBezierTo(
        antennaSway * 0.5,
        -h * 0.34,
        antennaSway,
        -h * 0.39,
      );
    canvas.drawPath(stemPath, stemPaint);

    // Glowing orb tip on antenna
    final Offset orbCenter = Offset(antennaSway, -h * 0.405);
    final double orbPulse = 0.85 + 0.25 * sin(idlePhase * 4 * pi);
    final Paint orbGlowPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(orbCenter, w * 0.055 * orbPulse, orbGlowPaint);
    canvas.drawCircle(
      orbCenter,
      w * 0.036,
      Paint()..color = const Color(0xFFFFCA28),
    );
    canvas.drawCircle(
      orbCenter + Offset(-w * 0.01, -w * 0.01),
      w * 0.012,
      Paint()..color = Colors.white,
    );

    // 4. Lower Astro-Pod Body (Torso)
    final RRect bodyRRect = RRect.fromRectAndCorners(
      Rect.fromCenter(
        center: Offset(0, h * 0.19),
        width: w * 0.38,
        height: h * 0.24,
      ),
      topLeft: Radius.circular(w * 0.10),
      topRight: Radius.circular(w * 0.10),
      bottomLeft: Radius.circular(w * 0.19),
      bottomRight: Radius.circular(w * 0.19),
    );
    final Paint bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFEDE7F6),
          Color(0xFFD1C4E9),
        ],
      ).createShader(bodyRRect.outerRect);
    canvas.drawRRect(bodyRRect, bodyPaint);
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..color = const Color(0xFF9575CD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018,
    );

    // Purple collar stripe & glowing star core on chest
    final Paint chestBadgePaint = Paint()
      ..color = const Color(0xFF5E35B1);
    canvas.drawCircle(Offset(0, h * 0.18), w * 0.058, chestBadgePaint);
    _drawFourPointStar(
      canvas,
      Offset(0, h * 0.18),
      w * 0.038,
      const Color(0xFFFFD54F),
    );

    // 5. Ear Pods on Left & Right of Helmet
    final Paint earPaint = Paint()..color = const Color(0xFF7E57C2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-w * 0.295, -h * 0.06),
          width: w * 0.07,
          height: h * 0.15,
        ),
        Radius.circular(w * 0.035),
      ),
      earPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.295, -h * 0.06),
          width: w * 0.07,
          height: h * 0.15,
        ),
        Radius.circular(w * 0.035),
      ),
      earPaint,
    );

    // 6. Main Rounded Helmet
    final RRect helmetRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -h * 0.06),
        width: w * 0.56,
        height: h * 0.42,
      ),
      Radius.circular(w * 0.20),
    );
    final Paint helmetPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF3E5F5),
          Color(0xFFD1C4E9),
        ],
      ).createShader(helmetRRect.outerRect);
    canvas.drawRRect(helmetRRect, helmetPaint);
    canvas.drawRRect(
      helmetRRect,
      Paint()
        ..color = const Color(0xFF7E57C2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );

    // 7. Deep-Space Glass Visor Screen
    final RRect visorRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -h * 0.055),
        width: w * 0.44,
        height: h * 0.29,
      ),
      Radius.circular(w * 0.13),
    );
    final Paint visorPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF12082B),
          Color(0xFF261454),
        ],
      ).createShader(visorRRect.outerRect);
    canvas.drawRRect(visorRRect, visorPaint);

    // Subtle glass reflection in top-left of visor
    final Path glossPath = Path()
      ..moveTo(-w * 0.16, -h * 0.16)
      ..quadraticBezierTo(-w * 0.07, -h * 0.18, -w * 0.02, -h * 0.16)
      ..quadraticBezierTo(-w * 0.10, -h * 0.13, -w * 0.16, -h * 0.11)
      ..close();
    canvas.drawPath(
      glossPath,
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );

    // 8. Expressive Eyes & Smile inside Visor
    final bool isBlinking = (idlePhase > 0.47 && idlePhase < 0.51) ||
        (idlePhase > 0.95 && idlePhase < 0.98);
    final double eyeLookX = mood == ByteMascotMood.curious
        ? sin(idlePhase * 2 * pi) * (w * 0.025)
        : 0.0;

    final Offset leftEyeCenter = Offset(-w * 0.095 + eyeLookX, -h * 0.065);
    final Offset rightEyeCenter = Offset(w * 0.095 + eyeLookX, -h * 0.065);

    if (isExcited) {
      // Happy ^ ^ crescent eyes
      final Paint happyEyePaint = Paint()
        ..color = const Color(0xFF64FFDA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028
        ..strokeCap = StrokeCap.round;

      final Path leftArc = Path()
        ..moveTo(leftEyeCenter.dx - w * 0.04, leftEyeCenter.dy + h * 0.015)
        ..quadraticBezierTo(
          leftEyeCenter.dx,
          leftEyeCenter.dy - h * 0.04,
          leftEyeCenter.dx + w * 0.04,
          leftEyeCenter.dy + h * 0.015,
        );
      final Path rightArc = Path()
        ..moveTo(rightEyeCenter.dx - w * 0.04, rightEyeCenter.dy + h * 0.015)
        ..quadraticBezierTo(
          rightEyeCenter.dx,
          rightEyeCenter.dy - h * 0.04,
          rightEyeCenter.dx + w * 0.04,
          rightEyeCenter.dy + h * 0.015,
        );
      canvas.drawPath(leftArc, happyEyePaint);
      canvas.drawPath(rightArc, happyEyePaint);

      // Cute pink neon cheek blushes
      final Paint blushPaint = Paint()
        ..color = const Color(0xFFFF80AB).withValues(alpha: 0.65);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-w * 0.135, -h * 0.01),
          width: w * 0.055,
          height: h * 0.026,
        ),
        blushPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.135, -h * 0.01),
          width: w * 0.055,
          height: h * 0.026,
        ),
        blushPaint,
      );
    } else if (isBlinking) {
      // Closed blink lines
      final Paint blinkPaint = Paint()
        ..color = const Color(0xFF64FFDA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.024
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(leftEyeCenter.dx - w * 0.035, leftEyeCenter.dy),
        Offset(leftEyeCenter.dx + w * 0.035, leftEyeCenter.dy),
        blinkPaint,
      );
      canvas.drawLine(
        Offset(rightEyeCenter.dx - w * 0.035, rightEyeCenter.dy),
        Offset(rightEyeCenter.dx + w * 0.035, rightEyeCenter.dy),
        blinkPaint,
      );
    } else {
      // Glowing cyan oval eyes with white starlight catchlight
      final Paint eyeGlowPaint = Paint()
        ..color = const Color(0xFF64FFDA).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      final Paint eyePaint = Paint()..color = const Color(0xFF64FFDA);

      final Rect leftRect = Rect.fromCenter(
        center: leftEyeCenter,
        width: w * 0.068,
        height: h * 0.088,
      );
      final Rect rightRect = Rect.fromCenter(
        center: rightEyeCenter,
        width: w * 0.068,
        height: h * 0.088,
      );
      canvas.drawOval(leftRect, eyeGlowPaint);
      canvas.drawOval(rightRect, eyeGlowPaint);
      canvas.drawOval(leftRect, eyePaint);
      canvas.drawOval(rightRect, eyePaint);

      // Catchlights
      final Paint highlightPaint = Paint()..color = Colors.white;
      canvas.drawCircle(
        leftEyeCenter + Offset(-w * 0.012, -h * 0.016),
        w * 0.014,
        highlightPaint,
      );
      canvas.drawCircle(
        rightEyeCenter + Offset(-w * 0.012, -h * 0.016),
        w * 0.014,
        highlightPaint,
      );
    }

    // Cute mouth arc
    final Paint mouthPaint = Paint()
      ..color = const Color(0xFF64FFDA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.020
      ..strokeCap = StrokeCap.round;
    final Path smilePath = Path()
      ..moveTo(-w * 0.035 + eyeLookX * 0.5, h * 0.012)
      ..quadraticBezierTo(
        eyeLookX * 0.5,
        isExcited ? h * 0.048 : h * 0.032,
        w * 0.035 + eyeLookX * 0.5,
        h * 0.012,
      );
    canvas.drawPath(smilePath, mouthPaint);

    // 9. Floating Robot Hands (Left & Right)
    final double handOffset = sin(idlePhase * 2 * pi + pi * 0.5) * (h * 0.025);
    final Paint handPaint = Paint()..color = const Color(0xFFEDE7F6);
    final Paint handBorderPaint = Paint()
      ..color = const Color(0xFF7E57C2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.016;

    // Left hand
    canvas.save();
    canvas.translate(-w * 0.27, h * 0.16 + handOffset);
    canvas.rotate(0.25);
    final Rect handRect = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.085,
      height: h * 0.12,
    );
    canvas.drawOval(handRect, handPaint);
    canvas.drawOval(handRect, handBorderPaint);
    canvas.restore();

    // Right hand (waves up when excited/tapped!)
    canvas.save();
    final double waveLift = isExcited ? -h * 0.12 : handOffset;
    final double waveAngle = isExcited
        ? -0.65 + sin((tapProgress > 0 ? tapProgress : idlePhase) * 6 * pi) * 0.35
        : -0.25;
    canvas.translate(w * 0.27, h * 0.16 + waveLift);
    canvas.rotate(waveAngle);
    canvas.drawOval(handRect, handPaint);
    canvas.drawOval(handRect, handBorderPaint);
    canvas.restore();

    canvas.restore();

    // 10. Orbiting Little Star & Tap Sparkle Burst
    final double orbitAngle = idlePhase * 2 * pi;
    final Offset orbitStarPos = Offset(
      cx + cos(orbitAngle) * (w * 0.39),
      (h * 0.44 + dy) + sin(orbitAngle) * (h * 0.12),
    );
    _drawFourPointStar(
      canvas,
      orbitStarPos,
      w * 0.048,
      const Color(0xFFFFD54F),
    );

    if (tapProgress > 0.0 && tapProgress < 1.0) {
      final double burstAlpha = (1.0 - tapProgress).clamp(0.0, 1.0);
      final double burstRadius = w * (0.30 + tapProgress * 0.18);
      for (int i = 0; i < 5; i++) {
        final double angle = -pi * 0.85 + (i * pi * 0.42);
        final Offset spPos = Offset(
          cx + cos(angle) * burstRadius,
          (h * 0.38 + dy) + sin(angle) * burstRadius,
        );
        _drawFourPointStar(
          canvas,
          spPos,
          w * 0.045 * burstAlpha,
          const Color(0xFFFFCA28).withValues(alpha: burstAlpha),
        );
      }
    }
  }

  void _drawFourPointStar(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final Path path = Path();
    final double inner = radius * 0.32;
    for (int i = 0; i < 8; i++) {
      final double r = i.isEven ? radius : inner;
      final double a = (i * pi / 4) - pi / 2;
      final double x = center.dx + cos(a) * r;
      final double y = center.dy + sin(a) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ByteAstroBotPainter oldDelegate) {
    return oldDelegate.idlePhase != idlePhase ||
        oldDelegate.tapProgress != tapProgress ||
        oldDelegate.mood != mood ||
        oldDelegate.darkThemeContext != darkThemeContext;
  }
}

/// A distinctive purple-space CTA button with a levitating zero-gravity float,
/// glowing violet nebula gradient, white text/icons, and soft aura shadow.
class CosmicActionButton extends StatefulWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onPressed;

  const CosmicActionButton({
    super.key,
    required this.label,
    this.subtitle,
    this.icon = Icons.auto_awesome_rounded,
    required this.onPressed,
  });

  @override
  State<CosmicActionButton> createState() => _CosmicActionButtonState();
}

class _CosmicActionButtonState extends State<CosmicActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final double t = Curves.easeInOutSine.transform(_floatController.value);
        // Gentle levitating vertical offset (-4px to +2px)
        final double dy = -4.0 * t + 2.0 * (1.0 - t);
        final double glowBlur = 16.0 + 6.0 * t;
        final double shadowOffset = 8.0 + 4.0 * t;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 295),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF311B92),
                  Color(0xFF5E35B1),
                  Color(0xFF7C4DFF),
                  Color(0xFF651FFF),
                ],
                stops: [0.0, 0.38, 0.78, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.32 + 0.15 * t),
                width: 1.4,
              ),
              boxShadow: [
                // Deep levitation drop shadow below the button
                BoxShadow(
                  color: const Color(0xFF311B92).withValues(alpha: 0.36 - 0.08 * t),
                  blurRadius: glowBlur,
                  offset: Offset(0, shadowOffset),
                  spreadRadius: 1,
                ),
                // Outer glowing purple space aura
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.42 + 0.14 * t),
                  blurRadius: glowBlur + 4,
                  offset: const Offset(0, 2),
                  spreadRadius: 1.5,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(26),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Frosted White/Lavender Space Icon Badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.26),
                        Colors.white.withValues(alpha: 0.10),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Trailing Frosted White Launch Arrow Pill
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


