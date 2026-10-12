// Hand-rolled localization: English + Urdu (plain spoken Urdu, RTL).
// No codegen — add a key to both maps, then use `tr(ref, 'key')`.
//
// Screen teams own their own tables (strings_b/c/d.dart); they are merged
// into [translate] and [allKeys] below. Placeholders use {name} syntax;
// fill with [fill].
import 'strings_b.dart';
import 'strings_c.dart';
import 'strings_d.dart';
import 'strings_en.dart';
import 'strings_ur.dart';

/// Translate [key] for [locale] ('en' or 'ur'). Main tables take priority,
/// then the screen-team tables; falls back to English, then to the key.
String translate(String locale, String key) {
  final isUr = locale == 'ur';
  final main = isUr ? urStrings : enStrings;
  final hit = main[key] ??
      (isUr ? urB[key] : enB[key]) ??
      (isUr ? urC[key] : enC[key]) ??
      (isUr ? urD[key] : enD[key]);
  if (hit != null) return hit;
  return enStrings[key] ?? enB[key] ?? enC[key] ?? enD[key] ?? key;
}

/// True when [key] has a real translation for [locale] (no English fallback).
bool hasTranslation(String locale, String key) {
  final isUr = locale == 'ur';
  final main = isUr ? urStrings : enStrings;
  return main.containsKey(key) ||
      (isUr ? urB : enB).containsKey(key) ||
      (isUr ? urC : enC).containsKey(key) ||
      (isUr ? urD : enD).containsKey(key);
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
  'Medical Specialist (Internal Medicine)': 'میڈیکل اسپیشلسٹ',
  'Cardiologist': 'دل کا ڈاکٹر',
  'Interventional Cardiologist': 'انٹروینشنل کارڈیالوجسٹ',
  'Gastroenterologist': 'معدے کا ڈاکٹر',
  'Hepatologist': 'جگر کا ڈاکٹر',
  'Pulmonologist (Chest Specialist)': 'سینے کا ڈاکٹر',
  'Nephrologist': 'گردے کا ڈاکٹر',
  'Neurologist': 'دماغ اور اعصاب کا ڈاکٹر',
  'Endocrinologist / Diabetologist': 'شوگر کا ڈاکٹر',
  'Rheumatologist': 'جوڑوں کا ڈاکٹر',
  'Hematologist': 'خون کا ڈاکٹر',
  'Oncologist': 'کینسر کا ڈاکٹر',
  'Dermatologist': 'جلد کا ڈاکٹر',
  'Psychiatrist': 'نفسیاتی ڈاکٹر',
  'General Surgeon': 'جنرل سرجن',
  'Laparoscopic Surgeon': 'لیپروسکوپک سرجن',
  'Colorectal Surgeon': 'کولوریکٹل سرجن',
  'Orthopedic Surgeon': 'ہڈیوں کا ڈاکٹر',
  'Orthopedic': 'ہڈی جوڑ',
  'Neurosurgeon': 'نیوروسرجن',
  'Plastic Surgeon': 'پلاسٹک سرجن',
  'Urologist': 'یورالوجسٹ',
  'Pediatric Surgeon': 'بچوں کا سرجن',
  'Cardiac Surgeon': 'دل کا سرجن',
  'Gynecologist / Obstetrician': 'زنانہ امراض کی ڈاکٹر',
  'Gynecologist': 'گائنی',
  'Pediatrician (Child Specialist)': 'بچوں کا ڈاکٹر',
  'Pediatrician': 'بچوں کے ڈاکٹر',
  'Child Specialist': 'بچوں کے اسپیشلسٹ',
  'Neonatologist': 'نومولود بچوں کا ڈاکٹر',
  'ENT Specialist': 'ناک کان گلے کا ڈاکٹر',
  'Eye Specialist (Ophthalmologist)': 'آنکھوں کا ڈاکٹر',
  'Eye Specialist': 'آنکھوں کے ڈاکٹر',
  'Vitreoretinal Surgeon': 'وٹریوریٹینل سرجن',
  'Dentist': 'دانتوں کا ڈاکٹر',
  'Orthodontist': 'آرتھوڈانٹسٹ',
  'Psychologist': 'ماہر نفسیات',
  'Physiotherapist': 'فزیوتھراپسٹ',
  'Speech Therapist': 'اسپیچ تھراپسٹ',
  'Radiologist / Sonologist': 'ریڈیالوجسٹ',
  'Pathologist': 'پیتھالوجسٹ',
  'Nutritionist / Dietitian': 'غذائیت کا ماہر',
  'Anesthetist / Pain Specialist': 'بے ہوشی کا ڈاکٹر',
  'Family Physician': 'فیملی ڈاکٹر',
  'Emergency Medicine Specialist': 'ایمرجنسی ڈاکٹر',
};

/// All known l10n keys — used by the l10n completeness test.
Set<String> get allKeys => {
      ...enStrings.keys,
      ...urStrings.keys,
      ...enB.keys,
      ...urB.keys,
      ...enC.keys,
      ...urC.keys,
      ...enD.keys,
      ...urD.keys,
    };
