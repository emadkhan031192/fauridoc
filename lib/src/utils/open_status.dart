import '../models/day_hours.dart';

/// Result of the live open/closed computation for a doctor or lab.
class OpenStatus {
  /// True when open right now.
  final bool isOpen;

  /// "HH:MM" (24h) of the next transition: closing time when open,
  /// opening time when closed. Null when unknown (e.g. closed all week).
  final String? transitionAt;

  const OpenStatus({required this.isOpen, this.transitionAt});
}

int _toMinutes(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

/// Computes whether an entity is open at [now] from its weekly [hours].
///
/// Handles:
/// - normal same-day shifts (09:00–21:00)
/// - overnight shifts (20:00–02:00): early-morning hours count as part of
///   the previous day's shift
/// - fully closed days
OpenStatus computeOpenStatus(Map<String, DayHours> hours, DateTime now) {
  final todayIdx = now.weekday - 1; // Monday = 0
  final todayKey = weekdayKeys[todayIdx];
  final today = hours[todayKey];
  final nowMin = now.hour * 60 + now.minute;

  bool openNow = false;
  String? transition;

  if (today != null && !today.closed) {
    final o = _toMinutes(today.open);
    final c = _toMinutes(today.close);
    if (c > o) {
      // same-day shift
      if (nowMin >= o && nowMin < c) {
        openNow = true;
        transition = today.close;
      } else if (nowMin < o) {
        transition = today.open;
      }
    } else if (c < o) {
      // overnight shift starting today: open from o tonight until c tomorrow
      if (nowMin >= o) {
        openNow = true;
        transition = today.close;
      } else {
        transition = today.open;
      }
    }
    // c == o (and not closed) is treated as closed all day.
  }

  // Early-morning part of yesterday's overnight shift.
  if (!openNow) {
    final yIdx = (todayIdx + 6) % 7;
    final yKey = weekdayKeys[yIdx];
    final y = hours[yKey];
    if (y != null && !y.closed) {
      final o = _toMinutes(y.open);
      final c = _toMinutes(y.close);
      if (c < o && nowMin < c) {
        openNow = true;
        transition = y.close;
      }
    }
  }

  // When closed now and no transition found today, look ahead up to 7 days.
  if (!openNow && transition == null) {
    for (var d = 1; d <= 7; d++) {
      final key = weekdayKeys[(todayIdx + d) % 7];
      final h = hours[key];
      if (h != null && !h.closed) {
        transition = h.open;
        break;
      }
    }
  }
  return OpenStatus(isOpen: openNow, transitionAt: transition);
}

/// "17:00" -> "5 PM", "09:30" -> "9:30 AM" for the status line.
String formatTime12(String hhmm) {
  final parts = hhmm.split(':');
  var h = int.tryParse(parts[0]) ?? 0;
  final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  final suffix = h >= 12 ? 'PM' : 'AM';
  h = h % 12;
  if (h == 0) h = 12;
  return m == 0 ? '$h $suffix' : '$h:${m.toString().padLeft(2, '0')} $suffix';
}
