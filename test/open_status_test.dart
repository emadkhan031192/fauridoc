import 'package:flutter_test/flutter_test.dart';

import 'package:fauridoc/src/models/day_hours.dart';
import 'package:fauridoc/src/utils/open_status.dart';

/// Builds a full-week hours map: [openDay] uses [open]–[close],
/// every other day is closed.
Map<String, DayHours> singleDayHours(String openDay, String open, String close) {
  return {
    for (final key in weekdayKeys)
      key: key == openDay
          ? DayHours(open: open, close: close)
          : DayHours.closedDay(),
  };
}

void main() {
  group('computeOpenStatus', () {
    test('open during a same-day shift', () {
      // 2026-10-12 is a Monday.
      final hours = singleDayHours('mon', '09:00', '21:00');
      final status = computeOpenStatus(hours, DateTime(2026, 10, 12, 10, 0));
      expect(status.isOpen, isTrue);
      expect(status.transitionAt, '21:00');
    });

    test('closed before opening', () {
      final hours = singleDayHours('mon', '09:00', '21:00');
      final status = computeOpenStatus(hours, DateTime(2026, 10, 12, 7, 0));
      expect(status.isOpen, isFalse);
      expect(status.transitionAt, '09:00');
    });

    test('closed day reports the next opening', () {
      final hours = {
        for (final key in weekdayKeys)
          key: key == 'sun'
              ? DayHours.closedDay()
              : const DayHours(open: '09:00', close: '21:00'),
      };
      // 2026-10-18 is a Sunday.
      final status = computeOpenStatus(hours, DateTime(2026, 10, 18, 12, 0));
      expect(status.isOpen, isFalse);
      expect(status.transitionAt, '09:00');
    });

    test('overnight shift spans midnight', () {
      final hours = singleDayHours('mon', '20:00', '02:00');

      // Monday 23:00 — evening part of Monday's shift.
      var status = computeOpenStatus(hours, DateTime(2026, 10, 12, 23, 0));
      expect(status.isOpen, isTrue);
      expect(status.transitionAt, '02:00');

      // Tuesday 01:00 — early-morning part of Monday's overnight shift.
      status = computeOpenStatus(hours, DateTime(2026, 10, 13, 1, 0));
      expect(status.isOpen, isTrue);
      expect(status.transitionAt, '02:00');

      // Tuesday 03:00 — after the overnight shift ended.
      status = computeOpenStatus(hours, DateTime(2026, 10, 13, 3, 0));
      expect(status.isOpen, isFalse);
    });
  });

  group('formatTime12', () {
    test('converts 24h times to 12h', () {
      expect(formatTime12('17:00'), '5 PM');
      expect(formatTime12('09:30'), '9:30 AM');
      expect(formatTime12('00:00'), '12 AM');
    });
  });
}
