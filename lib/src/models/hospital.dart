import 'model_utils.dart';

/// A hospital listing.
class Hospital {
  final String id;
  final String name;
  final String city;
  final String address;
  final String phone;
  final String emergencyPhone;
  final double? lat;
  final double? lng;
  final List<String> departments;
  final String visitingHours;
  final String opdHours;
  final bool emergency247;
  final String? photoUrl;
  final bool verified;
  final bool approved;
  final double rating;
  final int reviewCount;
  final bool hasParking;
  final String? ownerUid;
  final DateTime createdAt;

  Hospital({
    required this.id,
    required this.name,
    required this.city,
    this.address = '',
    this.phone = '',
    this.emergencyPhone = '',
    this.lat,
    this.lng,
    this.departments = const [],
    this.visitingHours = '',
    this.opdHours = '',
    this.emergency247 = false,
    this.photoUrl,
    this.verified = false,
    this.approved = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.hasParking = false,
    this.ownerUid,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory Hospital.fromJson(Map<String, dynamic> json) => Hospital(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        emergencyPhone: (json['emergencyPhone'] as String?) ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        departments:
            (json['departments'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        visitingHours: (json['visitingHours'] as String?) ?? '',
        opdHours: (json['opdHours'] as String?) ?? '',
        emergency247: (json['emergency247'] as bool?) ?? false,
        photoUrl: json['photoUrl'] as String?,
        verified: (json['verified'] as bool?) ?? false,
        approved: (json['approved'] as bool?) ?? false,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        hasParking: (json['hasParking'] as bool?) ?? false,
        ownerUid: json['ownerUid'] as String?,
        createdAt: parseDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'address': address,
        'phone': phone,
        'emergencyPhone': emergencyPhone,
        'lat': lat,
        'lng': lng,
        'departments': departments,
        'visitingHours': visitingHours,
        'opdHours': opdHours,
        'emergency247': emergency247,
        'photoUrl': photoUrl,
        'verified': verified,
        'approved': approved,
        'rating': rating,
        'reviewCount': reviewCount,
        'hasParking': hasParking,
        'ownerUid': ownerUid,
        'createdAt': createdAt.toIso8601String(),
      };

  Hospital copyWith({
    String? name,
    String? city,
    String? address,
    String? phone,
    String? emergencyPhone,
    double? lat,
    double? lng,
    List<String>? departments,
    String? visitingHours,
    String? opdHours,
    bool? emergency247,
    String? photoUrl,
    bool? verified,
    bool? approved,
    double? rating,
    int? reviewCount,
    bool? hasParking,
    String? ownerUid,
  }) =>
      Hospital(
        id: id,
        name: name ?? this.name,
        city: city ?? this.city,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        emergencyPhone: emergencyPhone ?? this.emergencyPhone,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        departments: departments ?? this.departments,
        visitingHours: visitingHours ?? this.visitingHours,
        opdHours: opdHours ?? this.opdHours,
        emergency247: emergency247 ?? this.emergency247,
        photoUrl: photoUrl ?? this.photoUrl,
        verified: verified ?? this.verified,
        approved: approved ?? this.approved,
        rating: rating ?? this.rating,
        reviewCount: reviewCount ?? this.reviewCount,
        hasParking: hasParking ?? this.hasParking,
        ownerUid: ownerUid ?? this.ownerUid,
        createdAt: createdAt,
      );
}
