// Cloud Firestore implementation of [FauridocRepository].
//
// Used when Firebase init succeeds. Public list streams query on
// `approved == true` and apply city/specialty/text filters client-side
// (avoids composite indexes). Created-at ordering is also client-side
// because `createdAt` is stored as an ISO-8601 string.
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_user.dart';
import '../models/community.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../models/model_utils.dart';
import '../models/review.dart';
import 'repository.dart';
import 'seed_loader.dart';

/// Fallback config lists, kept in sync with seeds.dart defaults.
const List<String> _fallbackCities = [
  'Mardan',
  'Peshawar',
  'Abbottabad',
  'Swabi',
  'Nowshera',
  'Charsadda',
  'Kohat',
  'D.I. Khan',
  'Bannu',
  'Mansehra',
];

const List<String> _fallbackSpecialties = [
  'General Physician',
  'Cardiologist',
  'Dermatologist',
  'Gynecologist',
  'Pediatrician',
  'ENT Specialist',
  'Orthopedic',
  'Eye Specialist',
  'Dentist',
  'Psychiatrist',
  'Neurologist',
  'Urologist',
  'General Surgeon',
  'Child Specialist',
];

const List<String> _fallbackTestCategories = [
  'Blood Tests',
  'Diabetes',
  'Liver',
  'Imaging',
  'Thyroid',
  'Heart',
  'Urine Tests',
  'Hormones',
];

class FirestoreRepository implements FauridocRepository {
  FirestoreRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Bundled research data, used as a read-only fallback for the directory
  /// listings while the Firestore collections are still empty (i.e. before
  /// the admin runs the one-tap seed import). Cached after first load.
  SeedBundle? _fallbackBundle;
  Future<SeedBundle> _seedBundle() async =>
      _fallbackBundle ??= await loadSeedBundle();

  // ---------- collection helpers ----------

  CollectionReference<Map<String, dynamic>> get _doctors => _db.collection('doctors');
  CollectionReference<Map<String, dynamic>> get _labs => _db.collection('labs');
  CollectionReference<Map<String, dynamic>> get _hospitals => _db.collection('hospitals');
  CollectionReference<Map<String, dynamic>> get _questions => _db.collection('questions');
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  DocumentReference<Map<String, dynamic>> get _configDoc => _db.doc('config/app');

  /// JSON of a doc, with the Firestore doc id forced into 'id'.
  Map<String, dynamic> _json(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return {'id': doc.id};
    return {...data, 'id': doc.id};
  }

  Map<String, dynamic> _jsonFromData(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return {...doc.data(), 'id': doc.id};
  }

  static String _clean(String? v) => (v ?? '').trim().toLowerCase();

  /// Registers a new entity as pending: generates an id, forces
  /// approved=false / verified=false, and stores the id inside the doc.
  Future<String> _register(
      CollectionReference<Map<String, dynamic>> col, Map<String, dynamic> json) async {
    final id = col.doc().id;
    json['id'] = id;
    json['approved'] = false;
    json['verified'] = false;
    await col.doc(id).set(json);
    return id;
  }

  /// One-time import of the bundled research seed data (admin action).
  /// Writes doctors/labs/hospitals with their researched ids so re-imports
  /// overwrite rather than duplicate. Returns counts per collection.
  Future<Map<String, int>> importSeedBundle(SeedBundle bundle) async {
    var batch = _db.batch();
    var ops = 0;
    Future<void> flush() async {
      if (ops > 0) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }

    for (final d in bundle.doctors) {
      batch.set(_doctors.doc(d.id), d.toJson(), SetOptions(merge: true));
      if (++ops >= 400) await flush();
    }
    for (final l in bundle.labs) {
      batch.set(_labs.doc(l.id), l.toJson(), SetOptions(merge: true));
      if (++ops >= 400) await flush();
    }
    for (final h in bundle.hospitals) {
      batch.set(_hospitals.doc(h.id), h.toJson(), SetOptions(merge: true));
      if (++ops >= 400) await flush();
    }
    await flush();
    if (bundle.cities.isNotEmpty) {
      await _db.collection('config').doc('lists').set({
        'cities': bundle.cities,
        'specialties': bundle.specialties,
        'testCategories': bundle.testCategories,
      }, SetOptions(merge: true));
    }
    return {
      'doctors': bundle.doctors.length,
      'labs': bundle.labs.length,
      'hospitals': bundle.hospitals.length,
    };
  }

  /// Toggles the current entity doc between approved (verified too) and rejected.
  Future<void> _approve(
      CollectionReference<Map<String, dynamic>> col, String id, bool approve) async {
    final updates = <String, dynamic>{'approved': approve};
    if (approve) updates['verified'] = true;
    await col.doc(id).update(updates);
  }

