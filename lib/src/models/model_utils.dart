/// Shared helpers for model JSON parsing.
DateTime parseDate(dynamic v) {
  if (v is String) {
    return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String newId(String prefix) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch}';
