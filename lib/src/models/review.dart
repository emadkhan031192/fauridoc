import 'model_utils.dart';

/// A patient review of a doctor. One per user per doctor (enforced by repo).
class Review {
  final String id;
  final String doctorId;
  final String userId;
  final String userName;
  final int rating; // 1..5
  final String text;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.doctorId,
    required this.userId,
    required this.userName,
    required this.rating,
    this.text = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        doctorId: (json['doctorId'] as String?) ?? '',
        userId: (json['userId'] as String?) ?? '',
        userName: (json['userName'] as String?) ?? '',
        rating: (json['rating'] as num?)?.toInt() ?? 5,
        text: (json['text'] as String?) ?? '',
        createdAt: parseDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'doctorId': doctorId,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };
}