  // ---------- doctors ----------

  @override
  bool get isDemo => false;

  @override
  Stream<List<Doctor>> watchDoctors({String? city, String? specialty, String? query}) {
    final q = _clean(query);
    bool matches(Doctor d) {
      if (city != null && city.isNotEmpty && d.city != city) return false;
      if (specialty != null && specialty.isNotEmpty && d.specialty != specialty) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${d.name} ${d.specialty} ${d.clinicName} ${d.qualification}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }

    return _doctors
        .where('approved', isEqualTo: true)
        .snapshots()
        .asyncExpand((snap) async* {
      if (snap.docs.isNotEmpty) {
        yield snap.docs
            .map((d) => Doctor.fromJson(_jsonFromData(d)))
            .where(matches)
            .toList();
      } else {
        // Collection not seeded yet: show the bundled research data.
        final bundle = await _seedBundle();
        yield bundle.doctors.where(matches).toList();
      }
    });
  }

  @override
  Future<Doctor?> getDoctor(String id) async {
    try {
      final doc = await _doctors.doc(id).get();
      if (doc.exists) return Doctor.fromJson(_json(doc));
    } catch (_) {
      // Firestore read failed (offline, permissions): fall back to seeds.
    }
    final bundle = await _seedBundle();
    try {
      return bundle.doctors.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> registerDoctor(Doctor doctor) => _register(_doctors, doctor.toJson());

  @override
  Future<void> updateDoctor(Doctor doctor) async {
    await _doctors.doc(doctor.id).set(doctor.toJson());
  }

  @override
  Future<void> deleteDoctor(String id) async {
    await _doctors.doc(id).delete();
  }

  @override
  Future<void> approveDoctor(String id, {required bool approve}) =>
      _approve(_doctors, id, approve);

  @override
  Stream<List<Doctor>> watchPendingDoctors() {
    return _doctors.where('approved', isEqualTo: false).snapshots().map((snap) {
      final list = snap.docs.map((d) => Doctor.fromJson(_jsonFromData(d))).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ---------- labs ----------

  @override
  Stream<List<Lab>> watchLabs({String? city, String? query, String? testQuery}) {
    final q = _clean(query);
    final tq = _clean(testQuery);
    bool matches(Lab l) {
      if (city != null && city.isNotEmpty && l.city != city) return false;
      if (q.isNotEmpty && !l.name.toLowerCase().contains(q)) return false;
      if (tq.isNotEmpty &&
          !l.tests.any((t) => t.test.toLowerCase().contains(tq))) {
        return false;
      }
      return true;
    }

    return _labs
        .where('approved', isEqualTo: true)
        .snapshots()
        .asyncExpand((snap) async* {
      if (snap.docs.isNotEmpty) {
        yield snap.docs
            .map((d) => Lab.fromJson(_jsonFromData(d)))
            .where(matches)
            .toList();
      } else {
        final bundle = await _seedBundle();
        yield bundle.labs.where(matches).toList();
      }
    });
  }

  @override
  Future<Lab?> getLab(String id) async {
    try {
      final doc = await _labs.doc(id).get();
      if (doc.exists) return Lab.fromJson(_json(doc));
    } catch (_) {
      // Firestore read failed (offline, permissions): fall back to seeds.
    }
    final bundle = await _seedBundle();
    try {
      return bundle.labs.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> registerLab(Lab lab) => _register(_labs, lab.toJson());

  @override
  Future<void> updateLab(Lab lab) async {
    await _labs.doc(lab.id).set(lab.toJson());
  }

  @override
  Future<void> deleteLab(String id) async {
    await _labs.doc(id).delete();
  }

  @override
  Future<void> approveLab(String id, {required bool approve}) =>
      _approve(_labs, id, approve);

  @override
  Stream<List<Lab>> watchPendingLabs() {
    return _labs.where('approved', isEqualTo: false).snapshots().map((snap) {
      final list = snap.docs.map((d) => Lab.fromJson(_jsonFromData(d))).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ---------- hospitals ----------

  @override
  Stream<List<Hospital>> watchHospitals({String? city, String? query}) {
    final q = _clean(query);
    bool matches(Hospital h) {
      if (city != null && city.isNotEmpty && h.city != city) return false;
      if (q.isNotEmpty && !h.name.toLowerCase().contains(q)) return false;
      return true;
    }

    return _hospitals
        .where('approved', isEqualTo: true)
        .snapshots()
        .asyncExpand((snap) async* {
      if (snap.docs.isNotEmpty) {
        yield snap.docs
            .map((d) => Hospital.fromJson(_jsonFromData(d)))
            .where(matches)
            .toList();
      } else {
        final bundle = await _seedBundle();
        yield bundle.hospitals.where(matches).toList();
      }
    });
  }

  @override
  Future<Hospital?> getHospital(String id) async {
    try {
      final doc = await _hospitals.doc(id).get();
      if (doc.exists) return Hospital.fromJson(_json(doc));
    } catch (_) {
      // Firestore read failed (offline, permissions): fall back to seeds.
    }
    final bundle = await _seedBundle();
    try {
      return bundle.hospitals.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> registerHospital(Hospital hospital) =>
      _register(_hospitals, hospital.toJson());

  @override
  Future<void> updateHospital(Hospital hospital) async {
    await _hospitals.doc(hospital.id).set(hospital.toJson());
  }

  @override
  Future<void> deleteHospital(String id) async {
    await _hospitals.doc(id).delete();
  }

  @override
  Future<void> approveHospital(String id, {required bool approve}) =>
      _approve(_hospitals, id, approve);

  @override
  Stream<List<Hospital>> watchPendingHospitals() {
    return _hospitals.where('approved', isEqualTo: false).snapshots().map((snap) {
      final list = snap.docs.map((d) => Hospital.fromJson(_jsonFromData(d))).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ---------- reviews ----------

  @override
  Stream<List<Review>> watchReviews(String doctorId) {
    return _doctors
        .doc(doctorId)
        .collection('reviews')
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => Review.fromJson(_jsonFromData(d))).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Stream<List<Review>> watchReviewsByUser(String uid) {
    // Reviews live in per-doctor subcollections; the collection group query
    // finds all of them, and the parent doctor id is taken from the doc path.
    return _db
        .collectionGroup('reviews')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) {
        final json = _jsonFromData(d);
        json['doctorId'] = d.reference.parent.parent?.id ?? '';
        return Review.fromJson(json);
      }).toList();
      // createdAt is an ISO-8601 string, so sort client-side.
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<void> addReview(Review review) async {
    final col = _doctors.doc(review.doctorId).collection('reviews');
    final existing = await col
        .where('userId', isEqualTo: review.userId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw const DuplicateReviewException();
    }
    final id = review.id.isEmpty ? newId('rv_') : review.id;
    final json = review.toJson()..['id'] = id;
    await col.doc(id).set(json);
    await _recalcDoctorRating(review.doctorId);
  }

  @override
  Future<void> deleteReview(String doctorId, String reviewId) async {
    await _doctors.doc(doctorId).collection('reviews').doc(reviewId).delete();
    await _recalcDoctorRating(doctorId);
  }

  /// Recomputes a doctor's rating/reviewCount from all of its reviews.
  Future<void> _recalcDoctorRating(String doctorId) async {
    final snap = await _doctors.doc(doctorId).collection('reviews').get();
    final count = snap.docs.length;
    double avg = 0;
    if (count > 0) {
      var sum = 0;
      for (final d in snap.docs) {
        sum += ((d.data()['rating'] as num?)?.toInt() ?? 0);
      }
      avg = sum / count;
    }
    await _doctors.doc(doctorId).update({'rating': avg, 'reviewCount': count});
  }

  // ---------- community ----------

  @override
  Stream<List<CommunityQuestion>> watchQuestions(
      {String? city, String? specialty, String? query}) {
    final q = _clean(query);
    return _questions.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => CommunityQuestion.fromJson(_jsonFromData(d)))
          .where((e) {
        if (city != null && city.isNotEmpty && e.city != city) return false;
        if (specialty != null && specialty.isNotEmpty && e.specialty != specialty) {
          return false;
        }
        if (q.isNotEmpty &&
            !'${e.title} ${e.body}'.toLowerCase().contains(q)) {
          return false;
        }
        return true;
      }).toList();
      list.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  @override
  Future<CommunityQuestion?> getQuestion(String id) async {
    final doc = await _questions.doc(id).get();
    if (!doc.exists) return null;
    return CommunityQuestion.fromJson(_json(doc));
  }

  @override
  Stream<List<CommunityReply>> watchReplies(String questionId) {
    return _questions
        .doc(questionId)
        .collection('replies')
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => CommunityReply.fromJson(_jsonFromData(d))).toList();
      list.sort((a, b) => b.score.compareTo(a.score));
      return list;
    });
  }

  @override
  Future<String> askQuestion(CommunityQuestion question) async {
    final id = question.id.isEmpty ? newId('q_') : question.id;
    final json = question.toJson()..['id'] = id;
    await _questions.doc(id).set(json);
    return id;
  }

  @override
  Future<String> addReply(CommunityReply reply) async {
    final id = reply.id.isEmpty ? newId('rp_') : reply.id;
    final json = reply.toJson()..['id'] = id;
    await _questions.doc(reply.questionId).collection('replies').doc(id).set(json);
    return id;
  }

  /// Toggles [uid]'s vote on [ref]: same vote again removes it.
  Future<void> _toggleVote(
      DocumentReference<Map<String, dynamic>> ref, String uid, int delta) async {
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;
    final votes = <String, int>{};
    final raw = data['votes'];
    if (raw is Map) {
      raw.forEach((k, v) {
        votes[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }
    if (votes[uid] == delta) {
      votes.remove(uid);
    } else {
      votes[uid] = delta;
    }
    var up = 0;
    var down = 0;
    for (final v in votes.values) {
      if (v > 0) {
        up++;
      } else if (v < 0) {
        down++;
      }
    }
    await ref.update({'votes': votes, 'upvotes': up, 'downvotes': down});
  }

  @override
  Future<void> voteQuestion(String questionId, String uid, int delta) =>
      _toggleVote(_questions.doc(questionId), uid, delta);

  @override
  Future<void> voteReply(String questionId, String replyId, String uid, int delta) =>
      _toggleVote(_questions.doc(questionId).collection('replies').doc(replyId), uid, delta);

  @override
  Future<void> pinQuestion(String questionId, bool pinned) async {
    await _questions.doc(questionId).update({'pinned': pinned});
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    final replies = await _questions.doc(questionId).collection('replies').get();
    for (final d in replies.docs) {
      await d.reference.delete();
    }
    await _questions.doc(questionId).delete();
  }

  @override
  Future<void> deleteReply(String questionId, String replyId) async {
    await _questions.doc(questionId).collection('replies').doc(replyId).delete();
  }

  // ---------- doctor stats ----------

  /// Monday of the current week as 'yyyy-MM-dd'.
  String _currentMonday() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Stats are best-effort: errors are swallowed so callers never throw.
  Future<void> _recordStat(String doctorId, String field) async {
    try {
      final ref = _db.collection('doctor_stats').doc(doctorId);
      final snap = await ref.get();
      final data = snap.data();
      final monday = _currentMonday();
      final stale = data == null || (data['week'] as String?) != monday;
      final updates = <String, dynamic>{};
      if (stale) {
        updates['views'] = 0;
        updates['whatsapp'] = 0;
        updates['week'] = monday;
      }
      updates[field] = FieldValue.increment(1);
      await ref.set(updates, SetOptions(merge: true));
    } catch (_) {
      // Best-effort: never throw to callers.
    }
  }

  @override
  Future<void> recordProfileView(String doctorId) => _recordStat(doctorId, 'views');

  @override
  Future<void> recordWhatsappClick(String doctorId) =>
      _recordStat(doctorId, 'whatsapp');

  @override
  Future<Map<String, int>> getWeeklyStats(String doctorId) async {
    const empty = {'views': 0, 'whatsapp': 0};
    final snap = await _db.collection('doctor_stats').doc(doctorId).get();
    final data = snap.data();
    if (data == null) return Map<String, int>.from(empty);
    if ((data['week'] as String?) != _currentMonday()) {
      return Map<String, int>.from(empty);
    }
    return {
      'views': (data['views'] as num?)?.toInt() ?? 0,
      'whatsapp': (data['whatsapp'] as num?)?.toInt() ?? 0,
    };
  }

  // ---------- config lists (admin-editable) ----------

  List<String> _stringList(Object? value, List<String> fallback) {
    if (value is List) {
      final list = value.map((e) => e.toString()).toList();
      if (list.isNotEmpty) return list;
    }
    return fallback;
  }

  /// Fallback chain: config doc list -> seed bundle list -> short hardcoded
  /// list. Seed bundle lookups are async, so the config snapshot stream is
  /// expanded to await the bundle when the config value is missing or empty.
  Stream<List<String>> _watchConfigList(String field, List<String> fallback,
      List<String> Function(SeedBundle bundle) seedList) {
    return _configDoc.snapshots().asyncExpand((snap) async* {
      final configList = _stringList(snap.data()?[field], const []);
      if (configList.isNotEmpty) {
        yield configList;
        return;
      }
      try {
        final bundle = await _seedBundle();
        final seed = seedList(bundle);
        yield seed.isNotEmpty ? seed : fallback;
      } catch (_) {
        yield fallback;
      }
    });
  }

  @override
  Stream<List<String>> watchCities() =>
      _watchConfigList('cities', _fallbackCities, (b) => b.cities);

  @override
  Stream<List<String>> watchSpecialties() =>
      _watchConfigList('specialties', _fallbackSpecialties, (b) => b.specialties);

  @override
  Stream<List<String>> watchTestCategories() =>
      _watchConfigList('testCategories', _fallbackTestCategories,
          (b) => b.testCategories);

  @override
  Future<void> setCities(List<String> cities) async {
    await _configDoc.set({'cities': cities}, SetOptions(merge: true));
  }

  @override
  Future<void> setSpecialties(List<String> specialties) async {
    await _configDoc.set({'specialties': specialties}, SetOptions(merge: true));
  }

  @override
  Future<void> setTestCategories(List<String> categories) async {
    await _configDoc.set({'testCategories': categories}, SetOptions(merge: true));
  }

  // ---------- admin ----------

  StreamController<AdminCounts>? _adminController;
  final List<StreamSubscription<dynamic>> _adminSubs = [];
  QuerySnapshot<Map<String, dynamic>>? _admDoctors;
  QuerySnapshot<Map<String, dynamic>>? _admLabs;
  QuerySnapshot<Map<String, dynamic>>? _admHospitals;
  QuerySnapshot<Map<String, dynamic>>? _admUsers;

  @override
  Stream<AdminCounts> watchAdminCounts() {
    _adminController ??= StreamController<AdminCounts>.broadcast();
    if (_adminSubs.isEmpty) {
      void onError(Object e) {
        final c = _adminController;
        if (c != null && !c.isClosed) c.addError(e);
      }

      _adminSubs.addAll([
        _doctors.snapshots().listen((s) {
          _admDoctors = s;
          _emitAdminCounts();
        }, onError: onError),
        _labs.snapshots().listen((s) {
          _admLabs = s;
          _emitAdminCounts();
        }, onError: onError),
        _hospitals.snapshots().listen((s) {
          _admHospitals = s;
          _emitAdminCounts();
        }, onError: onError),
        _users.snapshots().listen((s) {
          _admUsers = s;
          _emitAdminCounts();
        }, onError: onError),
      ]);
    }
    return _adminController!.stream;
  }

  void _emitAdminCounts() {
    final c = _adminController;
    if (c == null || c.isClosed) return;

    int approved(QuerySnapshot<Map<String, dynamic>>? snap) =>
        snap?.docs.where((d) => (d.data()['approved'] as bool?) == true).length ?? 0;

    int pending(QuerySnapshot<Map<String, dynamic>>? snap) =>
        snap?.docs.where((d) => (d.data()['approved'] as bool?) != true).length ?? 0;

    final doctorDocs = _admDoctors?.docs ?? [];

    var reviews = 0;
    for (final d in doctorDocs) {
      reviews += ((d.data()['reviewCount'] as num?)?.toInt() ?? 0);
    }

    c.add(AdminCounts(
      doctors: approved(_admDoctors),
      labs: approved(_admLabs),
      hospitals: approved(_admHospitals),
      pending: pending(_admDoctors) + pending(_admLabs) + pending(_admHospitals),
      users: _admUsers?.docs.length ?? 0,
      reviews: reviews,
    ));
  }

  // ---------- entities owned by a user ----------

  @override
  Stream<List<Doctor>> watchMyDoctors(String uid) {
    return _doctors.where('ownerUid', isEqualTo: uid).snapshots().map(
        (snap) => snap.docs.map((d) => Doctor.fromJson(_jsonFromData(d))).toList());
  }

  @override
  Stream<List<Lab>> watchMyLabs(String uid) {
    return _labs.where('ownerUid', isEqualTo: uid).snapshots().map(
        (snap) => snap.docs.map((d) => Lab.fromJson(_jsonFromData(d))).toList());
  }

  @override
  Stream<List<Hospital>> watchMyHospitals(String uid) {
    return _hospitals.where('ownerUid', isEqualTo: uid).snapshots().map(
        (snap) => snap.docs.map((d) => Hospital.fromJson(_jsonFromData(d))).toList());
  }

  // ---------- photos ----------

  @override
  Future<String> uploadPhoto(String entityKind, String entityId, String localPath) async {
    final ref = FirebaseStorage.instance.ref(
        'entity_photos/$entityKind/$entityId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final snapshot = await ref.putFile(File(localPath));
    return snapshot.ref.getDownloadURL();
  }

  // ---------- users ----------

  @override
  Future<void> upsertUser(AppUser user) async {
    await _users.doc(user.uid).set(user.toJson(), SetOptions(merge: true));
  }

  @override
  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromJson(_json(doc));
    });
  }
}
