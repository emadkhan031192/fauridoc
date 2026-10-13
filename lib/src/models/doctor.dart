import 'day_hours.dart';
import 'model_utils.dart';

/// A doctor listing.
class Doctor {
  final String id;
  final String name;
  final String nameUr;
  final String specialty;
  final String city;
  final String qualification;
  final String clinicName;
  final String address;
  final String phone;
  final String whatsapp;
  final double? lat;
  final double? lng;
  final Map<String, DayHours> hours;
  final List<String> languages;
  final String hoursText; // display text, e.g. "Mon–Fri 5–8 PM"
  final String? photoUrl; // network URL or local file path
  final List<String> clinicPhotos; // up to 3
  final bool verified;
  final bool approved;
  final double rating;
  final int reviewCount;
  final String? leaveTill; // display text, e.g. "10 Aug"
  final bool hasParking;
  final int? fee; // consultation fee in PKR
  final String? ownerUid;
  final DateTime createdAt;
  final bool pinned; // admin pin: pinned doctors sort first

  Doctor({
    required this.id,
    required this.name,
    this.nameUr = '',
    required this.specialty,
    required this.city,
    this.qualification = '',
    this.clinicName = '',
    this.address = '',
    this.phone = '',
    this.whatsapp = '',
    this.lat,
    this.lng,
    Map<String, DayHours>? hours,
    this.languages = const [],
    this.hoursText = '',
    this.photoUrl,
    this.clinicPhotos = const [],
    this.verified = false,
    this.approved = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.leaveTill,
    this.hasParking = false,
    this.fee,
    this.ownerUid,
    this.pinned = false,
    DateTime? createdAt,
  })  : hours = hours ?? const {},
        createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        nameUr: (json['nameUr'] as String?) ?? '',
        specialty: (json['specialty'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        qualification: (json['qualification'] as String?) ?? '',
        clinicName: (json['clinicName'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        whatsapp: (json['whatsapp'] as String?) ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        hours: hoursFromJson(json['hours'] as Map<String, dynamic>?),
        languages: (json['languages'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        hoursText: (json['hoursText'] as String?) ?? '',
        photoUrl: json['photoUrl'] as String?,
        clinicPhotos:
            (json['clinicPhotos'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        verified: (json['verified'] as bool?) ?? false,
        approved: (json['approved'] as bool?) ?? false,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        leaveTill: json['leaveTill'] as String?,
        hasParking: (json['hasParking'] as bool?) ?? false,
        fee: (json['fee'] as num?)?.toInt(),
        ownerUid: json['ownerUid'] as String?,
        pinned: (json['pinned'] as bool?) ?? false,
        createdAt: parseDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameUr': nameUr,
        'specialty': specialty,
        'city': city,
        'qualification': qualification,
        'clinicName': clinicName,
        'address': address,
        'phone': phone,
        'whatsapp': whatsapp,
        'lat': lat,
        'lng': lng,
        'hours': hoursToJson(hours),
        'languages': languages,
        'hoursText': hoursText,
        'photoUrl': photoUrl,
        'clinicPhotos': clinicPhotos,
        'verified': verified,
        'approved': approved,
        'rating': rating,
        'reviewCount': reviewCount,
        'leaveTill': leaveTill,
        'hasParking': hasParking,
        'fee': fee,
        'ownerUid': ownerUid,
        'pinned': pinned,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Display name in the requested language, falling back to English
  /// when the Urdu name is absent.
  String displayName(bool ur) => ur && nameUr.isNotEmpty ? nameUr : name;

  Doctor copyWith({
    String? name,
    String? specialty,
    String? city,
    String? qualification,
    String? clinicName,
    String? address,
    String? phone,
    String? whatsapp,
    double? lat,
    double? lng,
    Map<String, DayHours>? hours,
    List<String>? languages,
    String? hoursText,
    String? photoUrl,
    List<String>? clinicPhotos,
    bool? verified,
    bool? approved,
    double? rating,
    int? reviewCount,
    String? leaveTill,
    bool? hasParking,
    int? fee,
    String? ownerUid,
    bool? pinned,
  }) =>
      Doctor(
        id: id,
        name: name ?? this.name,
        specialty: specialty ?? this.specialty,
        city: city ?? this.city,
        qualification: qualification ?? this.qualification,
        clinicName: clinicName ?? this.clinicName,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        whatsapp: whatsapp ?? this.whatsapp,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        hours: hours ?? this.hours,
        languages: languages ?? this.languages,
        hoursText: hoursText ?? this.hoursText,
        photoUrl: photoUrl ?? this.photoUrl,
        clinicPhotos: clinicPhotos ?? this.clinicPhotos,
        verified: verified ?? this.verified,
        approved: approved ?? this.approved,
        rating: rating ?? this.rating,
        reviewCount: reviewCount ?? this.reviewCount,
        leaveTill: leaveTill ?? this.leaveTill,
        hasParking: hasParking ?? this.hasParking,
        fee: fee ?? this.fee,
        ownerUid: ownerUid ?? this.ownerUid,
        pinned: pinned ?? this.pinned,
        createdAt: createdAt,
      );
}
