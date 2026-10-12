import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../l10n/strings_b.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';

/// Single onboarding screen (design page-02). "Next"/"Skip" mark onboarding
/// seen and enter the app shell.
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, left: 20, right: 20),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    trB(ref, 'onb.skip'),
                    style: FdType.body(ur,
                        size: 16,
                        w: FontWeight.w600,
                        color: FdColors.primary),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
            // Illustration: mint circle, stacked cards, verified badge.
            const Center(child: _OnboardingArt()),
            const Spacer(flex: 2),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: FdDim.page),
              child: Text(
                trB(ref, 'onb.title'),
                style: FdType.display(ur, size: 34),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: FdDim.page),
              child: Text(
                trB(ref, 'onb.body'),
                style: FdType.body(ur, size: 16, color: FdColors.inkSoft),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: FdDim.page),
              child: Row(
                children: [
                  // Progress: teal dash + 2 grey dots.
                  Container(
                    width: 38,
                    height: 10,
                    decoration: BoxDecoration(
                      color: FdColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _progressDot(),
                  const SizedBox(width: 8),
                  _progressDot(),
                  const Spacer(),
                  FdButton(
                    label: trB(ref, 'onb.next'),
                    icon: Icons.arrow_forward,
                    isUrdu: ur,
                    onTap: _finish,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _progressDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: FdColors.primary.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// The onboarding illustration, composed from widgets:
/// mint disc, a tilted card behind, the doctor card, and a check badge.
class _OnboardingArt extends StatelessWidget {
  const _OnboardingArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Mint disc.
          Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              color: FdColors.mintDeep,
              shape: BoxShape.circle,
            ),
          ),
          // Card behind, slightly tilted.
          Transform.rotate(
            angle: -0.1,
            child: Container(
              width: 218,
              height: 158,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: FdColors.line, width: 1.5),
              ),
            ),
          ),
          // Front card.
          Container(
            width: 218,
            height: 158,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: FdColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: FdColors.primary.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar.
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: FdColors.peach,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: FdColors.peachInk,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name bars.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 13,
                            width: 110,
                            decoration: BoxDecoration(
                              color: FdColors.ink,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 70,
                            decoration: BoxDecoration(
                              color: FdColors.line,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Star dots + rating pill.
                Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 7),
                        decoration: const BoxDecoration(
                          color: FdColors.starGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: FdColors.primary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 62,
                      height: 20,
                      decoration: BoxDecoration(
                        color: FdColors.mintDeep,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Verified badge overlapping the card's top corner.
          const Positioned(
            top: 34,
            right: 26,
            child: _CheckBadge(),
          ),
        ],
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: FdColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: FdColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 30),
    );
  }
}
