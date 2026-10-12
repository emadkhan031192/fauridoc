import 'model_utils.dart';

/// A community question, tagged by city + specialty.
class CommunityQuestion {
  final String id;
  final String title;
  final String body;
  final String city;
  final String specialty;
  final String userId;
  final String userName;
  final bool isDoctor;
  final bool pinned;
  final int upvotes;
  final int downvotes;
  final Map<String, int> votes; // uid -> +1 / -1
  final DateTime createdAt;

  CommunityQuestion({
    required this.id,
    required this.title,
    this.body = '',
    this.city = '',
    this.specialty = '',
    required this.userId,
    required this.userName,
    this.isDoctor = false,
    this.pinned = false,
    this.upvotes = 0,
    this.downvotes = 0,
    this.votes = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  int get score => upvotes - downvotes;

  factory CommunityQuestion.fromJson(Map<String, dynamic> json) => CommunityQuestion(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        city: (json['city'] as String?) ?? '',
        specialty: (json['specialty'] as String?) ?? '',
        userId: (json['userId'] as String?) ?? '',
        userName: (json['userName'] as String?) ?? '',
        isDoctor: (json['isDoctor'] as bool?) ?? false,
        pinned: (json['pinned'] as bool?) ?? false,
        upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
        downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
        votes: (json['votes'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
            const {},
        createdAt: parseDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'city': city,
        'specialty': specialty,
        'userId': userId,
        'userName': userName,
        'isDoctor': isDoctor,
        'pinned': pinned,
        'upvotes': upvotes,
        'downvotes': downvotes,
        'votes': votes,
        'createdAt': createdAt.toIso8601String(),
      };

  CommunityQuestion copyWith({
    String? title,
    String? body,
    String? city,
    String? specialty,
    bool? pinned,
    int? upvotes,
    int? downvotes,
    Map<String, int>? votes,
  }) =>
      CommunityQuestion(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        city: city ?? this.city,
        specialty: specialty ?? this.specialty,
        userId: userId,
        userName: userName,
        isDoctor: isDoctor,
        pinned: pinned ?? this.pinned,
        upvotes: upvotes ?? this.upvotes,
        downvotes: downvotes ?? this.downvotes,
        votes: votes ?? this.votes,
        createdAt: createdAt,
      );
}

/// A reply to a community question. Doctor replies carry a "Doctor" badge.
class CommunityReply {
  final String id;
  final String questionId;
  final String body;
  final String userId;
  final String userName;
  final bool isDoctor;
  final int upvotes;
  final int downvotes;
  final Map<String, int> votes;
  final DateTime createdAt;

  CommunityReply({
    required this.id,
    required this.questionId,
    required this.body,
    required this.userId,
    required this.userName,
    this.isDoctor = false,
    this.upvotes = 0,
    this.downvotes = 0,
    this.votes = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  int get score => upvotes - downvotes;

  factory CommunityReply.fromJson(Map<String, dynamic> json) => CommunityReply(
        id: json['id'] as String,
        questionId: (json['questionId'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        userId: (json['userId'] as String?) ?? '',
        userName: (json['userName'] as String?) ?? '',
        isDoctor: (json['isDoctor'] as bool?) ?? false,
        upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
        downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
        votes: (json['votes'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ??
            const {},
        createdAt: parseDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'questionId': questionId,
        'body': body,
        'userId': userId,
        'userName': userName,
        'isDoctor': isDoctor,
        'upvotes': upvotes,
        'downvotes': downvotes,
        'votes': votes,
        'createdAt': createdAt.toIso8601String(),
      };

  CommunityReply copyWith({int? upvotes, int? downvotes, Map<String, int>? votes}) =>
      CommunityReply(
        id: id,
        questionId: questionId,
        body: body,
        userId: userId,
        userName: userName,
        isDoctor: isDoctor,
        upvotes: upvotes ?? this.upvotes,
        downvotes: downvotes ?? this.downvotes,
        votes: votes ?? this.votes,
        createdAt: createdAt,
      );
}
