import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/tokens.dart';
import '../app.dart';
import '../l10n/strings_b.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';

/// Single onboarding screen (design page-02). "Next"/"Skip" mark onboarding
/// seen and enter the app shell.
///
/// Layout is pixel-matched to `design/fauridoc-screens.html` §Onboarding
/// (390x844 artboard, 1 CSS px = 1 Flutter logical px). The seen-flag logic
/// and navigation are untouched.
class OnboardingScreen extends ConsumerStatefulWidget {
  final SharedPreferences prefs;
  final bool demoMode;

  const OnboardingScreen({
    super.key,
    required this.prefs,
    required this.demoMode,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Future<void> _finish() async {
    await widget.prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeShell(demoMode: widget.demoMode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final family = ur ? FdType.urdu : FdType.latin;

    return Scaffold(
      backgroundColor: FdSpec.pageBg,
      body: Padding(
        // Spec: padding 48px 24px 40px.
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Skip row: 44 px tall, aligned right.
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _PressScale(
                    onTap: _finish,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        trB(ref, 'onb.skip'),
                        style: TextStyle(
                          fontFamily: family,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: FdColors.muted,
                          height: 44 / 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Illustration fills the flexible middle area, centered.
            Expanded(
              child: Center(
                child: CustomPaint(
                  size: const Size(320, 260),
                  painter: _OnboardingArtPainter(),
                ),
              ),
            ),
            // Title + body block: 10 px gap.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trB(ref, 'onb.title'),
                  style: TextStyle(
                    fontFamily: family,
                    fontSize: 30,
                    fontWeight: ur ? FontWeight.w700 : FontWeight.w800,
                    letterSpacing: ur ? 0 : -0.75, // -0.025em
                    height: ur ? 2.0 : 1.1,
                    color: FdColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  trB(ref, 'onb.body'),
                  style: TextStyle(
                    fontFamily: family,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: ur ? 2.4 : 1.5,
                    color: FdColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Dots + Next.
            Row(
              children: [
                // Active dash: 26x8, radius 4, teal.
                Container(
                  width: 26,
                  height: 8,
                  decoration: BoxDecoration(
                    color: FdColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                _dot(),
                const SizedBox(width: 8),
                _dot(),
                const Spacer(),
                _PressScale(
                  onTap: _finish,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    decoration: BoxDecoration(
                      color: FdColors.primary,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          trB(ref, 'onb.next'),
                          style: TextStyle(
                            fontFamily: family,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CustomPaint(
                          size: const Size(18, 18),
                          painter: _ArrowPainter(ur: ur),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Inactive dot: 8x8, radius 4, #C9D3CF.
  Widget _dot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFC9D3CF),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Press feedback for elements with the spec's `press` class:
/// scales to 0.97 in 80 ms while pressed.
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: widget.child,
      ),
    );
  }
}

/// The spec's "Next" arrow SVG: M5 12h14 M13 6l6 6-6 6, stroke 2.2.
class _ArrowPainter extends CustomPainter {
  final bool ur;
  const _ArrowPainter({required this.ur});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.save();
    if (ur) {
      // Mirror the arrow for RTL.
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawLine(Offset(5 * s, 12 * s), Offset(19 * s, 12 * s), paint);
    canvas.drawPath(
      Path()
        ..moveTo(13 * s, 6 * s)
        ..lineTo(19 * s, 12 * s)
        ..lineTo(13 * s, 18 * s),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The spec's onboarding illustration, drawn from the SVG in the design:
/// mint disc, tilted card behind, front doctor card (avatar, name bars,
/// stars, rating pill), and the teal verified-check badge.
/// The SVG is 300x240 shown at 320x260 with meet-fit (uniform scale, centered).
class _OnboardingArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Meet-fit: uniform scale so 300x240 fits 320x260, centered.
    final s = size.width / 300; // 1.0667
    canvas.translate(0, (size.height - 240 * s) / 2);
    canvas.scale(s);

    const mint = Color(0xFFDDF0EA);
    const teal = Color(0xFF0B6B5C);
    const hairline = Color(0xFFC9D3CF);
    const peachBg = Color(0xFFFFE6D2);
    const peachInk = Color(0xFF8A3F00);
    const ink = Color(0xFF0F2A2E);
    const star = Color(0xFFF5B400);
    const starOff = Color(0xFFE1E7E4);
    const pillBg = Color(0xFFE4F3EF);

    // Mint disc.
    canvas.drawCircle(
      const Offset(150, 120),
      112,
      Paint()..color = mint,
    );

    // Back card, rotated -7 deg about (144, 108).
    canvas.save();
    canvas.translate(144, 108);
    canvas.rotate(-7 * 3.141592653589793 / 180);
    canvas.translate(-144, -108);
    canvas.drawRRect(
      RRect.fromLTRBR(58, 48, 58 + 172, 48 + 120, const Radius.circular(16)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(58, 48, 58 + 172, 48 + 120, const Radius.circular(16)),
      Paint()
        ..color = hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();

    // Front card.
    final card = RRect.fromLTRBR(76, 68, 76 + 172, 68 + 124,
        const Radius.circular(16));
    canvas.drawRRect(card, Paint()..color = Colors.white);
    canvas.drawRRect(
      card,
      Paint()
        ..color = teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Avatar.
    canvas.drawCircle(
      const Offset(110, 104),
      21,
      Paint()..color = peachBg,
    );
    // Face: eye dot + smile, #8A3F00.
    canvas.drawCircle(const Offset(110, 98), 6, Paint()..color = peachInk);
    canvas.drawPath(
      Path()
        ..moveTo(98, 118)
        ..cubicTo(100, 110, 120, 110, 122, 118),
      Paint()
        ..color = peachInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Name + sub bars.
    canvas.drawRRect(
      RRect.fromLTRBR(142, 92, 142 + 76, 92 + 9, const Radius.circular(4.5)),
      Paint()..color = ink,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(142, 110, 142 + 52, 110 + 7, const Radius.circular(3.5)),
      Paint()..color = hairline,
    );

    // Stars: 4 gold, last off.
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(98 + 16.0 * i, 156),
        5.5,
        Paint()..color = i < 4 ? star : starOff,
      );
    }

    // Rating pill.
    canvas.drawRRect(
      RRect.fromLTRBR(182, 148, 182 + 50, 148 + 16, const Radius.circular(8)),
      Paint()..color = pillBg,
    );

    // Verified badge.
    canvas.drawCircle(
      const Offset(244, 74),
      18,
      Paint()..color = teal,
    );
    canvas.drawPath(
      Path()
        ..moveTo(236, 74.5)
        ..lineTo(241.5, 80)
        ..lineTo(252, 69),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
