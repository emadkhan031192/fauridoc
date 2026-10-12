/// The signed-in user (Firebase Auth user mapped in, or a demo-mode profile).
class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final bool isAdmin;
  final bool isDoctor;
  final String? doctorId; // linked doctor profile, if any

  const AppUser({
    required this.uid,
    required this.name,
    this.phone = '',
    this.email = '',
    this.isAdmin = false,
    this.isDoctor = false,
    this.doctorId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        name: (json['name'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        isAdmin: (json['isAdmin'] as bool?) ?? false,
        isDoctor: (json['isDoctor'] as bool?) ?? false,
        doctorId: json['doctorId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'phone': phone,
        'email': email,
        'isAdmin': isAdmin,
        'isDoctor': isDoctor,
        'doctorId': doctorId,
      };

  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    bool? isAdmin,
    bool? isDoctor,
    String? doctorId,
  }) =>
      AppUser(
        uid: uid,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        isAdmin: isAdmin ?? this.isAdmin,
        isDoctor: isDoctor ?? this.isDoctor,
        doctorId: doctorId ?? this.doctorId,
      );
}

/// Live counts for the admin dashboard.
class AdminCounts {
  final int doctors;
  final int labs;
  final int hospitals;
  final int pending;
  final int users;
  final int reviews;

  const AdminCounts({
    this.doctors = 0,
    this.labs = 0,
    this.hospitals = 0,
    this.pending = 0,
    this.users = 0,
    this.reviews = 0,
  });
}
