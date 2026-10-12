import 'day_hours.dart';
import 'model_utils.dart';

/// One test offered by a lab, with its price in PKR.
class LabTestPrice {
  final String test;
  final String category;
  final int price;

  const LabTestPrice({required this.test, required this.category, required this.price});

  factory LabTestPrice.fromJson(Map<String, dynamic> json) => LabTestPrice(
        test: (json['test'] as String?) ?? '',
        category: (json['category'] as String?) ?? '',
        price: (json['price'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'test': test, 'category': category, 'price': price};
}

/// A diagnostic lab listing.
class Lab {
  final String id;
  final String name;
  final String city;
  final String address;
  final String phone;
  final double? lat;
  final double? lng;
  final Map<String, DayHours> hours;
  final String hoursText; // display text, e.g. "Mon–Sat 8 AM – 10 PM"
  final String? photoUrl;
  final bool verified;
  final bool approved;
  final double rating;
  final int reviewCount;
  final bool hasParking;
  final List<LabTestPrice> tests;
  final String? ownerUid;
  final DateTime createdAt;

  Lab({
    required this.id,
    required this.name,
    required this.city,
    this.address = '',
    this.phone = '',
    this.lat,
    this.lng,
    Map<String, DayHours>? hours,
    this.hoursText = '',
    this.photoUrl,
    this.verified = false,
    this.approved = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.hasParking = false,
    this.tests = const [],
    this.ownerUid,
    DateTime? createdAt,
  })  : hours = hours ?? const {},
        createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Price of a specific test, or null if this lab doesn't offer it.
  int? priceFor(String testName) {
    final t = testName.trim().toLowerCase();
    for (final tp in tests) {
      if (tp.test.trim().toLowerCase() == t) return tp.price;
    }
    return null;
  }

  factory Lab.fromJson(Map<String, dynamic> json) => Lab(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        hours: hoursFromJson(json['hours'] as Map<String, dynamic>?),
        hoursText: (json['hoursText'] as String?) ?? '',
        photoUrl: json['photoUrl'] as String?,
        verified: (json['verified'] as bool?) ?? false,
        approved: (json['approved'] as bool?) ?? false,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        hasParking: (json['hasParking'] as bool?) ?? false,
        tests: (json['tests'] as List?)
                ?.map((e) => LabTestPrice.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        ownerUid: json['ownerUid'] as String?,
        createdAt: parseDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'address': address,
        'phone': phone,
        'lat': lat,
        'lng': lng,
        'hours': hoursToJson(hours),
        'hoursText': hoursText,
        'photoUrl': photoUrl,
        'verified': verified,
        'approved': approved,
        'rating': rating,
        'reviewCount': reviewCount,
        'hasParking': hasParking,
        'tests': tests.map((t) => t.toJson()).toList(),
        'ownerUid': ownerUid,
        'createdAt': createdAt.toIso8601String(),
      };

  Lab copyWith({
    String? name,
    String? city,
    String? address,
    String? phone,
    double? lat,
    double? lng,
    Map<String, DayHours>? hours,
    String? hoursText,
    String? photoUrl,
    bool? verified,
    bool? approved,
    double? rating,
    int? reviewCount,
    bool? hasParking,
    List<LabTestPrice>? tests,
    String? ownerUid,
  }) =>
      Lab(
        id: id,
        name: name ?? this.name,
        city: city ?? this.city,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        hours: hours ?? this.hours,
        hoursText: hoursText ?? this.hoursText,
        photoUrl: photoUrl ?? this.photoUrl,
        verified: verified ?? this.verified,
        approved: approved ?? this.approved,
        rating: rating ?? this.rating,
        reviewCount: reviewCount ?? this.reviewCount,
        hasParking: hasParking ?? this.hasParking,
        tests: tests ?? this.tests,
        ownerUid: ownerUid ?? this.ownerUid,
        createdAt: createdAt,
      );
}
