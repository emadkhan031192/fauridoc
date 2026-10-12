import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'onboarding_screen.dart';

/// Launch splash: brand mark on teal, then routes to onboarding (first run)
/// or straight into the app shell.
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
      await Future.delayed(const Duration(milliseconds: 1800));
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
    return Scaffold(
      backgroundColor: FauridocTheme.teal,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.all(12),
                child: Image.asset('assets/icon_mark.png'),
              ),
              const SizedBox(height: 20),
              Text(
                tr(ref, 'appName'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(ref, 'tagline'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
