/// Opening hours for a single weekday, stored as 24h "HH:MM" strings.
/// Supports overnight shifts (e.g. open "20:00", close "02:00").
class DayHours {
  final String open; // "17:00"
  final String close; // "21:00"
  final bool closed; // whole day closed

  const DayHours({required this.open, required this.close, this.closed = false});

  factory DayHours.closedDay() => const DayHours(open: '00:00', close: '00:00', closed: true);

  factory DayHours.fromJson(Map<String, dynamic> json) => DayHours(
        open: (json['open'] as String?) ?? '09:00',
        close: (json['close'] as String?) ?? '17:00',
        closed: (json['closed'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {'open': open, 'close': close, 'closed': closed};

  DayHours copyWith({String? open, String? close, bool? closed}) => DayHours(
        open: open ?? this.open,
        close: close ?? this.close,
        closed: closed ?? this.closed,
      );
}

/// Weekday keys used in hours maps: mon..sun.
const List<String> weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Default clinic hours: Mon–Sat 09:00–13:00 & 17:00–21:00 is NOT
/// representable here (single shift per day), so we use 09:00–21:00
/// Mon–Sat and closed Sunday. Entities can edit afterwards.
Map<String, DayHours> defaultHours() => {
      'mon': const DayHours(open: '09:00', close: '21:00'),
      'tue': const DayHours(open: '09:00', close: '21:00'),
      'wed': const DayHours(open: '09:00', close: '21:00'),
      'thu': const DayHours(open: '09:00', close: '21:00'),
      'fri': const DayHours(open: '09:00', close: '21:00'),
      'sat': const DayHours(open: '09:00', close: '17:00'),
      'sun': DayHours.closedDay(),
    };

Map<String, DayHours> hoursFromJson(Map<String, dynamic>? json) {
  final out = <String, DayHours>{};
  for (final k in weekdayKeys) {
    final v = json?[k];
    out[k] = v is Map<String, dynamic> ? DayHours.fromJson(v) : DayHours.closedDay();
  }
  return out;
}

Map<String, dynamic> hoursToJson(Map<String, DayHours> hours) =>
    {for (final k in weekdayKeys) k: (hours[k] ?? DayHours.closedDay()).toJson()};
