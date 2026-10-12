import 'package:flutter_test/flutter_test.dart';

import 'package:fauridoc/src/utils/geo.dart';

void main() {
  group('haversineKm', () {
    test('Mardan to Peshawar is about 47 km', () {
      final km = haversineKm(34.20, 72.04, 34.01, 71.58);
      expect(km, inInclusiveRange(45.0, 55.0));
    });

    test('same point is zero', () {
      expect(haversineKm(34.20, 72.04, 34.20, 72.04), lessThan(0.001));
    });
  });

  group('formatDistance', () {
    test('formats meters and kilometers', () {
      expect(formatDistance(0.85), '850 m');
      expect(formatDistance(3.24), '3.2 km');
    });
  });
}
