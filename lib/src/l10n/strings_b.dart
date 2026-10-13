import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'strings.dart';

/// Screen-B string tables: splash, onboarding, home, search, emergency.
/// Owned by the screens agent — do not edit from elsewhere.
/// [trB] checks these tables first, then falls back to [translate].
const Map<String, String> enB = {
  'splash.tagline': 'Doctor, lab, hospital. Instantly.',
  'splash.taglineUr': 'ڈاکٹر، لیب، ہسپتال — فوراً',
  'splash.madeFor': 'Made for Khyber Pakhtunkhwa',
  'splash.byLine': 'An App by Afzal Digital Lab',

  'onb.skip': 'Skip',
  'onb.title': 'Find a verified doctor',
  'onb.body':
      'Every doctor is checked by our team before they appear. Pick by specialty, city and real patient ratings.',
  'onb.next': 'Next',

  'home.title': 'Find a doctor\nyou can trust.',
  'home.nearestEmergency': 'Nearest hospital emergency',
  'home.open247': 'Open 24/7',
  'home.searchHint': 'Search doctors, lab tests, hospitals',
  'home.all': 'All',
  'home.topRatedNearYou': 'Top rated near you',
  'home.openNowUntil': 'Open now · until {time}',
  'home.closedOpensAt': 'Closed · opens {time}',
  'home.closed': 'Closed',
  'home.onLeaveTill': 'On leave till {date}',
  'home.viewProfile': 'View profile',
  'home.call': 'Call',
  'home.moreDoctorsIn': 'More doctors in {city}',
  'home.topRated': 'Top rated',
  'home.new': 'New',
  'home.fee': 'Fee',
  'home.distance': 'Distance',
  'home.reviews': 'Reviews',
  'home.noDoctors': 'No doctors in {city} yet.',
  'home.chooseCity': 'Choose city',
  'home.dayMon': 'Mon',
  'home.dayTue': 'Tue',
  'home.dayWed': 'Wed',
  'home.dayThu': 'Thu',
  'home.dayFri': 'Fri',
  'home.daySat': 'Sat',
  'home.daySun': 'Sun',

  'search.title': 'Search',
  'search.hint': 'Search by name or keyword',
  'search.doctors': 'Doctors',
  'search.labTests': 'Lab Tests',
  'search.hospitals': 'Hospitals',
  'search.allSpecialties': 'All specialties',
  'search.within5km': 'Within 5 km',
  'search.doctorsIn': '{count} doctors in {city}',
  'search.labsIn': '{count} labs in {city}',
  'search.hospitalsIn': '{count} hospitals in {city}',
  'search.callNow': 'Call now',
  'search.noResults': 'No results found',
  'search.testsFrom': '{count} tests · from Rs {price}',
  'search.emergency247': 'Emergency 24/7',
  'search.private': 'Private',
  'search.govt': 'Govt',
  'search.locationNeeded':
      'Location permission is needed to measure distance',

  'emg.title': 'Nearest emergency',
  'emg.aboutMin': 'about {n} min',
  'emg.emergencyOpen247': 'Emergency open 24/7',
  'emg.callEmergency': 'Call emergency · {phone}',
  'emg.directions': 'Directions',
  'emg.shareLocation': 'Share location',
  'emg.locationCopied': 'Location link copied to clipboard',
  'emg.ambulanceTitle': 'Need an ambulance? Call Rescue 1122',
  'emg.ambulanceBody':
      'Fauridoc does not send ambulances. For a life-threatening emergency, call first.',
  'emg.otherWards': 'Other emergency wards nearby',
  'emg.noHospital': 'No hospital listed in {city} yet.',
};

