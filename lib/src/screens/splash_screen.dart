import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../l10n/strings_b.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'onboarding_screen.dart';

/// Launch splash: brand mark on teal with concentric circles, then routes to
/// onboarding (first run) or straight into the app shell.
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: FdColors.primary,
      body: Stack(
        children: [
          // Subtle concentric circles behind the logo.
          Positioned.fill(
            child: CustomPaint(painter: _CirclesPainter()),
          ),
          SafeArea(
            child: SizedBox(
              width: size.width,
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  const FdLogo(size: 112),
                  const SizedBox(height: 26),
                  Text(
                    'Fauridoc',
                    style: TextStyle(
                      fontFamily: FdType.latin,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    trB(ref, 'splash.tagline'),
                    textAlign: TextAlign.center,
                    style: FdType.body(ur,
                        size: 17, w: FontWeight.w500, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  // Urdu tagline is part of the design in both locales.
                  Text(
                    trB(ref, 'splash.taglineUr'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: FdType.urdu,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      height: 2.0,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Page dots: first active.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dot(Colors.white),
                      _dot(Colors.white.withValues(alpha: 0.35)),
                      _dot(Colors.white.withValues(alpha: 0.35)),
                    ],
                  ),
                  const Spacer(flex: 4),
                  Text(
                    trB(ref, 'splash.madeFor'),
                    textAlign: TextAlign.center,
                    style: FdType.label(ur,
                        size: 13,
                        w: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trB(ref, 'splash.byLine'),
                    textAlign: TextAlign.center,
                    style: FdType.label(ur,
                        size: 13,
                        w: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75)),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Faint concentric circles centered on the logo area.
class _CirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final center = Offset(size.width / 2, size.height * 0.38);
    for (final r in [150.0, 240.0, 340.0, 460.0]) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
