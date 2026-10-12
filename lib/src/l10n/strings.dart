// Hand-rolled localization: English + Urdu (plain spoken Urdu, RTL).
// No codegen — add a key to both maps, then use `tr(ref, 'key')`.
//
// Placeholders use {name} syntax; fill with [fill].
import 'strings_en.dart';
import 'strings_ur.dart';

/// Translate [key] for [locale] ('en' or 'ur'). Falls back to English,
/// then to the key itself.
String translate(String locale, String key) {
  final map = locale == 'ur' ? urStrings : enStrings;
  return map[key] ?? enStrings[key] ?? key;
}

/// Replace {placeholders} in [template] with [values].
String fill(String template, Map<String, String> values) {
  var out = template;
  values.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

/// Specialty names in the current locale (proper nouns stay readable).
String specialtyLabel(String locale, String specialty) {
  if (locale != 'ur') return specialty;
  return _specialtyUr[specialty] ?? specialty;
}

const Map<String, String> _specialtyUr = {
  'General Physician': 'جنرل فزیشن',
  'Cardiologist': 'امراضِ قلب',
  'Dermatologist': 'امراضِ جلد',
  'Gynecologist': 'گائنی',
  'Pediatrician': 'بچوں کے ڈاکٹر',
  'ENT Specialist': 'ناک کان گلہ',
  'Orthopedic': 'ہڈی جوڑ',
  'Eye Specialist': 'آنکھوں کے ڈاکٹر',
  'Dentist': 'دانتوں کے ڈاکٹر',
  'Psychiatrist': 'نفسیاتی امراض',
  'Neurologist': 'امراضِ دماغ و اعصاب',
  'Urologist': 'امراضِ گردہ و مثانہ',
  'General Surgeon': 'جنرل سرجن',
  'Child Specialist': 'بچوں کے اسپیشلسٹ',
};

/// All known l10n keys — used by the l10n completeness test.
Set<String> get allKeys => {...enStrings.keys, ...urStrings.keys};
