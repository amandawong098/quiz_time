import 'dart:math';
import 'package:flutter/material.dart';
import '../services/sound_service.dart';

enum ByteMascotMood { idle, happy, curious }

/// Immutable configuration representing a user's customized Byte avatar.
/// Can be serialized to/from a compact `byte://v1?...` URI stored in `profiles.avatar_url`
/// or a JSON map so every screen in LearnByte renders the user's custom Byte automatically.
class ByteAppearance {
  final String bodyId;
  final String eyeId;
  final String costumeId;
  final String stageId;

  const ByteAppearance({
    this.bodyId = 'body_classic',
    this.eyeId = 'eye_cyan',
    this.costumeId = 'costume_none',
    this.stageId = 'stage_nebula',
  });

  static const ByteAppearance defaultAppearance = ByteAppearance();

  ByteAppearance copyWith({
    String? bodyId,
    String? eyeId,
    String? costumeId,
    String? stageId,
  }) {
    return ByteAppearance(
      bodyId: bodyId ?? this.bodyId,
      eyeId: eyeId ?? this.eyeId,
      costumeId: costumeId ?? this.costumeId,
      stageId: stageId ?? this.stageId,
    );
  }

  /// Encodes this appearance into a compact URI string that fits in `profiles.avatar_url`.
  String toAvatarUrlString() {
    return 'byte://v1?body=$bodyId&eye=$eyeId&costume=$costumeId&stage=$stageId';
  }

  Map<String, dynamic> toJson() => {
    'bodyId': bodyId,
    'eyeId': eyeId,
    'costumeId': costumeId,
    'stageId': stageId,
  };

  factory ByteAppearance.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultAppearance;
    return ByteAppearance(
      bodyId: json['bodyId'] as String? ?? 'body_classic',
      eyeId: json['eyeId'] as String? ?? 'eye_cyan',
      costumeId: json['costumeId'] as String? ?? 'costume_none',
      stageId: json['stageId'] as String? ?? 'stage_nebula',
    );
  }

  /// Parses a `byte://...` URI string (or falls back to default appearance).
  factory ByteAppearance.fromAvatarUrlString(String? raw) {
    if (raw == null || raw.isEmpty || !raw.startsWith('byte://')) {
      return defaultAppearance;
    }
    try {
      final uri = Uri.parse(raw);
      final q = uri.queryParameters;
      return ByteAppearance(
        bodyId: q['body'] ?? 'body_classic',
        eyeId: q['eye'] ?? 'eye_cyan',
        costumeId: q['costume'] ?? 'costume_none',
        stageId: q['stage'] ?? 'stage_nebula',
      );
    } catch (_) {
      return defaultAppearance;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ByteAppearance &&
        other.bodyId == bodyId &&
        other.eyeId == eyeId &&
        other.costumeId == costumeId &&
        other.stageId == stageId;
  }

  @override
  int get hashCode => Object.hash(bodyId, eyeId, costumeId, stageId);
}

/// Global notifier for the current logged-in user's Byte appearance so that
/// any avatar widget showing the current user updates instantaneously.
class CurrentByteAppearanceNotifier {
  static final ValueNotifier<ByteAppearance> notifier =
      ValueNotifier<ByteAppearance>(ByteAppearance.defaultAppearance);
}

/// Universal circular/rounded Avatar widget that replaces profile photos across LearnByte
/// (Wayground / Quizizz style). Renders the user's customized Byte over their stage backdrop.
class UserByteAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? avatarData;
  final String? userId;
  final String? name;
  final ByteAppearance? appearanceOverride;
  final double radius;
  final bool isCurrentUser;
  final VoidCallback? onTap;
  final bool showBorder;

  const UserByteAvatar({
    super.key,
    this.avatarUrl,
    this.avatarData,
    this.userId,
    this.name,
    this.appearanceOverride,
    this.radius = 20,
    this.isCurrentUser = false,
    this.onTap,
    this.showBorder = true,
  });

  static List<Color> stageGradientColors(String stageId) {
    switch (stageId) {
      case 'stage_mars':
        return const [Color(0xFF450A0A), Color(0xFF991B1B), Color(0xFFEA580C)];
      case 'stage_saturn':
        return const [Color(0xFF082F49), Color(0xFF0369A1), Color(0xFF38BDF8)];
      case 'stage_cyber':
        return const [Color(0xFF1E1B4B), Color(0xFF701A75), Color(0xFFF43F5E)];
      case 'stage_supernova':
        return const [Color(0xFF422006), Color(0xFFB45309), Color(0xFFFBBF24)];
      case 'stage_nebula':
      default:
        return const [Color(0xFF12082B), Color(0xFF311B92), Color(0xFF651FFF)];
    }
  }

  static Color stageBorderColor(String stageId) {
    switch (stageId) {
      case 'stage_mars':
        return const Color(0xFFFB923C);
      case 'stage_saturn':
        return const Color(0xFF38BDF8);
      case 'stage_cyber':
        return const Color(0xFFF472B6);
      case 'stage_supernova':
        return const Color(0xFFFACC15);
      case 'stage_nebula':
      default:
        return const Color(0xFFB388FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ByteAppearance>(
      valueListenable: CurrentByteAppearanceNotifier.notifier,
      builder: (context, currentOwnAppearance, _) {
        final effectiveAvatarUrl = avatarUrl ?? avatarData;
        ByteAppearance resolved;
        if (appearanceOverride != null) {
          resolved = appearanceOverride!;
        } else if (effectiveAvatarUrl != null &&
            effectiveAvatarUrl.startsWith('byte://')) {
          resolved = ByteAppearance.fromAvatarUrlString(effectiveAvatarUrl);
        } else if (isCurrentUser) {
          resolved = currentOwnAppearance;
        } else {
          resolved = ByteAppearance.fromAvatarUrlString(effectiveAvatarUrl);
        }

        final double diameter = radius * 2;
        final bgColors = stageGradientColors(resolved.stageId);
        final borderColor = stageBorderColor(resolved.stageId);

        Widget badge = Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: bgColors,
            ),
            border: showBorder
                ? Border.all(
                    color: borderColor,
                    width: (radius * 0.09).clamp(1.2, 3.0),
                  )
                : null,
            boxShadow: radius >= 18
                ? [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.35),
                      blurRadius: radius * 0.35,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: ClipOval(
            child: Transform.scale(
              scale: 1.26,
              alignment: const Alignment(0, 0.08),
              child: CustomPaint(
                size: Size(diameter, diameter),
                painter: _ByteAstroBotPainter(
                  idlePhase: 0.12,
                  tapProgress: 0.0,
                  mood: ByteMascotMood.happy,
                  darkThemeContext: true,
                  appearance: resolved,
                  isAvatarPortrait: true,
                ),
              ),
            ),
          ),
        );

        if (onTap != null) {
          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: badge,
          );
        }
        return badge;
      },
    );
  }
}

