import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/theme.dart';

/// SharedPreferences keys for the user font-size scales.
const String kFontScaleEnKey = 'font_scale_en';
const String kFontScaleUrKey = 'font_scale_ur';

/// Default scales: Latin 1.0x, Urdu 0.9x (the historic Nastaliq reduction).
const double kDefaultEnScale = 1.0;
const double kDefaultUrScale = 0.9;

/// User-adjustable font scales, persisted in SharedPreferences (loaded in
/// `FauridocApp.initState`, saved on every change — same pattern as
/// [localeProvider]).
///
/// The notifier mirrors the values onto [FdType.enScale]/[FdType.urScale] so
/// the (static) [FdType] text-style methods apply the user scale without a
/// [WidgetRef] in their signatures. Watching this provider re-renders the
/// watching widget, so screens add `ref.watch(fontScaleProvider)` at the top
/// of `build` to pick up slider changes.
final fontScaleProvider =
    NotifierProvider<FontScaleNotifier, ({double en, double ur})>(
  FontScaleNotifier.new,
);

class FontScaleNotifier extends Notifier<({double en, double ur})> {
  @override
  ({double en, double ur}) build() =>
      (en: FdType.enScale, ur: FdType.urScale);

  /// Restore persisted values (called once from `FauridocApp.initState`).
  Future<void> load(double en, double ur) async {
    state = (en: en, ur: ur);
    FdType.enScale = en;
    FdType.urScale = ur;
  }

  void setEn(double v) {
    state = (en: v, ur: state.ur);
    FdType.enScale = v;
  }

  void setUr(double v) {
    state = (en: state.en, ur: v);
    FdType.urScale = v;
  }
}

/// Widget-side helper: watches [fontScaleProvider] (so the caller rebuilds
/// when a slider moves) and returns the scaled size for the script.
double fdFontSize(WidgetRef ref, double base, bool ur) {
  final scales = ref.watch(fontScaleProvider);
  return base * (ur ? scales.ur : scales.en);
}
