import '../models/app_user.dart';
import '../models/community.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../models/review.dart';

/// Sort options for the search screen.
enum EntitySort { rating, mostReviewed, newest }

/// Thrown when a user tries to review the same doctor twice.
class DuplicateReviewException implements Exception {
  final String message;
  const DuplicateReviewException([this.message = 'You have already reviewed this doctor.']);
  @override
  String toString() => 'DuplicateReviewException: $message';
}

/// Data layer contract. Two implementations:
/// - [DemoRepository]: in-memory + SharedPreferences (no Firebase configured).
/// - [FirestoreRepository]: Cloud Firestore (used when Firebase init succeeds).
///
/// Public list streams return ONLY approved entities. Pending registrations
/// are exposed through the watchPending* streams (admin only).
abstract class FauridocRepository {
  /// True when running without Firebase (demo mode).
  bool get isDemo;

  // ---------- doctors ----------
  Stream<List<Doctor>> watchDoctors({String? city, String? specialty, String? query});
  Future<Doctor?> getDoctor(String id);
  Future<String> registerDoctor(Doctor doctor); // creates as pending (approved=false)
  Future<void> updateDoctor(Doctor doctor);
  Future<void> deleteDoctor(String id);
  Future<void> approveDoctor(String id, {required bool approve});
  Stream<List<Doctor>> watchPendingDoctors();

  // ---------- labs ----------
  Stream<List<Lab>> watchLabs({String? city, String? query, String? testQuery});
  Future<Lab?> getLab(String id);
  Future<String> registerLab(Lab lab);
  Future<void> updateLab(Lab lab);
  Future<void> deleteLab(String id);
  Future<void> approveLab(String id, {required bool approve});
  Stream<List<Lab>> watchPendingLabs();

  // ---------- hospitals ----------
  Stream<List<Hospital>> watchHospitals({String? city, String? query});
  Future<Hospital?> getHospital(String id);
  Future<String> registerHospital(Hospital hospital);
  Future<void> updateHospital(Hospital hospital);
  Future<void> deleteHospital(String id);
  Future<void> approveHospital(String id, {required bool approve});
  Stream<List<Hospital>> watchPendingHospitals();

  // ---------- reviews ----------
  Stream<List<Review>> watchReviews(String doctorId);

  /// All reviews written by [uid] across doctors, newest first.
  Stream<List<Review>> watchReviewsByUser(String uid);

  /// Throws [DuplicateReviewException] when this user already reviewed the doctor.
  Future<void> addReview(Review review);
  Future<void> deleteReview(String doctorId, String reviewId);

  // ---------- community ----------
  Stream<List<CommunityQuestion>> watchQuestions({String? city, String? specialty, String? query});
  Future<CommunityQuestion?> getQuestion(String id);
  Stream<List<CommunityReply>> watchReplies(String questionId);
  Future<String> askQuestion(CommunityQuestion question);
  Future<String> addReply(CommunityReply reply);
  Future<void> voteQuestion(String questionId, String uid, int delta); // +1 or -1, toggles
  Future<void> voteReply(String questionId, String replyId, String uid, int delta);
  Future<void> pinQuestion(String questionId, bool pinned);
  Future<void> deleteQuestion(String questionId);
  Future<void> deleteReply(String questionId, String replyId);

  // ---------- doctor stats ----------
  Future<void> recordProfileView(String doctorId);
  Future<void> recordWhatsappClick(String doctorId);
  Future<Map<String, int>> getWeeklyStats(String doctorId); // {'views': n, 'whatsapp': n}

  // ---------- config lists (admin-editable) ----------
  Stream<List<String>> watchCities();
  Stream<List<String>> watchSpecialties();
  Stream<List<String>> watchTestCategories();
  Future<void> setCities(List<String> cities);
  Future<void> setSpecialties(List<String> specialties);
  Future<void> setTestCategories(List<String> categories);

  // ---------- admin ----------
  Stream<AdminCounts> watchAdminCounts();

  // ---------- entities owned by a user (their registrations) ----------
  Stream<List<Doctor>> watchMyDoctors(String uid);
  Stream<List<Lab>> watchMyLabs(String uid);
  Stream<List<Hospital>> watchMyHospitals(String uid);

  // ---------- photos ----------
  /// Uploads a photo and returns a URL (or local path in demo mode).
  Future<String> uploadPhoto(String entityKind, String entityId, String localPath);

  // ---------- users ----------
  Future<void> upsertUser(AppUser user);
  Stream<AppUser?> watchUser(String uid);
}
