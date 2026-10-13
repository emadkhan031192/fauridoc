import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/tokens.dart';
import '../app.dart';
import '../l10n/strings_b.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'onboarding_screen.dart';

/// Launch splash: brand mark on teal with concentric circles, then routes to
/// onboarding (first run) or straight into the app shell.
///
/// Layout is pixel-matched to `design/fauridoc-screens.html` §Splash
/// (390x844 artboard, 1 CSS px = 1 Flutter logical px). Navigation timing
/// (1600 ms auto-advance) is untouched.
class SplashScreen extends ConsumerStatefulWidget {
  final SharedPreferences prefs;
  final bool showOnboarding;
  final bool demoMode;

  const SplashScreen({
    super.key,
    required this.prefs,
    required this.showOnboarding,
    required this.demoMode,
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.showOnboarding
              ? OnboardingScreen(
                  prefs: widget.prefs,
                  demoMode: widget.demoMode,
                )
              : HomeShell(demoMode: widget.demoMode),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);

    return Scaffold(
      backgroundColor: FdSpec.splashBg,
      body: Stack(
        children: [
          // Three faint concentric circles (560/400/250 px) per the spec.
          Positioned.fill(
            child: CustomPaint(painter: _CirclesPainter()),
          ),
          // Logo block at margin-top 270.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 270),
              const Center(child: _LogoTile()),
              const SizedBox(height: 26),
              const Text(
                'Fauridoc',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: FdType.latin,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.26, // -0.03em
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                trB(ref, 'splash.tagline'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: FdType.family(ur),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 10),
              // Urdu tagline is part of the design in both locales.
              Text(
                trB(ref, 'splash.taglineUr'),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: FdType.urdu,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  height: 2.0,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          // Footer pinned at bottom 56: fading dots + two credit lines.
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(Colors.white),
                    _dot(Colors.white.withValues(alpha: 0.5)),
                    _dot(Colors.white.withValues(alpha: 0.3)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  trB(ref, 'splash.madeFor'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: FdType.family(ur),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.72, // 0.06em
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  trB(ref, 'splash.byLine'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: FdType.family(ur),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.72, // 0.06em
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// White 104 px rounded logo tile with the spec's exact shadow and mark.
class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(0, 18),
            blurRadius: 40,
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(60, 60),
          painter: _LogoMarkPainter(),
        ),
      ),
    );
  }
}

/// The spec's logo SVG: teal plus + orange bolt on a 24x24 grid.
class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24; // 60 px / 24 grid
    final teal = Paint()..color = FdSpec.primary;
    final orange = Paint()..color = const Color(0xFFFF7A1A);

    // M9.5 3h5v6.5H21v5h-6.5V21h-5v-6.5H3v-5h6.5z
    final plus = Path()
      ..moveTo(9.5 * s, 3 * s)
      ..lineTo(14.5 * s, 3 * s)
      ..lineTo(14.5 * s, 9.5 * s)
      ..lineTo(21 * s, 9.5 * s)
      ..lineTo(21 * s, 14.5 * s)
      ..lineTo(14.5 * s, 14.5 * s)
      ..lineTo(14.5 * s, 21 * s)
      ..lineTo(9.5 * s, 21 * s)
      ..lineTo(9.5 * s, 14.5 * s)
      ..lineTo(3 * s, 14.5 * s)
      ..lineTo(3 * s, 9.5 * s)
      ..lineTo(9.5 * s, 9.5 * s)
      ..close();
    canvas.drawPath(plus, teal);

    // M13.6 8.2l-3.4 4.6h2.6l-.9 3.6 3.6-5h-2.6z
    final bolt = Path()
      ..moveTo(13.6 * s, 8.2 * s)
      ..lineTo(10.2 * s, 12.8 * s)
      ..lineTo(12.8 * s, 12.8 * s)
      ..lineTo(11.9 * s, 16.4 * s)
      ..lineTo(15.5 * s, 11.4 * s)
      ..lineTo(12.9 * s, 11.4 * s)
      ..close();
    canvas.drawPath(bolt, orange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The three spec circles, positioned on the 390x844 artboard grid:
/// 560 px @ center (195,372) alpha .07; 400 px @ (133,858) alpha .10;
/// 250 px @ center (195,372) alpha .14.
class _CirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * (195 / 390);
    final cyMain = size.height * (372 / 844);
    final cx2 = size.width * (133 / 390);
    final cy2 = size.height * (858 / 844);

    void circle(double x, double y, double r, double alpha) {
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    circle(cx, cyMain, 280, 0.07);
    circle(cx2, cy2, 200, 0.10);
    circle(cx, cyMain, 125, 0.14);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