/// "Byte" the Astro-Bot Mascot with continuous subtle zero-gravity floating,
/// natural blinking, orbiting star particle, and interactive tap-to-chirp/wave.
/// natural blinking, orbiting star particle, interactive tap-to-chirp/wave,
/// and full custom body paint, eye style, and fitted vector costumes.
class ByteMascot extends StatefulWidget {
  final double size;
  final ByteMascotMood mood;
  final List<String>? tapMessages;
  final String? initialBubbleText;
  final bool darkThemeContext;
  final ByteAppearance? appearance;
  final bool useCurrentUserAppearance;
  final VoidCallback? onTapOverride;

  const ByteMascot({
    super.key,
    this.size = 110,
    this.mood = ByteMascotMood.idle,
    this.tapMessages,
    this.initialBubbleText,
    this.darkThemeContext = false,
    this.appearance,
    this.useCurrentUserAppearance = true,
    this.onTapOverride,
  });

  @override
  State<ByteMascot> createState() => _ByteMascotState();
}

class _ByteMascotState extends State<ByteMascot> with TickerProviderStateMixin {
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
    if (widget.initialBubbleText != oldWidget.initialBubbleText) {
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

    if (widget.onTapOverride != null) {
      widget.onTapOverride!();
      return;
    }

    final messages =
        (widget.tapMessages != null && widget.tapMessages!.isNotEmpty)
        ? widget.tapMessages!
        : _defaultMessages;

    setState(() {
      _messageIndex = (_messageIndex + 1) % messages.length;
      _activeBubbleText = messages[_messageIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ByteAppearance>(
      valueListenable: CurrentByteAppearanceNotifier.notifier,
      builder: (context, globalAppearance, _) {
        final effectiveAppearance =
            widget.appearance ??
            (widget.useCurrentUserAppearance
                ? globalAppearance
                : ByteAppearance.defaultAppearance);

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
                  animation: Listenable.merge([
                    _idleController,
                    _tapController,
                  ]),
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _ByteAstroBotPainter(
                        idlePhase: _idleController.value,
                        tapProgress: _tapController.value,
                        mood: widget.mood,
                        darkThemeContext: widget.darkThemeContext,
                        appearance: effectiveAppearance,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ByteBodyPalette {
  final List<Color> gradient;
  final Color border;
  final Color earColor;
  final Color handFill;
  final Color auraColor;

  const _ByteBodyPalette({
    required this.gradient,
    required this.border,
    required this.earColor,
    required this.handFill,
    required this.auraColor,
  });
}

class _ByteAstroBotPainter extends CustomPainter {
  final double idlePhase;
  final double tapProgress;
  final ByteMascotMood mood;
  final bool darkThemeContext;
  final ByteAppearance appearance;
  final bool isAvatarPortrait;

  _ByteAstroBotPainter({
    required this.idlePhase,
    required this.tapProgress,
    required this.mood,
    required this.darkThemeContext,
    this.appearance = ByteAppearance.defaultAppearance,
    this.isAvatarPortrait = false,
  });

  _ByteBodyPalette _resolvePalette() {
    // If Alien disguise is equipped and user has default classic paint, give it a cool alien tint,
    // otherwise respect the user's chosen body paint!
    if (appearance.costumeId == 'costume_alien' &&
        appearance.bodyId == 'body_classic') {
      return const _ByteBodyPalette(
        gradient: [Color(0xFFE8F5E9), Color(0xFFB9F6CA), Color(0xFF69F0AE)],
        border: Color(0xFF00C853),
        earColor: Color(0xFF00E676),
        handFill: Color(0xFFB9F6CA),
        auraColor: Color(0xFF00E676),
      );
    }

    switch (appearance.bodyId) {
      case 'body_obsidian':
        return const _ByteBodyPalette(
          gradient: [Color(0xFF475569), Color(0xFF1E293B), Color(0xFF0F172A)],
          border: Color(0xFF00E5FF),
          earColor: Color(0xFF0284C7),
          handFill: Color(0xFF334155),
          auraColor: Color(0xFF00E5FF),
        );
      case 'body_gold':
        return const _ByteBodyPalette(
          gradient: [Color(0xFFFFFBEB), Color(0xFFFDE047), Color(0xFFF59E0B)],
          border: Color(0xFFB45309),
          earColor: Color(0xFFD97706),
          handFill: Color(0xFFFEF08A),
          auraColor: Color(0xFFFBBF24),
        );
      case 'body_rose':
        return const _ByteBodyPalette(
          gradient: [Color(0xFFFDF2F8), Color(0xFFFBCFE8), Color(0xFFF472B6)],
          border: Color(0xFFDB2777),
          earColor: Color(0xFFEC4899),
          handFill: Color(0xFFFCE7F3),
          auraColor: Color(0xFFF472B6),
        );
      case 'body_emerald':
        return const _ByteBodyPalette(
          gradient: [Color(0xFFECFDF5), Color(0xFFA7F3D0), Color(0xFF34D399)],
          border: Color(0xFF059669),
          earColor: Color(0xFF10B981),
          handFill: Color(0xFFD1FAE5),
          auraColor: Color(0xFF34D399),
        );
      case 'body_galaxy':
        return const _ByteBodyPalette(
          gradient: [Color(0xFFC4B5FD), Color(0xFF6D28D9), Color(0xFF311068)],
          border: Color(0xFFE879F9),
          earColor: Color(0xFF9333EA),
          handFill: Color(0xFFA78BFA),
          auraColor: Color(0xFFD946EF),
        );
      case 'body_classic':
      default:
        return const _ByteBodyPalette(
          gradient: [Color(0xFFFFFFFF), Color(0xFFEDE7F6), Color(0xFFD1C4E9)],
          border: Color(0xFF7E57C2),
          earColor: Color(0xFF7E57C2),
          handFill: Color(0xFFEDE7F6),
          auraColor: Color(0xFF7C4DFF),
        );
    }
  }

  Color _resolvePrimaryEyeColor() {
    if (appearance.costumeId == 'costume_alien' &&
        appearance.eyeId == 'eye_cyan') {
      return const Color(0xFF76FF03);
    }
    switch (appearance.eyeId) {
      case 'eye_star_gold':
        return const Color(0xFFFFD54F);
      case 'eye_heart_pink':
        return const Color(0xFFFF4081);
      case 'eye_cyber_visor':
        return const Color(0xFF00E5FF);
      case 'eye_fire_amber':
        return const Color(0xFFFF9100);
      case 'eye_emerald_pixel':
        return const Color(0xFF00E676);
      case 'eye_cyan':
      default:
        return const Color(0xFF64FFDA);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w * 0.5;

    final palette = _resolvePalette();
    final eyeColor = _resolvePrimaryEyeColor();
    final costume = appearance.costumeId;

    final bool isExcited =
        (tapProgress > 0.0 && tapProgress < 1.0) ||
        mood == ByteMascotMood.happy;

    // Smooth zero-gravity bobbing (-4.5% to +4.5% of height)
    final double idleBob = isAvatarPortrait
        ? 0.0
        : sin(idlePhase * 2 * pi) * (h * 0.042);
    // Tap jump arc
    final double tapJump = tapProgress > 0.0
        ? -sin(tapProgress * pi) * (h * 0.11)
        : 0.0;
    final double dy = idleBob + tapJump;

    // Gentle head/body tilt when excited or curious
    double tiltAngle = isAvatarPortrait ? 0.0 : sin(idlePhase * 2 * pi) * 0.035;
    if (mood == ByteMascotMood.curious && !isAvatarPortrait) {
      tiltAngle += 0.06 * sin(idlePhase * 2 * pi);
    }
    if (tapProgress > 0.0 && tapProgress < 1.0) {
      tiltAngle += sin(tapProgress * 2 * pi) * 0.12;
    }

    // 1. Floating shadow / cosmic pad underneath Byte
    if (!isAvatarPortrait) {
      final double shadowScale = (1.0 - ((-dy) / (h * 0.25))).clamp(0.65, 1.15);
      final Paint shadowPaint = Paint()
        ..color = palette.auraColor.withValues(alpha: 0.24 * shadowScale)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, h * 0.91),
          width: w * 0.42 * shadowScale,
          height: h * 0.07 * shadowScale,
        ),
        shadowPaint,
      );
    }

    // 2. Soft background aura glow behind Byte
    final Paint auraPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              palette.auraColor.withValues(alpha: isExcited ? 0.30 : 0.16),
              palette.auraColor.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(cx, h * 0.48 + dy),
              radius: w * 0.46,
            ),
          );
    canvas.drawCircle(Offset(cx, h * 0.48 + dy), w * 0.46, auraPaint);

    canvas.save();
    canvas.translate(cx, h * 0.50 + dy);
    canvas.rotate(tiltAngle);

    // =========================================================================
    // LAYER A: BACK COSTUME ELEMENTS (Capes, Jetpacks, Back Saturn Ring, Katanas)
    // =========================================================================
    if (costume == 'costume_wizard') {
      _drawWizardCapeBack(canvas, w, h, idlePhase);
    } else if (costume == 'costume_royalty') {
      _drawRoyalCapeBack(canvas, w, h, idlePhase);
    } else if (costume == 'costume_astronaut') {
      _drawAstronautJetpackBack(canvas, w, h, idlePhase);
    } else if (costume == 'costume_planet') {
      _drawSaturnRingHalf(canvas, w, h, isFront: false);
    } else if (costume == 'costume_cyber_ninja') {
      _drawNinjaKatanasBack(canvas, w, h);
    }

    // =========================================================================
    // LAYER B: ANTENNA(S) ON TOP OF HELMET
    // =========================================================================
    final double antennaSway = sin(idlePhase * 2 * pi + 1.1) * (w * 0.025);
    if (costume == 'costume_alien') {
      // Dual curved green Martian feeler antennae!
      final Paint alienStemPaint = Paint()
        ..color = const Color(0xFF00E676)
        ..strokeWidth = w * 0.030
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      for (final double side in [-1.0, 1.0]) {
        final Path feeler = Path()
          ..moveTo(side * w * 0.09, -h * 0.25)
          ..quadraticBezierTo(
            side * w * 0.16 + antennaSway * 0.5,
            -h * 0.35,
            side * w * 0.19 + antennaSway,
            -h * 0.41,
          );
        canvas.drawPath(feeler, alienStemPaint);

        final Offset tip = Offset(side * w * 0.19 + antennaSway, -h * 0.415);
        canvas.drawCircle(
          tip,
          w * 0.048,
          Paint()
            ..color = const Color(0xFF76FF03).withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(
          tip,
          w * 0.034,
          Paint()..color = const Color(0xFF76FF03),
        );
        canvas.drawCircle(
          tip + Offset(-w * 0.008, -w * 0.008),
          w * 0.011,
          Paint()..color = Colors.white,
        );
      }
    } else if (costume != 'costume_wizard' && costume != 'costume_royalty') {
      // Standard single antenna (hidden under Wizard Hat & Royal Crown so they sit flush)
      final Paint stemPaint = Paint()
        ..color = palette.border
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
    }

    // 4. Lower Astro-Pod Body (Torso)
    // =========================================================================
    // LAYER C: LOWER ASTRO-POD BODY (TORSO) & OUTFIT DETAILS
    // =========================================================================
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
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: palette.gradient,
      ).createShader(bodyRRect.outerRect);
    canvas.drawRRect(bodyRRect, bodyPaint);

    // Costume-specific torso details clipped inside the torso RRect
    canvas.save();
    canvas.clipRRect(bodyRRect);
    if (costume == 'costume_planet') {
      // Planetary atmospheric stripes across torso
      final Paint band1 = Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.45);
      final Paint band2 = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.40);
      canvas.drawRect(
        Rect.fromLTWH(-w * 0.25, h * 0.11, w * 0.5, h * 0.045),
        band1,
      );
      canvas.drawRect(
        Rect.fromLTWH(-w * 0.25, h * 0.21, w * 0.5, h * 0.04),
        band2,
      );
    } else if (costume == 'costume_wizard') {
      // Starlight Wizard Robe front tunic
      canvas.drawRect(
        Rect.fromLTWH(-w * 0.25, h * 0.06, w * 0.5, h * 0.30),
        Paint()..color = const Color(0xFF1E1B4B).withValues(alpha: 0.85),
      );
      // Gold robe center trim
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, h * 0.19),
          width: w * 0.05,
          height: h * 0.26,
        ),
        Paint()..color = const Color(0xFFFBBF24),
      );
    } else if (costume == 'costume_cyber_ninja') {
      // Dark stealth shinobi armor plates + diagonal sash
      canvas.drawRect(
        Rect.fromLTWH(-w * 0.25, h * 0.06, w * 0.5, h * 0.30),
        Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.88),
      );
      final Path sash = Path()
        ..moveTo(-w * 0.20, h * 0.08)
        ..lineTo(-w * 0.12, h * 0.08)
        ..lineTo(w * 0.18, h * 0.30)
        ..lineTo(w * 0.10, h * 0.30)
        ..close();
      canvas.drawPath(sash, Paint()..color = const Color(0xFFF43F5E));
    }
    canvas.restore();

    // Torso outline
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..color = const Color(0xFF9575CD)
        ..color = palette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018,
    );

    // Purple collar stripe & glowing star core on chest
    final Paint chestBadgePaint = Paint()..color = const Color(0xFF5E35B1);
    canvas.drawCircle(Offset(0, h * 0.18), w * 0.058, chestBadgePaint);
    _drawFourPointStar(
      canvas,
      Offset(0, h * 0.18),
      w * 0.038,
      const Color(0xFFFFD54F),
    );
    // Chest Emblem / Costume Front Torso Piece
    if (costume == 'costume_astronaut') {
      // NASA Commander Life-Support Chest Box
      final RRect packRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, h * 0.185),
          width: w * 0.20,
          height: h * 0.12,
        ),
        Radius.circular(w * 0.025),
      );
      canvas.drawRRect(packRRect, Paint()..color = const Color(0xFFCBD5E1));
      canvas.drawRRect(
        packRRect,
        Paint()
          ..color = const Color(0xFF475569)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.012,
      );
      // 3 glowing telemetry buttons
      canvas.drawCircle(
        Offset(-w * 0.05, h * 0.175),
        w * 0.016,
        Paint()..color = const Color(0xFFEF4444),
      );
      canvas.drawCircle(
        Offset(0, h * 0.175),
        w * 0.016,
        Paint()..color = const Color(0xFF10B981),
      );
      canvas.drawCircle(
        Offset(w * 0.05, h * 0.175),
        w * 0.016,
        Paint()..color = const Color(0xFF00E5FF),
      );
    } else if (costume == 'costume_royalty') {
      // Royal Ermine Fur Collar & Golden Gem Clasp
      final RRect collarRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, h * 0.115),
          width: w * 0.36,
          height: h * 0.065,
        ),
        Radius.circular(w * 0.03),
      );
      canvas.drawRRect(collarRect, Paint()..color = Colors.white);
      // Ermine spots
      for (final double sx in [-0.11, -0.05, 0.05, 0.11]) {
        canvas.drawCircle(
          Offset(w * sx, h * 0.115),
          w * 0.008,
          Paint()..color = Colors.black87,
        );
      }
      // Gold & Ruby Medallion Clasp
      canvas.drawCircle(
        Offset(0, h * 0.125),
        w * 0.042,
        Paint()..color = const Color(0xFFFBBF24),
      );
      canvas.drawCircle(
        Offset(0, h * 0.125),
        w * 0.025,
        Paint()..color = const Color(0xFFE11D48),
      );
    } else if (costume == 'costume_alien') {
      // Mini UFO Saucer Belt around Byte's waist!
      final Rect saucerRect = Rect.fromCenter(
        center: Offset(0, h * 0.21),
        width: w * 0.48,
        height: h * 0.085,
      );
      canvas.drawOval(
        saucerRect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF94A3B8), Color(0xFFE2E8F0), Color(0xFF475569)],
          ).createShader(saucerRect),
      );
      canvas.drawOval(
        saucerRect,
        Paint()
          ..color = const Color(0xFF00E676)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.014,
      );
      // Glowing UFO rim lights
      for (int i = -2; i <= 2; i++) {
        canvas.drawCircle(
          Offset(i * w * 0.08, h * 0.21),
          w * 0.014,
          Paint()..color = const Color(0xFF76FF03),
        );
      }
    } else {
      // Standard glowing star core on chest
      final Paint chestBadgePaint = Paint()..color = palette.border;
      canvas.drawCircle(Offset(0, h * 0.18), w * 0.058, chestBadgePaint);
      _drawFourPointStar(
        canvas,
        Offset(0, h * 0.18),
        w * 0.038,
        const Color(0xFFFFD54F),
      );
    }

    // =========================================================================
    // LAYER D: EAR PODS & MAIN ROUNDED HELMET
    // =========================================================================
    final Paint earPaint = Paint()..color = palette.earColor;
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
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: palette.gradient,
      ).createShader(helmetRRect.outerRect);
    canvas.drawRRect(helmetRRect, helmetPaint);
    canvas.drawRRect(
      helmetRRect,
      Paint()
        ..color = palette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );

    // 7. Deep-Space Glass Visor Screen
    // Commander Astronaut Gold Visor Rim
    if (costume == 'costume_astronaut') {
      final RRect goldRim = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -h * 0.055),
          width: w * 0.47,
          height: h * 0.32,
        ),
        Radius.circular(w * 0.145),
      );
      canvas.drawRRect(
        goldRim,
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.022,
      );
    }

    // =========================================================================
    // LAYER E: DEEP-SPACE GLASS VISOR SCREEN & EXPRESSIVE CUSTOM EYES
    // =========================================================================
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
        colors: [Color(0xFF12082B), Color(0xFF261454)],
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
    final bool isBlinking =
        !isAvatarPortrait &&
        ((idlePhase > 0.47 && idlePhase < 0.51) ||
            (idlePhase > 0.95 && idlePhase < 0.98));
    final double eyeLookX =
        (mood == ByteMascotMood.curious && !isAvatarPortrait)
        ? sin(idlePhase * 2 * pi) * (w * 0.025)
        : 0.0;

    final Offset leftEyeCenter = Offset(-w * 0.095 + eyeLookX, -h * 0.065);
    final Offset rightEyeCenter = Offset(w * 0.095 + eyeLookX, -h * 0.065);

    _drawVisorEyesAndMouth(
      canvas: canvas,
      w: w,
      h: h,
      leftEyeCenter: leftEyeCenter,
      rightEyeCenter: rightEyeCenter,
      eyeLookX: eyeLookX,
      eyeColor: eyeColor,
      isBlinking: isBlinking,
      isExcited: isExcited,
      costume: costume,
    );

    // =========================================================================
    // LAYER F: FITTED HEADGEAR COSTUMES (Wizard Hat, Royal Crown, Ninja Band)
    // =========================================================================
    if (costume == 'costume_wizard') {
      _drawWizardHatOnHelmet(canvas, w, h);
    } else if (costume == 'costume_royalty') {
      _drawRoyalCrownOnHelmet(canvas, w, h);
    } else if (costume == 'costume_cyber_ninja') {
      _drawNinjaHeadbandOnHelmet(canvas, w, h, idlePhase);
    }

    // =========================================================================
    // LAYER G: FRONT SATURN PLANETARY RING (Sweeps in front of Byte in 3D!)
    // =========================================================================
    if (costume == 'costume_planet') {
      _drawSaturnRingHalf(canvas, w, h, isFront: true);
    }

    // =========================================================================
    // LAYER H: FLOATING ROBOT HANDS & HELD COSTUME PROPS
    // =========================================================================
    final double handOffset = isAvatarPortrait
        ? 0.0
        : sin(idlePhase * 2 * pi + pi * 0.5) * (h * 0.025);
    final Paint handPaint = Paint()..color = palette.handFill;
    final Paint handBorderPaint = Paint()
      ..color = palette.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.016;

    final Rect handRect = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.085,
      height: h * 0.12,
    );

    // Left hand
    canvas.save();
    canvas.translate(-w * 0.27, h * 0.16 + handOffset);
    canvas.rotate(0.25);
    canvas.drawOval(handRect, handPaint);
    canvas.drawOval(handRect, handBorderPaint);
    canvas.restore();

    // Right hand (waves up when excited/tapped + holds costume prop!)
    canvas.save();
    final double waveLift = isExcited ? -h * 0.12 : handOffset;
    final double waveAngle = isExcited
        ? -0.65 +
              (isAvatarPortrait
                  ? 0.15
                  : sin((tapProgress > 0 ? tapProgress : idlePhase) * 6 * pi) *
                        0.35)
        : -0.25;
    canvas.translate(w * 0.27, h * 0.16 + waveLift);
    canvas.rotate(waveAngle);

    // Held prop in right hand
    if (costume == 'costume_wizard') {
      // Glowing Starlight Wand
      canvas.drawLine(
        Offset(0, h * 0.02),
        Offset(w * 0.06, -h * 0.18),
        Paint()
          ..color = const Color(0xFFFBBF24)
          ..strokeWidth = w * 0.022
          ..strokeCap = StrokeCap.round,
      );
      _drawFourPointStar(
        canvas,
        Offset(w * 0.065, -h * 0.195),
        w * 0.055,
        const Color(0xFF00E5FF),
      );
    } else if (costume == 'costume_royalty') {
      // Golden Royal Scepter
      canvas.drawLine(
        Offset(0, h * 0.04),
        Offset(w * 0.05, -h * 0.17),
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..strokeWidth = w * 0.024
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(w * 0.05, -h * 0.18),
        w * 0.036,
        Paint()..color = const Color(0xFFFBBF24),
      );
      canvas.drawCircle(
        Offset(w * 0.05, -h * 0.18),
        w * 0.022,
        Paint()..color = const Color(0xFFE11D48),
      );
    } else if (costume == 'costume_cyber_ninja') {
      // Glowing Cyan Shuriken
      _drawFourPointStar(
        canvas,
        Offset(w * 0.04, -h * 0.09),
        w * 0.06,
        const Color(0xFF00E5FF),
      );
      canvas.drawCircle(
        Offset(w * 0.04, -h * 0.09),
        w * 0.015,
        Paint()..color = const Color(0xFF0F172A),
      );
    }

    canvas.drawOval(handRect, handPaint);
    canvas.drawOval(handRect, handBorderPaint);
    canvas.restore();

    canvas.restore();

    // 10. Orbiting Little Star & Tap Sparkle Burst
    if (!isAvatarPortrait) {
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
  }

  void _drawVisorEyesAndMouth({
    required Canvas canvas,
    required double w,
    required double h,
    required Offset leftEyeCenter,
    required Offset rightEyeCenter,
    required double eyeLookX,
    required Color eyeColor,
    required bool isBlinking,
    required bool isExcited,
    required String costume,
  }) {
    // Special Cyber-Visor Shades option
    if (appearance.eyeId == 'eye_cyber_visor') {
      final RRect shadesRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(eyeLookX * 0.6, -h * 0.068),
          width: w * 0.34,
          height: h * 0.085,
        ),
        Radius.circular(w * 0.03),
      );
      canvas.drawRRect(
        shadesRRect,
        Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(
        shadesRRect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF38BDF8), Color(0xFFF43F5E)],
          ).createShader(shadesRRect.outerRect),
      );
      // White glare slash across cyber visor
      final Path glare = Path()
        ..moveTo(-w * 0.08, -h * 0.105)
        ..lineTo(-w * 0.03, -h * 0.105)
        ..lineTo(-w * 0.09, -h * 0.03)
        ..lineTo(-w * 0.14, -h * 0.03)
        ..close();
      canvas.drawPath(
        glare,
        Paint()..color = Colors.white.withValues(alpha: 0.65),
      );
    } else if (isBlinking) {
      // Closed blink lines
      final Paint blinkPaint = Paint()
        ..color = const Color(0xFF64FFDA)
        ..color = eyeColor
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
    } else if (appearance.eyeId == 'eye_star_gold') {
      // Glowing Star Eyes!
      for (final center in [leftEyeCenter, rightEyeCenter]) {
        canvas.drawCircle(
          center,
          w * 0.055,
          Paint()
            ..color = const Color(0xFFFFD54F).withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        _drawFourPointStar(canvas, center, w * 0.055, const Color(0xFFFFD54F));
        canvas.drawCircle(center, w * 0.015, Paint()..color = Colors.white);
      }
    } else if (appearance.eyeId == 'eye_heart_pink') {
      // Glowing Pink Heart Eyes!
      for (final center in [leftEyeCenter, rightEyeCenter]) {
        _drawHeart(canvas, center, w * 0.085, const Color(0xFFFF4081));
      }
    } else if (appearance.eyeId == 'eye_fire_amber') {
      // Fierce Angry Heroic Mecha Eyes (outer corners angled UP, inner corners angled DOWN)
      final Paint fireGlow = Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      final Paint firePaint = Paint()..color = const Color(0xFFFFAB00);
      final Paint glintPaint = Paint()..color = const Color(0xFFFFF8E1);

      for (final int side in [-1, 1]) {
        final Offset c = side == -1 ? leftEyeCenter : rightEyeCenter;
        final Path p = Path()
          // Inner brow corner (angled DOWN toward center)
          ..moveTo(c.dx - side * w * 0.042, c.dy + h * 0.002)
          // Sharp outer brow corner (angled UP)
          ..lineTo(c.dx + side * w * 0.048, c.dy - h * 0.042)
          // Outer lower corner
          ..lineTo(c.dx + side * w * 0.036, c.dy + h * 0.022)
          // Curved fierce lower lid back to inner corner
          ..quadraticBezierTo(
            c.dx - side * w * 0.005,
            c.dy + h * 0.042,
            c.dx - side * w * 0.042,
            c.dy + h * 0.002,
          )
          ..close();
        canvas.drawPath(p, fireGlow);
        canvas.drawPath(p, firePaint);
        // Sharp inner hero glint
        canvas.drawCircle(
          Offset(c.dx + side * w * 0.012, c.dy - h * 0.004),
          w * 0.011,
          glintPaint,
        );
      }
    } else if (appearance.eyeId == 'eye_emerald_pixel') {
      // Retro 8-Bit Pixel Grid Eyes
      final Paint pxPaint = Paint()..color = const Color(0xFF00E676);
      final double u = w * 0.018;
      for (final Offset c in [leftEyeCenter, rightEyeCenter]) {
        canvas.drawRect(
          Rect.fromCenter(center: c, width: u * 3, height: u * 4),
          pxPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: c + Offset(-u * 0.5, -u * 0.8),
            width: u,
            height: u,
          ),
          Paint()..color = Colors.white,
        );
      }
    } else if (isExcited && costume != 'costume_alien') {
      // Happy ^ ^ crescent eyes
      final Paint happyEyePaint = Paint()
        ..color = eyeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028
        ..strokeCap = StrokeCap.round;

      for (final Offset c in [leftEyeCenter, rightEyeCenter]) {
        final Path arc = Path()
          ..moveTo(c.dx - w * 0.04, c.dy + h * 0.015)
          ..quadraticBezierTo(
            c.dx,
            c.dy - h * 0.04,
            c.dx + w * 0.04,
            c.dy + h * 0.015,
          );
        canvas.drawPath(arc, happyEyePaint);
      }
    } else {
      // Glowing cyan oval eyes with white starlight catchlight
      // Classic glowing oval eyes (or 3 Alien eyes when Alien Disguise is equipped!)
      final List<Offset> eyeCenters = costume == 'costume_alien'
          ? [
              Offset(-w * 0.115 + eyeLookX, -h * 0.055),
              Offset(eyeLookX, -h * 0.115),
              Offset(w * 0.115 + eyeLookX, -h * 0.055),
            ]
          : [leftEyeCenter, rightEyeCenter];

      final Paint eyeGlowPaint = Paint()
        ..color = eyeColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      final Paint eyePaint = Paint()..color = eyeColor;
      final Paint highlightPaint = Paint()..color = Colors.white;

      for (final Offset c in eyeCenters) {
        final double ew = costume == 'costume_alien' ? w * 0.056 : w * 0.068;
        final double eh = costume == 'costume_alien' ? h * 0.072 : h * 0.088;
        final Rect r = Rect.fromCenter(center: c, width: ew, height: eh);
        canvas.drawOval(r, eyeGlowPaint);
        canvas.drawOval(r, eyePaint);
        canvas.drawCircle(
          c + Offset(-w * 0.01, -h * 0.014),
          w * 0.012,
          highlightPaint,
        );
      }
    }

    // Cute pink neon cheek blushes when happy
    if (isExcited) {
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
    }

    // Cute mouth arc
    final Paint mouthPaint = Paint()
      ..color = eyeColor
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
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final double w = size;
    final double h = size;
    final Path path = Path()
      ..moveTo(center.dx, center.dy + h * 0.35)
      ..cubicTo(
        center.dx - w * 0.6,
        center.dy,
        center.dx - w * 0.35,
        center.dy - h * 0.45,
        center.dx,
        center.dy - h * 0.15,
      )
      ..cubicTo(
        center.dx + w * 0.35,
        center.dy - h * 0.45,
        center.dx + w * 0.6,
        center.dy,
        center.dx,
        center.dy + h * 0.35,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  // Left hand
  // ===========================================================================
  // FITTED VECTOR COSTUME HELPERS
  // ===========================================================================

  void _drawAstronautJetpackBack(
    Canvas canvas,
    double w,
    double h,
    double phase,
  ) {
    final double flameFlicker = 0.85 + 0.3 * sin(phase * 8 * pi);
    for (final double side in [-1.0, 1.0]) {
      final double tx = side * w * 0.21;
      // Thruster flame
      final Path flame = Path()
        ..moveTo(tx - w * 0.038, h * 0.26)
        ..quadraticBezierTo(
          tx,
          h * (0.38 * flameFlicker),
          tx + w * 0.038,
          h * 0.26,
        )
        ..close();
      canvas.drawPath(
        flame,
        Paint()
          ..shader =
              const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF00E5FF),
                  Color(0xFFFF9100),
                  Color(0xFFFF3D00),
                ],
              ).createShader(
                Rect.fromLTWH(tx - w * 0.04, h * 0.25, w * 0.08, h * 0.15),
              ),
      );

      // Metallic Jetpack Cylinder
      final RRect tank = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(tx, h * 0.17),
          width: w * 0.095,
          height: h * 0.20,
        ),
        Radius.circular(w * 0.03),
      );
      canvas.drawRRect(
        tank,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF1F5F9), Color(0xFF94A3B8)],
          ).createShader(tank.outerRect),
      );
      canvas.drawRRect(
        tank,
        Paint()
          ..color = const Color(0xFF475569)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.014,
      );
    }
  }

  void _drawSaturnRingHalf(
    Canvas canvas,
    double w,
    double h, {
    required bool isFront,
  }) {
    canvas.save();
    canvas.translate(0, h * 0.14);
    canvas.rotate(-0.26); // Tilted Saturn ring angle

    final Rect outerRing = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.84,
      height: h * 0.22,
    );
    final Rect innerRing = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.68,
      height: h * 0.16,
    );

    final double startAngle = isFront ? 0.0 : pi;
    const double sweepAngle = pi;

    canvas.drawArc(
      outerRing,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = const Color(0xFFFBBF24).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      innerRing,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.024
        ..strokeCap = StrokeCap.round,
    );

    if (isFront) {
      // Little icy moon orbiting on the front ring
      canvas.drawCircle(
        Offset(w * 0.36, h * 0.05),
        w * 0.035,
        Paint()..color = const Color(0xFFE0F2FE),
      );
    }
    canvas.restore();
  }

  void _drawWizardCapeBack(Canvas canvas, double w, double h, double phase) {
    final double wave = sin(phase * 2 * pi) * (w * 0.02);
    final Path cape = Path()
      ..moveTo(-w * 0.16, h * 0.08)
      ..quadraticBezierTo(
        -w * 0.32 + wave,
        h * 0.22,
        -w * 0.28 + wave,
        h * 0.34,
      )
      ..quadraticBezierTo(0, h * 0.38, w * 0.28 + wave, h * 0.34)
      ..quadraticBezierTo(w * 0.32 + wave, h * 0.22, w * 0.16, h * 0.08)
      ..close();

    canvas.drawPath(
      cape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF311068), Color(0xFF4C1D95), Color(0xFF1E1B4B)],
        ).createShader(Rect.fromLTWH(-w * 0.32, h * 0.08, w * 0.64, h * 0.30)),
    );
    canvas.drawPath(
      cape,
      Paint()
        ..color = const Color(0xFFFBBF24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015,
    );
  }

  void _drawWizardHatOnHelmet(Canvas canvas, double w, double h) {
    // Curved Wizard Hat Cone sitting snugly on Byte's helmet (-h * 0.24)
    final Path cone = Path()
      ..moveTo(-w * 0.22, -h * 0.23)
      ..quadraticBezierTo(-w * 0.08, -h * 0.42, w * 0.08, -h * 0.48)
      ..quadraticBezierTo(w * 0.14, -h * 0.44, w * 0.06, -h * 0.36)
      ..lineTo(w * 0.22, -h * 0.23)
      ..close();

    canvas.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C1D95), Color(0xFF1E1B4B)],
        ).createShader(Rect.fromLTWH(-w * 0.25, -h * 0.48, w * 0.5, h * 0.26)),
    );
    canvas.drawPath(
      cone,
      Paint()
        ..color = const Color(0xFFFBBF24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015,
    );

    // Gold Ribbon Band at base of cone
    final Path band = Path()
      ..moveTo(-w * 0.21, -h * 0.235)
      ..quadraticBezierTo(0, -h * 0.265, w * 0.21, -h * 0.235)
      ..lineTo(w * 0.19, -h * 0.27)
      ..quadraticBezierTo(0, -h * 0.295, -w * 0.19, -h * 0.27)
      ..close();
    canvas.drawPath(band, Paint()..color = const Color(0xFFF59E0B));

    // Wide Wizard Hat Brim hugging helmet curve
    final Rect brimRect = Rect.fromCenter(
      center: Offset(0, -h * 0.23),
      width: w * 0.62,
      height: h * 0.085,
    );
    canvas.drawOval(brimRect, Paint()..color = const Color(0xFF311068));
    canvas.drawOval(
      brimRect,
      Paint()
        ..color = const Color(0xFFFBBF24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.016,
    );

    // Stars on wizard hat cone
    _drawFourPointStar(
      canvas,
      Offset(-w * 0.03, -h * 0.33),
      w * 0.032,
      const Color(0xFFFFD54F),
    );
    _drawFourPointStar(
      canvas,
      Offset(w * 0.05, -h * 0.40),
      w * 0.024,
      const Color(0xFF00E5FF),
    );
  }

  void _drawRoyalCapeBack(Canvas canvas, double w, double h, double phase) {
    final double wave = sin(phase * 2 * pi) * (w * 0.018);
    final Path cape = Path()
      ..moveTo(-w * 0.18, h * 0.07)
      ..quadraticBezierTo(
        -w * 0.35 + wave,
        h * 0.22,
        -w * 0.30 + wave,
        h * 0.35,
      )
      ..quadraticBezierTo(0, h * 0.39, w * 0.30 + wave, h * 0.35)
      ..quadraticBezierTo(w * 0.35 + wave, h * 0.22, w * 0.18, h * 0.07)
      ..close();

    canvas.drawPath(
      cape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBE123C), Color(0xFF881337)],
        ).createShader(Rect.fromLTWH(-w * 0.35, h * 0.07, w * 0.7, h * 0.32)),
    );
    canvas.drawPath(
      cape,
      Paint()
        ..color = const Color(0xFFFBBF24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018,
    );
  }

  void _drawRoyalCrownOnHelmet(Canvas canvas, double w, double h) {
    final Path crown = Path()
      ..moveTo(-w * 0.16, -h * 0.25)
      ..lineTo(-w * 0.18, -h * 0.38)
      ..lineTo(-w * 0.09, -h * 0.31)
      ..lineTo(0, -h * 0.42)
      ..lineTo(w * 0.09, -h * 0.31)
      ..lineTo(w * 0.18, -h * 0.38)
      ..lineTo(w * 0.16, -h * 0.25)
      ..close();

    canvas.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFEF08A), Color(0xFFF59E0B), Color(0xFFD97706)],
        ).createShader(Rect.fromLTWH(-w * 0.2, -h * 0.42, w * 0.4, h * 0.18)),
    );
    canvas.drawPath(
      crown,
      Paint()
        ..color = const Color(0xFF92400E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014,
    );

    // Crown jewels
    canvas.drawCircle(
      Offset(0, -h * 0.29),
      w * 0.022,
      Paint()..color = const Color(0xFFE11D48),
    );
    canvas.drawCircle(
      Offset(-w * 0.09, -h * 0.285),
      w * 0.016,
      Paint()..color = const Color(0xFF0284C7),
    );
    canvas.drawCircle(
      Offset(w * 0.09, -h * 0.285),
      w * 0.016,
      Paint()..color = const Color(0xFF10B981),
    );
  }

  void _drawNinjaKatanasBack(Canvas canvas, double w, double h) {
    // Two crossed plasma katana hilts behind shoulders
    for (final double side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(side * w * 0.18, h * 0.02);
      canvas.rotate(side * 0.55);
      final RRect hilt = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -h * 0.12),
          width: w * 0.042,
          height: h * 0.18,
        ),
        Radius.circular(w * 0.015),
      );
      canvas.drawRRect(hilt, Paint()..color = const Color(0xFF1E293B));
      canvas.drawRRect(
        hilt,
        Paint()
          ..color = side < 0 ? const Color(0xFF00E5FF) : const Color(0xFFF43F5E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.012,
      );
      canvas.restore();
    }
  }

  void _drawNinjaHeadbandOnHelmet(
    Canvas canvas,
    double w,
    double h,
    double phase,
  ) {
    final double flutter = sin(phase * 4 * pi) * (h * 0.025);
    // Flowing headband tails on right side of helmet
    final Path tail1 = Path()
      ..moveTo(w * 0.24, -h * 0.20)
      ..quadraticBezierTo(
        w * 0.36,
        -h * 0.25 + flutter,
        w * 0.43,
        -h * 0.19 - flutter,
      );
    final Path tail2 = Path()
      ..moveTo(w * 0.24, -h * 0.18)
      ..quadraticBezierTo(
        w * 0.35,
        -h * 0.16 - flutter,
        w * 0.41,
        -h * 0.11 + flutter,
      );
    final Paint tailPaint = Paint()
      ..color = const Color(0xFFE11D48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.032
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(tail1, tailPaint);
    canvas.drawPath(tail2, tailPaint);

    // Forehead band across helmet top
    final RRect band = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -h * 0.21),
        width: w * 0.53,
        height: h * 0.055,
      ),
      Radius.circular(w * 0.025),
    );
    canvas.drawRRect(band, Paint()..color = const Color(0xFFE11D48));

    // Metallic forehead plate
    final RRect plate = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -h * 0.21),
        width: w * 0.18,
        height: h * 0.042,
      ),
      Radius.circular(w * 0.01),
    );
    canvas.drawRRect(plate, Paint()..color = const Color(0xFFE2E8F0));
    canvas.drawLine(
      Offset(-w * 0.05, -h * 0.21),
      Offset(w * 0.05, -h * 0.21),
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = w * 0.012,
    );
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
        oldDelegate.darkThemeContext != darkThemeContext ||
        oldDelegate.appearance != appearance ||
        oldDelegate.isAvatarPortrait != isAvatarPortrait;
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
                  color: const Color(
                    0xFF311B92,
                  ).withValues(alpha: 0.36 - 0.08 * t),
                  blurRadius: glowBlur,
                  offset: Offset(0, shadowOffset),
                  spreadRadius: 1,
                ),
                // Outer glowing purple space aura
                BoxShadow(
                  color: const Color(
                    0xFF7C4DFF,
                  ).withValues(alpha: 0.42 + 0.14 * t),
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
                  child: Icon(widget.icon, color: Colors.white, size: 20),
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
