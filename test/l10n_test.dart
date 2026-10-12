import 'package:flutter_test/flutter_test.dart';

import 'package:fauridoc/src/l10n/strings.dart';
import 'package:fauridoc/src/l10n/strings_b.dart';
import 'package:fauridoc/src/l10n/strings_c.dart';
import 'package:fauridoc/src/l10n/strings_d.dart';
import 'package:fauridoc/src/l10n/strings_en.dart';
import 'package:fauridoc/src/l10n/strings_ur.dart';

void main() {
  test('every key has a real translation in both locales', () {
    for (final key in allKeys) {
      expect(hasTranslation('en', key), isTrue, reason: 'missing in en: $key');
      expect(hasTranslation('ur', key), isTrue, reason: 'missing in ur: $key');
    }
  });

  test('no empty values in either locale', () {
    for (final key in allKeys) {
      expect(translate('en', key).isNotEmpty, isTrue,
          reason: 'empty en value: $key');
      expect(translate('ur', key).isNotEmpty, isTrue,
          reason: 'empty ur value: $key');
      expect(translate('en', key) == key, isFalse,
          reason: 'untranslated en key: $key');
    }
  });

  test('no key is defined twice within one locale (shadowing)', () {
    // en and ur are separate locales; uniqueness is required within each.
    for (final group in [
      [enStrings, enB, enC, enD],
      [urStrings, urB, urC, urD],
    ]) {
      final owners = <String, int>{};
      for (var i = 0; i < group.length; i++) {
        for (final key in group[i].keys) {
          if (owners.containsKey(key)) {
            fail('key "$key" defined in two tables ([${owners[key]}, $i])');
          }
          owners[key] = i;
        }
      }
    }
  });
}
