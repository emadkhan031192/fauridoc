import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/app_user.dart';
import '../data/auth.dart';

/// Overridden in main() with the real repository (demo or Firestore).
final repositoryProvider = Provider<FauridocRepository>((ref) {
  throw UnimplementedError('repositoryProvider must be overridden in main()');
});

/// 'en' or 'ur'. Persisted in SharedPreferences by [LocaleNotifier].
final localeProvider = NotifierProvider<LocaleNotifier, String>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<String> {
  @override
  String build() => 'en';

  Future<void> load(String saved) async {
    if (saved == 'ur' || saved == 'en') state = saved;
  }

  void setLocale(String code) {
    if (code == 'ur' || code == 'en') state = code;
  }

  void toggle() => state = state == 'en' ? 'ur' : 'en';
}

/// Current signed-in user (null = guest). Managed by [AuthController].
final authProvider = NotifierProvider<AuthController, AppUser?>(AuthController.new);

/// The user's selected city scope. Defaults to the first configured city.
final cityProvider = NotifierProvider<CityNotifier, String>(CityNotifier.new);

class CityNotifier extends Notifier<String> {
  @override
  String build() => 'Mardan';

  void setCity(String city) => state = city;
}

/// Bottom-nav tab index.
final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);

class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int i) => state = i;
}

/// Demo-only "Admin preview" toggle (lets the user preview the admin panel
/// without Firebase). Hidden entirely in Firestore mode.
final demoAdminPreviewProvider = NotifierProvider<DemoAdminPreviewNotifier, bool>(
  DemoAdminPreviewNotifier.new,
);

class DemoAdminPreviewNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
  void toggle() => state = !state;
}

/// Translate key [k] for the current locale.
String tr(WidgetRef ref, String k) => translate(ref.watch(localeProvider), k);

/// Non-widget helper (tests, etc.).
String trCode(String locale, String k) => translate(locale, k);
