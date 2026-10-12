import 'package:flutter_test/flutter_test.dart';

import 'package:fauridoc/src/l10n/strings.dart';
import 'package:fauridoc/src/l10n/strings_en.dart';
import 'package:fauridoc/src/l10n/strings_ur.dart';

void main() {
  test('every key exists in both locales', () {
    for (final key in allKeys) {
      expect(enStrings.containsKey(key), isTrue, reason: 'missing in en: $key');
      expect(urStrings.containsKey(key), isTrue, reason: 'missing in ur: $key');
    }
  });

  test('no empty values in either locale', () {
    for (final entry in enStrings.entries) {
      expect(entry.value.isNotEmpty, isTrue, reason: 'empty en value: ${entry.key}');
    }
    for (final entry in urStrings.entries) {
      expect(entry.value.isNotEmpty, isTrue, reason: 'empty ur value: ${entry.key}');
    }
  });
}