const Map<String, String> urB = {
  'splash.tagline': 'ڈاکٹر، لیب، ہسپتال۔ فوراً۔',
  'splash.taglineUr': 'ڈاکٹر، لیب، ہسپتال — فوراً',
  'splash.madeFor': 'خیبر پختونخوا کے لیے بنایا گیا',
  'splash.byLine': 'افضل ڈیجیٹل لیب کی ایک ایپ',

  'onb.skip': 'چھوڑیں',
  'onb.title': 'تصدیق شدہ ڈاکٹر تلاش کریں',
  'onb.body':
      'ہر ڈاکٹر ہماری ٹیم کی جانچ کے بعد یہاں نظر آتا ہے۔ اسپیشلٹی، شہر اور مریضوں کی اصل ریٹنگ سے انتخاب کریں۔',
  'onb.next': 'آگے',

  'home.title': 'اپنے بھروسے کا\nڈاکٹر ڈھونڈیں',
  'home.nearestEmergency': 'قریبی ہسپتال ایمرجنسی',
  'home.open247': '24/7 کھلا',
  'home.searchHint': 'ڈاکٹر، ٹیسٹ، ہسپتال تلاش کریں',
  'home.all': 'سب',
  'home.topRatedNearYou': 'آپ کے قریب سب سے اچھے',
  'home.openNowUntil': 'ابھی کھلا ہے · {time} تک',
  'home.closedOpensAt': 'بند ہے · {time} کھلے گا',
  'home.closed': 'بند ہے',
  'home.onLeaveTill': 'چھٹی پر · {date} تک',
  'home.viewProfile': 'پروفائل دیکھیں',
  'home.call': 'کال کریں',
  'home.moreDoctorsIn': '{city} میں مزید ڈاکٹر',
  'home.topRated': 'سب سے اچھے',
  'home.new': 'نیا',
  'home.fee': 'فیس',
  'home.distance': 'فاصلہ',
  'home.reviews': 'ریویوز',
  'home.noDoctors': '{city} میں ابھی کوئی ڈاکٹر نہیں۔',
  'home.chooseCity': 'شہر منتخب کریں',
  'home.dayMon': 'پیر',
  'home.dayTue': 'منگل',
  'home.dayWed': 'بدھ',
  'home.dayThu': 'جمعرات',
  'home.dayFri': 'جمعہ',
  'home.daySat': 'ہفتہ',
  'home.daySun': 'اتوار',

  'search.title': 'تلاش',
  'search.hint': 'نام یا لفظ سے تلاش کریں',
  'search.doctors': 'ڈاکٹرز',
  'search.labTests': 'لیب ٹیسٹ',
  'search.hospitals': 'ہسپتال',
  'search.allSpecialties': 'تمام اسپیشلٹیز',
  'search.within5km': '5 کلومیٹر کے اندر',
  'search.doctorsIn': '{city} میں {count} ڈاکٹر',
  'search.labsIn': '{city} میں {count} لیبز',
  'search.hospitalsIn': '{city} میں {count} ہسپتال',
  'search.callNow': 'ابھی کال کریں',
  'search.noResults': 'کوئی نتیجہ نہیں ملا',
  'search.testsFrom': '{count} ٹیسٹ · Rs {price} سے',
  'search.emergency247': 'ایمرجنسی 24/7',
  'search.private': 'نجی',
  'search.govt': 'سرکاری',
  'search.locationNeeded': 'فاصلے کے لیے لوکیشن کی اجازت درکار ہے',

  'emg.title': 'قریبی ایمرجنسی',
  'emg.aboutMin': 'تقریباً {n} منٹ',
  'emg.emergencyOpen247': 'ایمرجنسی 24/7 کھلی ہے',
  'emg.callEmergency': 'ایمرجنسی کال · {phone}',
  'emg.directions': 'راستہ دیکھیں',
  'emg.shareLocation': 'لوکیشن بھیجیں',
  'emg.locationCopied': 'لوکیشن لنک کاپی ہو گیا',
  'emg.ambulanceTitle': 'ایمبولینس چاہیے؟ ریسکیو 1122 پر کال کریں',
  'emg.ambulanceBody':
      'فوریڈاک ایمبولینس نہیں بھیجتا۔ جان لیوا ایمرجنسی میں پہلے کال کریں۔',
  'emg.otherWards': 'قریب دیگر ایمرجنسی وارڈز',
  'emg.noHospital': '{city} میں ابھی کوئی ہسپتال درج نہیں۔',
};

/// Translate [key] for the current locale: screen-B tables first,
/// then the shared [translate] tables.
String trB(WidgetRef ref, String key) {
  final locale = ref.watch(localeProvider);
  final map = locale == 'ur' ? urB : enB;
  return map[key] ?? translate(locale, key);
}
