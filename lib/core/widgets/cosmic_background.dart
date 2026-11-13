import 'dart:math';
import 'package:flutter/material.dart';

/// Deep-space palette constants used across the app's Cosmic UI.
class CosmicColors {
  static const Color deepVoid = Color(0xFF0B0620);
  static const Color spaceNavy = Color(0xFF170B3B);
  static const Color nebulaPurple = Color(0xFF31166D);
  static const Color cosmicViolet = Color(0xFF512DA8);
  static const Color starlightGold = Color(0xFFFFD54F);
  static const Color nebulaCyan = Color(0xFF4DD0E1);
  static const Color surfaceTint = Color(0xFFF3F1FA);

  static const LinearGradient appBarGradient = LinearGradient(
    colors: [
      Color(0xFF0E0728),
      Color(0xFF221152),
      Color(0xFF3E1F82),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dockGradient = LinearGradient(
    colors: [
      Color(0xFF10082B),
      Color(0xFF1F104F),
      Color(0xFF2E176A),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Color & motif configuration for each of the 6 Cosmic Leaderboard Leagues.
class CosmicLeagueThemeData {
  final String league;
  final List<Color> backgroundGradient;
  final List<Color> appBarGradient;
  final Color primaryAccent;
  final Color secondaryGlow;
  final int seed;

  const CosmicLeagueThemeData({
    required this.league,
    required this.backgroundGradient,
    required this.appBarGradient,
    required this.primaryAccent,
    required this.secondaryGlow,
    required this.seed,
  });

  static CosmicLeagueThemeData forLeague(String league) {
    switch (league) {
      case 'Stargazer':
        return const CosmicLeagueThemeData(
          league: 'Stargazer',
          backgroundGradient: [
            Color(0xFF231204),
            Color(0xFF4E2908),
            Color(0xFF87490D),
            Color(0xFF2D1638),
          ],
          appBarGradient: [
            Color(0xFF1F1003),
            Color(0xFF4A2707),
            Color(0xFF753E0B),
          ],
          primaryAccent: Color(0xFFFFCA28),
          secondaryGlow: Color(0xFFFF8F00),
          seed: 101,
        );
      case 'Explorer':
        return const CosmicLeagueThemeData(
          league: 'Explorer',
          backgroundGradient: [
            Color(0xFF11072E),
            Color(0xFF2A1468),
            Color(0xFF4E2799),
            Color(0xFF1C0E42),
          ],
          appBarGradient: [
            Color(0xFF0F0628),
            Color(0xFF26125E),
            Color(0xFF45228A),
          ],
          primaryAccent: Color(0xFFB388FF),
          secondaryGlow: Color(0xFF7C4DFF),
          seed: 202,
        );
      case 'Voyager':
        return const CosmicLeagueThemeData(
          league: 'Voyager',
          backgroundGradient: [
            Color(0xFF041F17),
            Color(0xFF0B4734),
            Color(0xFF157353),
            Color(0xFF082E29),
          ],
          appBarGradient: [
            Color(0xFF041C14),
            Color(0xFF0A3E2E),
            Color(0xFF136649),
          ],
          primaryAccent: Color(0xFF69F0AE),
          secondaryGlow: Color(0xFF00E676),
          seed: 303,
        );
      case 'Stellar Scholar':
        return const CosmicLeagueThemeData(
          league: 'Stellar Scholar',
          backgroundGradient: [
            Color(0xFF05102E),
            Color(0xFF0F286B),
            Color(0xFF1E47A8),
            Color(0xFF0B1B4A),
          ],
          appBarGradient: [
            Color(0xFF050E29),
            Color(0xFF0E2461),
            Color(0xFF1B3F96),
          ],
          primaryAccent: Color(0xFF82B1FF),
          secondaryGlow: Color(0xFF448AFF),
          seed: 404,
        );
      case 'Galactic Sage':
        return const CosmicLeagueThemeData(
          league: 'Galactic Sage',
          backgroundGradient: [
            Color(0xFF1E052B),
            Color(0xFF4A0E63),
            Color(0xFF7B1FA2),
            Color(0xFF2A093D),
          ],
          appBarGradient: [
            Color(0xFF1A0426),
            Color(0xFF400C57),
            Color(0xFF6A1B9A),
          ],
          primaryAccent: Color(0xFFEA80FC),
          secondaryGlow: Color(0xFFD500F9),
          seed: 505,
        );
      case 'Cosmic Legend':
        return const CosmicLeagueThemeData(
          league: 'Cosmic Legend',
          backgroundGradient: [
            Color(0xFF031D26),
            Color(0xFF074659),
            Color(0xFF00798C),
            Color(0xFF09253A),
          ],
          appBarGradient: [
            Color(0xFF031921),
            Color(0xFF063D4E),
            Color(0xFF006978),
          ],
          primaryAccent: Color(0xFF84FFFF),
          secondaryGlow: Color(0xFF00E5FF),
          seed: 606,
        );
      default:
        return const CosmicLeagueThemeData(
          league: 'Stargazer',
          backgroundGradient: [
            Color(0xFF11072E),
            Color(0xFF2A1468),
            Color(0xFF4E2799),
            Color(0xFF1C0E42),
          ],
          appBarGradient: [
            Color(0xFF0F0628),
            Color(0xFF26125E),
            Color(0xFF45228A),
          ],
          primaryAccent: CosmicColors.starlightGold,
          secondaryGlow: Color(0xFF7C4DFF),
          seed: 101,
        );
    }
  }
}

/// Full-screen animated cosmic background for the Leaderboard screen that changes
/// both its color palette and celestial artwork according to `league`.
class CosmicLeagueFullBackground extends StatelessWidget {
  final String league;
  final Widget child;

  const CosmicLeagueFullBackground({
    super.key,
    required this.league,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CosmicLeagueThemeData.forLeague(league);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.backgroundGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: CustomPaint(
                  key: ValueKey<String>('league_bg_$league'),
                  painter: _LeagueCelestialPainter(theme: theme),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Drop-in `flexibleSpace` widget for any `AppBar` to render a deep-space
/// nebula gradient with twinkling stars, constellation lines, and a ringed planet.
class CosmicAppBarFlexibleSpace extends StatelessWidget {
  final int seed;
  final bool showPlanet;
  final String? league;

  const CosmicAppBarFlexibleSpace({
    super.key,
    this.seed = 42,
    this.showPlanet = true,
    this.league,
  });

  @override
  Widget build(BuildContext context) {
    final leagueTheme =
        league != null ? CosmicLeagueThemeData.forLeague(league!) : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: leagueTheme != null
            ? LinearGradient(
                colors: leagueTheme.appBarGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : CosmicColors.appBarGradient,
      ),
      child: CustomPaint(
        painter: _StarfieldNebulaPainter(
          seed: leagueTheme?.seed ?? seed,
          showPlanet: showPlanet,
          density: 28,
          accentColor: leagueTheme?.primaryAccent,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Reusable cosmic banner container with deep-space nebula, stars, and optional ringed planet.
class CosmicNebulaBox extends StatelessWidget {
  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final int seed;
  final bool showPlanet;
  final List<Color>? gradientColors;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const CosmicNebulaBox({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.seed = 101,
    this.showPlanet = true,
    this.gradientColors,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: border,
        boxShadow: boxShadow,
        gradient: LinearGradient(
          colors: gradientColors ??
              const [
                Color(0xFF11082E),
                Color(0xFF26135C),
                Color(0xFF43228E),
              ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: _StarfieldNebulaPainter(
            seed: seed,
            showPlanet: showPlanet,
            density: 26,
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Subtle cosmic star-dust & constellation watermark for light/tinted scaffold bodies.
class CosmicAmbientScaffoldBody extends StatelessWidget {
  final Widget child;

  const CosmicAmbientScaffoldBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _AmbientConstellationPainter(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _LeagueCelestialPainter extends CustomPainter {
  final CosmicLeagueThemeData theme;

  const _LeagueCelestialPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rng = Random(theme.seed);

    // 1. Ambient Nebula Glows matching the league's color theme
    final glow1 = Paint()
      ..shader = RadialGradient(
        colors: [
          theme.primaryAccent.withValues(alpha: 0.25),
          theme.primaryAccent.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.82, size.height * 0.22),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.22),
      size.width * 0.55,
      glow1,
    );

    final glow2 = Paint()
      ..shader = RadialGradient(
        colors: [
          theme.secondaryGlow.withValues(alpha: 0.22),
          theme.secondaryGlow.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.18, size.height * 0.65),
          radius: size.width * 0.6,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.65),
      size.width * 0.6,
      glow2,
    );

    // 2. Starfield across the full screen
    for (int i = 0; i < 65; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final radius = 0.7 + rng.nextDouble() * 1.7;
      final alpha = 0.2 + rng.nextDouble() * 0.65;
      final isAccent = i % 4 == 0;
      final color = isAccent
          ? theme.primaryAccent.withValues(alpha: alpha)
          : Colors.white.withValues(alpha: alpha);

      canvas.drawCircle(Offset(dx, dy), radius, Paint()..color = color);

      if (i % 6 == 0) {
        final sparklePaint = Paint()
          ..color = color
          ..strokeWidth = 1.0;
        final arm = radius * 3.4;
        canvas.drawLine(Offset(dx - arm, dy), Offset(dx + arm, dy), sparklePaint);
        canvas.drawLine(Offset(dx, dy - arm), Offset(dx, dy + arm), sparklePaint);
      }
    }

    // 3. League-Specific Celestial Design Motif
    switch (theme.league) {
      case 'Stargazer':
        _paintStargazerMotif(canvas, size);
        break;
      case 'Explorer':
        _paintExplorerMotif(canvas, size);
        break;
      case 'Voyager':
        _paintVoyagerMotif(canvas, size);
        break;
      case 'Stellar Scholar':
        _paintStellarScholarMotif(canvas, size);
        break;
      case 'Galactic Sage':
        _paintGalacticSageMotif(canvas, size);
        break;
      case 'Cosmic Legend':
        _paintCosmicLegendMotif(canvas, size);
        break;
    }
  }

  /// Stargazer: Golden Sunburst + Big Dipper / Cassiopeia Constellations
  void _paintStargazerMotif(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.85, size.height * 0.18);
    final rayPaint = Paint()
      ..color = theme.primaryAccent.withValues(alpha: 0.18)
      ..strokeWidth = 1.4;

    for (int i = 0; i < 12; i++) {
      final angle = (i * pi) / 6;
      final r = size.width * 0.22;
      canvas.drawLine(
        center,
        Offset(center.dx + cos(angle) * r, center.dy + sin(angle) * r),
        rayPaint,
      );
    }
    canvas.drawCircle(
      center,
      22,
      Paint()..color = theme.primaryAccent.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      center,
      10,
      Paint()..color = const Color(0xFFFFF8E1).withValues(alpha: 0.55),
    );

    // Big Dipper constellation across the middle-bottom
    final dipper = <Offset>[
      Offset(size.width * 0.10, size.height * 0.32),
      Offset(size.width * 0.22, size.height * 0.29),
      Offset(size.width * 0.34, size.height * 0.33),
      Offset(size.width * 0.45, size.height * 0.36),
      Offset(size.width * 0.48, size.height * 0.45),
      Offset(size.width * 0.62, size.height * 0.46),
      Offset(size.width * 0.64, size.height * 0.37),
      Offset(size.width * 0.45, size.height * 0.36),
    ];
    final linePaint = Paint()
      ..color = theme.primaryAccent.withValues(alpha: 0.32)
      ..strokeWidth = 1.3;
    for (int i = 0; i < dipper.length - 1; i++) {
      canvas.drawLine(dipper[i], dipper[i + 1], linePaint);
    }
    for (final pt in dipper) {
      canvas.drawCircle(pt, 3.2, Paint()..color = theme.primaryAccent.withValues(alpha: 0.8));
    }
  }

  /// Explorer: Compass Rose Star & Curved Planetary Orbit Arcs
  void _paintExplorerMotif(Canvas canvas, Size size) {
    final orbitPaint = Paint()
      ..color = theme.primaryAccent.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.20),
      size.width * 0.28,
      orbitPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.20),
      size.width * 0.42,
      orbitPaint,
    );

    // Compass star emblem at top-left
    final compassCenter = Offset(size.width * 0.16, size.height * 0.22);
    final compassPaint = Paint()
      ..color = theme.primaryAccent.withValues(alpha: 0.38)
      ..strokeWidth = 1.8;
    canvas.drawLine(
      Offset(compassCenter.dx - 28, compassCenter.dy),
      Offset(compassCenter.dx + 28, compassCenter.dy),
      compassPaint,
    );
    canvas.drawLine(
      Offset(compassCenter.dx, compassCenter.dy - 28),
      Offset(compassCenter.dx, compassCenter.dy + 28),
      compassPaint,
    );
    canvas.drawCircle(
      compassCenter,
      14,
      orbitPaint,
    );
  }

  /// Voyager: Flowing Emerald Aurora Borealis Waves & Ringed World
  void _paintVoyagerMotif(Canvas canvas, Size size) {
    for (int w = 0; w < 3; w++) {
      final path = Path();
      final baseY = size.height * (0.18 + w * 0.14);
      path.moveTo(0, baseY);
      path.cubicTo(
        size.width * 0.25,
        baseY - 38,
        size.width * 0.55,
        baseY + 42,
        size.width,
        baseY - 18,
      );
      final auroraPaint = Paint()
        ..color = theme.primaryAccent.withValues(alpha: 0.18 - w * 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0 - w * 3;
      canvas.drawPath(path, auroraPaint);
    }

    // Ringed Exoplanet
    final planetCenter = Offset(size.width * 0.82, size.height * 0.22);
    canvas.drawCircle(
      planetCenter,
      26,
      Paint()..color = theme.primaryAccent.withValues(alpha: 0.22),
    );
    canvas.save();
    canvas.translate(planetCenter.dx, planetCenter.dy);
    canvas.rotate(-0.28);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 78, height: 22),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.restore();
  }

  /// Stellar Scholar: Geometric Celestial Astrolabe Rings & Binary Stars
  void _paintStellarScholarMotif(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.24);
    final ringPaint = Paint()
      ..color = theme.primaryAccent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, size.width * 0.22, ringPaint);
    canvas.drawCircle(center, size.width * 0.32, ringPaint);

    // Inscribed diamond / astrolabe axes
    final r = size.width * 0.22;
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r, center.dy)
      ..close();
    canvas.drawPath(path, ringPaint);
  }

  /// Galactic Sage: Swirling Spiral Galaxy & Mystic Pulsar Rings
  void _paintGalacticSageMotif(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.78, size.height * 0.22);
    final spiralPaint = Paint()
      ..color = theme.primaryAccent.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    for (int arm = 0; arm < 2; arm++) {
      final path = Path();
      final offsetAngle = arm * pi;
      for (double t = 0; t < 3.6 * pi; t += 0.15) {
        final radius = 3.5 * t;
        final x = center.dx + radius * cos(t + offsetAngle);
        final y = center.dy + radius * 0.65 * sin(t + offsetAngle);
        if (t == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, spiralPaint);
    }
    canvas.drawCircle(
      center,
      10,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  /// Cosmic Legend: Multi-Ringed Celestial Saturn + Shooting Golden Comets
  void _paintCosmicLegendMotif(Canvas canvas, Size size) {
    // Shooting comets
    final cometPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          CosmicColors.starlightGold.withValues(alpha: 0.7),
          theme.primaryAccent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5))
      ..strokeWidth = 2.2;

    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.14),
      Offset(size.width * 0.04, size.height * 0.06),
      cometPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.14),
      3.0,
      Paint()..color = CosmicColors.starlightGold,
    );

    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.34),
      Offset(size.width * 0.56, size.height * 0.25),
      cometPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.34),
      3.0,
      Paint()..color = CosmicColors.starlightGold,
    );

    // Multi-ringed Quasar Planet
    final planetCenter = Offset(size.width * 0.84, size.height * 0.19);
    canvas.drawCircle(
      planetCenter,
      28,
      Paint()..color = theme.primaryAccent.withValues(alpha: 0.26),
    );
    canvas.save();
    canvas.translate(planetCenter.dx, planetCenter.dy);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 88, height: 24),
      Paint()
        ..color = CosmicColors.starlightGold.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 104, height: 32),
      Paint()
        ..color = theme.primaryAccent.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LeagueCelestialPainter oldDelegate) =>
      oldDelegate.theme.league != theme.league;
}

class _StarfieldNebulaPainter extends CustomPainter {
  final int seed;
  final bool showPlanet;
  final int density;
  final Color? accentColor;

  const _StarfieldNebulaPainter({
    required this.seed,
    required this.showPlanet,
    this.density = 28,
    this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rng = Random(seed);
    final highlight = accentColor ?? const Color(0xFF7C4DFF);

    // 1. Soft glowing nebula clouds
    final nebulaPaint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          highlight.withValues(alpha: 0.28),
          highlight.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.22, size.height * 0.35),
          radius: size.width * 0.45,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.35),
      size.width * 0.45,
      nebulaPaint1,
    );

    final nebulaPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.16),
          const Color(0xFF00E5FF).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.82, size.height * 0.65),
          radius: size.width * 0.38,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.65),
      size.width * 0.38,
      nebulaPaint2,
    );

    // 2. Subtle constellation lines
    final constellationPoints = <Offset>[
      Offset(size.width * 0.12, size.height * 0.68),
      Offset(size.width * 0.21, size.height * 0.36),
      Offset(size.width * 0.33, size.height * 0.52),
      Offset(size.width * 0.44, size.height * 0.26),
    ];
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < constellationPoints.length - 1; i++) {
      canvas.drawLine(constellationPoints[i], constellationPoints[i + 1], linePaint);
    }
    for (final pt in constellationPoints) {
      canvas.drawCircle(
        pt,
        2.0,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // 3. Starfield & 4-point sparkle stars
    for (int i = 0; i < density; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final radius = 0.6 + rng.nextDouble() * 1.5;
      final alpha = 0.25 + rng.nextDouble() * 0.65;
      final isGold = i % 6 == 0;
      final starColor = isGold
          ? (accentColor ?? const Color(0xFFFFE082)).withValues(alpha: alpha)
          : Colors.white.withValues(alpha: alpha);

      canvas.drawCircle(Offset(dx, dy), radius, Paint()..color = starColor);

      // Draw a 4-point sparkle on every 7th star
      if (i % 7 == 0) {
        final sparklePaint = Paint()
          ..color = starColor
          ..strokeWidth = 0.9;
        final arm = radius * 3.2;
        canvas.drawLine(Offset(dx - arm, dy), Offset(dx + arm, dy), sparklePaint);
        canvas.drawLine(Offset(dx, dy - arm), Offset(dx, dy + arm), sparklePaint);
      }
    }

    // 4. Optional ringed planet silhouette in top-right corner
    if (showPlanet) {
      final planetCenter = Offset(size.width * 0.88, size.height * 0.34);
      final planetRadius = (size.height * 0.22).clamp(12.0, 26.0);

      // Planet body
      final planetPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            highlight.withValues(alpha: 0.35),
            const Color(0xFF311B92).withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(
          Rect.fromCircle(center: planetCenter, radius: planetRadius),
        );
      canvas.drawCircle(planetCenter, planetRadius, planetPaint);

      // Planet ring
      canvas.save();
      canvas.translate(planetCenter.dx, planetCenter.dy);
      canvas.rotate(-0.32);
      final ringPaint = Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: planetRadius * 3.1,
          height: planetRadius * 0.82,
        ),
        ringPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldNebulaPainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.showPlanet != showPlanet ||
      oldDelegate.accentColor != accentColor;
}

class _AmbientConstellationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rng = Random(77);

    // Soft top-right & bottom-left nebula wash
    final wash1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7E57C2).withValues(alpha: 0.07),
          const Color(0xFF7E57C2).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.12),
          radius: size.width * 0.65,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.12),
      size.width * 0.65,
      wash1,
    );

    final wash2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF26C6DA).withValues(alpha: 0.05),
          const Color(0xFF26C6DA).withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.1, size.height * 0.82),
          radius: size.width * 0.6,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.82),
      size.width * 0.6,
      wash2,
    );

    // Faint stardust dots
    final dotPaint = Paint()..color = const Color(0xFF5E35B1).withValues(alpha: 0.10);
    for (int i = 0; i < 24; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = 1.0 + rng.nextDouble() * 1.6;
      canvas.drawCircle(Offset(dx, dy), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
