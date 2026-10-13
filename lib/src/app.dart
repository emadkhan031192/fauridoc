import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/auth.dart';
import 'providers/font_scale.dart';
import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/community_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/theme.dart';

/// Root widget: wires auth, locale persistence, and the bottom-nav shell.
class FauridocApp extends ConsumerStatefulWidget {
  final SharedPreferences prefs;
  final AuthBackend authBackend;
  final bool demoMode;

  const FauridocApp({
    super.key,
    required this.prefs,
    required this.authBackend,
    required this.demoMode,
  });

  @override
  ConsumerState<FauridocApp> createState() => _FauridocAppState();
}

class _FauridocAppState extends ConsumerState<FauridocApp> {
  @override
  void initState() {
    super.initState();
    // Attach auth backend + restore saved locale and font scales.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).attach(widget.authBackend);
      ref.read(localeProvider.notifier).load(widget.prefs.getString('locale') ?? 'en');
      ref.read(fontScaleProvider.notifier).load(
            widget.prefs.getDouble(kFontScaleEnKey) ?? kDefaultEnScale,
            widget.prefs.getDouble(kFontScaleUrKey) ?? kDefaultUrScale,
          );
    });
    ref.listenManual(localeProvider, (prev, next) {
      widget.prefs.setString('locale', next);
    });
    ref.listenManual(fontScaleProvider, (prev, next) {
      widget.prefs.setDouble(kFontScaleEnKey, next.en);
      widget.prefs.setDouble(kFontScaleUrKey, next.ur);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final seenOnboarding = widget.prefs.getBool('seen_onboarding') ?? false;

    return MaterialApp(
      title: 'Fauridoc',
      debugShowCheckedModeBanner: false,
      locale: Locale(locale),
      theme: fauridocTheme(locale),
      home: Directionality(
        textDirection: locale == 'ur' ? TextDirection.rtl : TextDirection.ltr,
        child: SplashScreen(
          prefs: widget.prefs,
          showOnboarding: !seenOnboarding,
          demoMode: widget.demoMode,
        ),
      ),
    );
  }
}

/// Main shell with bottom navigation: Home / Search / Map / Community / Profile.
class HomeShell extends ConsumerWidget {
  final bool demoMode;

  const HomeShell({super.key, required this.demoMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabIndexProvider);
    final locale = ref.watch(localeProvider);
    ref.watch(fontScaleProvider); // Re-render when the font-size sliders change.

    final screens = [
      const HomeScreen(),
      const SearchScreen(),
      const MapScreen(),
      const CommunityScreen(),
      ProfileScreen(demoMode: demoMode),
    ];

    return Directionality(
      textDirection: locale == 'ur' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: IndexedStack(index: tab, children: screens),
        bottomNavigationBar: FdBottomNav(
          currentIndex: tab,
          onTap: (i) => ref.read(tabIndexProvider.notifier).setTab(i),
          isUrdu: locale == 'ur',
          labels: [
            tr(ref, 'navHome'),
            tr(ref, 'navSearch'),
            tr(ref, 'navMap'),
            tr(ref, 'navCommunity'),
            tr(ref, 'navProfile'),
          ],
        ),
      ),
    );
  }
}
