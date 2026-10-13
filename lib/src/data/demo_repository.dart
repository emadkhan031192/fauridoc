import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/community.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../models/model_utils.dart';
import '../models/review.dart';
import 'repository.dart';
import 'seed_loader.dart';
import 'seeds.dart';

/// Demo-mode repository: everything in memory, persisted to
/// SharedPreferences as JSON so registrations, reviews, votes and config
/// edits survive restarts. Used when Firebase isn't configured.
class DemoRepository implements FauridocRepository {
  final SharedPreferences _prefs;

  final Map<String, Doctor> _doctors = {};
  final Map<String, Lab> _labs = {};
  final Map<String, Hospital> _hospitals = {};
  final Map<String, List<Review>> _reviews = {}; // doctorId -> reviews
  final Map<String, CommunityQuestion> _questions = {};
  final Map<String, List<CommunityReply>> _replies = {}; // questionId -> replies
  final Map<String, AppUser> _users = {};
  final Map<String, Map<String, int>> _stats = {}; // doctorId -> {views, whatsapp}
  String _statsWeek = '';

  List<String> _cities = [];
  List<String> _specialties = [];
  List<String> _testCategories = [];

  final _tick = StreamController<void>.broadcast();

  DemoRepository(this._prefs) {
    _load();
  }

  @override
  bool get isDemo => true;

  void _emit() => _tick.add(null);

  /// Stream that yields the current state immediately, then re-emits on
  /// every mutation. (StreamBuilder needs the first frame without waiting
  /// for a change.)
  Stream<T> _watch<T>(T Function() current) async* {
    yield current();
    await for (final _ in _tick.stream) {
      yield current();
    }
  }

  // ---------- persistence ----------
  static const _kDoctors = 'demo_doctors';
  static const _kLabs = 'demo_labs';
  static const _kHospitals = 'demo_hospitals';
  static const _kReviews = 'demo_reviews';
  static const _kQuestions = 'demo_questions';
  static const _kReplies = 'demo_replies';
  static const _kUsers = 'demo_users';
  static const _kStats = 'demo_stats';
  static const _kConfig = 'demo_config';
  static const _kSeedVersion = 'demo_seed_version';
  static const _seedVersion = 2; // bump to force a reseed with fresh research data

  void _load() {
    try {
      final d = _prefs.getString(_kDoctors);
      if (d == null || (_prefs.getInt(_kSeedVersion) ?? 0) < _seedVersion) {
        _seed();
        return;
      }
      for (final e in (jsonDecode(d) as List)) {
        final doc = Doctor.fromJson(Map<String, dynamic>.from(e as Map));
        _doctors[doc.id] = doc;
      }
      for (final e in (jsonDecode(_prefs.getString(_kLabs) ?? '[]') as List)) {
        final lab = Lab.fromJson(Map<String, dynamic>.from(e as Map));
        _labs[lab.id] = lab;
      }
      for (final e in (jsonDecode(_prefs.getString(_kHospitals) ?? '[]') as List)) {
        final h = Hospital.fromJson(Map<String, dynamic>.from(e as Map));
        _hospitals[h.id] = h;
      }
      for (final e in (jsonDecode(_prefs.getString(_kReviews) ?? '[]') as List)) {
        final r = Review.fromJson(Map<String, dynamic>.from(e as Map));
        _reviews.putIfAbsent(r.doctorId, () => []).add(r);
      }
      for (final e in (jsonDecode(_prefs.getString(_kQuestions) ?? '[]') as List)) {
        final q = CommunityQuestion.fromJson(Map<String, dynamic>.from(e as Map));
        _questions[q.id] = q;
      }
      for (final e in (jsonDecode(_prefs.getString(_kReplies) ?? '[]') as List)) {
        final r = CommunityReply.fromJson(Map<String, dynamic>.from(e as Map));
        _replies.putIfAbsent(r.questionId, () => []).add(r);
      }
      for (final e in (jsonDecode(_prefs.getString(_kUsers) ?? '[]') as List)) {
        final u = AppUser.fromJson(Map<String, dynamic>.from(e as Map));
        _users[u.uid] = u;
      }
      final cfg = jsonDecode(_prefs.getString(_kConfig) ?? '{}') as Map;
      _cities = (cfg['cities'] as List?)?.map((e) => e.toString()).toList() ?? defaultCities;
      _specialties =
          (cfg['specialties'] as List?)?.map((e) => e.toString()).toList() ?? defaultSpecialties;
      _testCategories =
          (cfg['testCategories'] as List?)?.map((e) => e.toString()).toList() ??
              defaultTestCategories;
      final st = jsonDecode(_prefs.getString(_kStats) ?? '{}') as Map;
      _statsWeek = (st['week'] as String?) ?? '';
      for (final e in ((st['data'] as Map?) ?? {}).entries) {
        _stats[e.key.toString()] =
            (e.value as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      _rollStatsWeek();
    } catch (_) {
      _seed();
      _save();
    }
  }

  void _seed() {
    // Seed synchronously from the legacy Dart seeds so first paint has data,
    // then replace with the researched JSON bundle when it loads.
    _seedFromDart();
    _seedFromBundle();
  }

  void _seedFromDart() {
    for (final d in seedDoctors()) {
      _doctors[d.id] = d;
    }
    for (final l in seedLabs()) {
      _labs[l.id] = l;
    }
    for (final h in seedHospitals()) {
      _hospitals[h.id] = h;
    }
    for (final q in seedQuestions()) {
      _questions[q.id] = q;
    }
    _cities = List.of(defaultCities);
    _specialties = List.of(defaultSpecialties);
    _testCategories = List.of(defaultTestCategories);
    _statsWeek = _weekKey(DateTime.now());
    _save();
    _emit();
  }

  Future<void> _seedFromBundle() async {
    final bundle = await loadSeedBundle();
    if (bundle.doctors.isEmpty) return;
    // Replace only the legacy 'seed_*' records; keep anything the user added.
    _doctors.removeWhere((id, _) => id.startsWith('seed_'));
    _labs.removeWhere((id, _) => id.startsWith('seed_'));
    _hospitals.removeWhere((id, _) => id.startsWith('seed_'));
    for (final d in bundle.doctors) {
      _doctors.putIfAbsent(d.id, () => d);
    }
    for (final l in bundle.labs) {
      _labs.putIfAbsent(l.id, () => l);
    }
    for (final h in bundle.hospitals) {
      _hospitals.putIfAbsent(h.id, () => h);
    }
    if (bundle.cities.isNotEmpty) _cities = List.of(bundle.cities);
    if (bundle.specialties.isNotEmpty) _specialties = List.of(bundle.specialties);
    if (bundle.testCategories.isNotEmpty) {
      _testCategories = List.of(bundle.testCategories);
    }
    await _prefs.setInt(_kSeedVersion, _seedVersion);
    _save();
    _emit();
  }

  void _save() {
    _prefs.setString(_kDoctors, jsonEncode(_doctors.values.map((e) => e.toJson()).toList()));
    _prefs.setString(_kLabs, jsonEncode(_labs.values.map((e) => e.toJson()).toList()));
    _prefs.setString(
        _kHospitals, jsonEncode(_hospitals.values.map((e) => e.toJson()).toList()));
    _prefs.setString(
      _kReviews,
      jsonEncode(_reviews.values.expand((e) => e).map((e) => e.toJson()).toList()),
    );
    _prefs.setString(
        _kQuestions, jsonEncode(_questions.values.map((e) => e.toJson()).toList()));
    _prefs.setString(
      _kReplies,
      jsonEncode(_replies.values.expand((e) => e).map((e) => e.toJson()).toList()),
    );
    _prefs.setString(_kUsers, jsonEncode(_users.values.map((e) => e.toJson()).toList()));
    _prefs.setString(
      _kConfig,
      jsonEncode({'cities': _cities, 'specialties': _specialties, 'testCategories': _testCategories}),
    );
    _prefs.setString(_kStats, jsonEncode({'week': _statsWeek, 'data': _stats}));
  }

  // ---------- doctors ----------
  @override
  Stream<List<Doctor>> watchDoctors({String? city, String? specialty, String? query}) =>
      _watch(() => _filterDoctors(city: city, specialty: specialty, query: query));

  List<Doctor> _filterDoctors({String? city, String? specialty, String? query}) {
    final q = (query ?? '').trim().toLowerCase();
    return _doctors.values.where((d) {
      if (!d.approved) return false;
      if (city != null && city.isNotEmpty && d.city != city) return false;
      if (specialty != null && specialty.isNotEmpty && d.specialty != specialty) return false;
      if (q.isNotEmpty) {
        final hay = '${d.name} ${d.specialty} ${d.clinicName} ${d.qualification}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<Doctor?> getDoctor(String id) async => _doctors[id];

  @override
  Future<String> registerDoctor(Doctor doctor) async {
    final id = doctor.id.isEmpty ? newId('dr_') : doctor.id;
    final json = doctor.toJson()..['id'] = id;
    _doctors[id] = Doctor.fromJson(json).copyWith(approved: false, verified: false);
    _save();
    _emit();
    return id;
  }

  @override
  Future<void> updateDoctor(Doctor doctor) async {
    _doctors[doctor.id] = doctor;
    _save();
    _emit();
  }

  @override
  Future<void> deleteDoctor(String id) async {
    _doctors.remove(id);
    _reviews.remove(id);
    _save();
    _emit();
  }

  @override
  Future<void> approveDoctor(String id, {required bool approve}) async {
    final d = _doctors[id];
    if (d == null) return;
    _doctors[id] = d.copyWith(approved: approve, verified: approve ? true : d.verified);
    _save();
    _emit();
  }

  @override
  Stream<List<Doctor>> watchPendingDoctors() => _watch(
        () => _doctors.values.where((d) => !d.approved).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  // ---------- labs ----------
  @override
  Stream<List<Lab>> watchLabs({String? city, String? query, String? testQuery}) =>
      _watch(() => _filterLabs(city: city, query: query, testQuery: testQuery));

  List<Lab> _filterLabs({String? city, String? query, String? testQuery}) {
    final q = (query ?? '').trim().toLowerCase();
    final tq = (testQuery ?? '').trim().toLowerCase();
    return _labs.values.where((l) {
      if (!l.approved) return false;
      if (city != null && city.isNotEmpty && l.city != city) return false;
      if (q.isNotEmpty && !l.name.toLowerCase().contains(q)) return false;
      if (tq.isNotEmpty &&
          !l.tests.any((t) => t.test.toLowerCase().contains(tq))) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<Lab?> getLab(String id) async => _labs[id];

  @override
  Future<String> registerLab(Lab lab) async {
    final id = lab.id.isEmpty ? newId('lab_') : lab.id;
    final json = lab.toJson()..['id'] = id;
    _labs[id] = Lab.fromJson(json).copyWith(approved: false, verified: false);
    _save();
    _emit();
    return id;
  }

  @override
  Future<void> updateLab(Lab lab) async {
    _labs[lab.id] = lab;
    _save();
    _emit();
  }

  @override
  Future<void> deleteLab(String id) async {
    _labs.remove(id);
    _save();
    _emit();
  }

  @override
  Future<void> approveLab(String id, {required bool approve}) async {
    final l = _labs[id];
    if (l == null) return;
    _labs[id] = l.copyWith(approved: approve, verified: approve ? true : l.verified);
    _save();
    _emit();
  }

  @override
  Stream<List<Lab>> watchPendingLabs() => _watch(
        () => _labs.values.where((l) => !l.approved).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  // ---------- hospitals ----------
  @override
  Stream<List<Hospital>> watchHospitals({String? city, String? query}) =>
      _watch(() => _filterHospitals(city: city, query: query));

  List<Hospital> _filterHospitals({String? city, String? query}) {
    final q = (query ?? '').trim().toLowerCase();
    return _hospitals.values.where((h) {
      if (!h.approved) return false;
      if (city != null && city.isNotEmpty && h.city != city) return false;
      if (q.isNotEmpty && !h.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Future<Hospital?> getHospital(String id) async => _hospitals[id];

  @override
  Future<String> registerHospital(Hospital hospital) async {
    final id = hospital.id.isEmpty ? newId('hsp_') : hospital.id;
    final json = hospital.toJson()..['id'] = id;
    _hospitals[id] = Hospital.fromJson(json).copyWith(approved: false, verified: false);
    _save();
    _emit();
    return id;
  }

  @override
  Future<void> updateHospital(Hospital hospital) async {
    _hospitals[hospital.id] = hospital;
    _save();
    _emit();
  }

  @override
  Future<void> deleteHospital(String id) async {
    _hospitals.remove(id);
    _save();
    _emit();
  }

  @override
  Future<void> approveHospital(String id, {required bool approve}) async {
    final h = _hospitals[id];
    if (h == null) return;
    _hospitals[id] = h.copyWith(approved: approve, verified: approve ? true : h.verified);
    _save();
    _emit();
  }

  @override
  Stream<List<Hospital>> watchPendingHospitals() => _watch(
        () => _hospitals.values.where((h) => !h.approved).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
  // ---------- reviews ----------
  @override
  Stream<List<Review>> watchReviews(String doctorId) => _watch(
        () => List<Review>.from(_reviews[doctorId] ?? [])
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Stream<List<Review>> watchReviewsByUser(String uid) => _watch(
        () => _reviews.values
            .expand((list) => list)
            .where((r) => r.userId == uid)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<void> addReview(Review review) async {
    final existing = _reviews[review.doctorId] ?? const [];
    if (existing.any((r) => r.userId == review.userId)) {
      throw const DuplicateReviewException();
    }
    final id = review.id.isEmpty ? newId('rev_') : review.id;
    final json = review.toJson()..['id'] = id;
    _reviews.putIfAbsent(review.doctorId, () => []).add(Review.fromJson(json));
    _recalcRating(review.doctorId);
    _save();
    _emit();
  }

  void _recalcRating(String doctorId) {
    final list = _reviews[doctorId] ?? const [];
    final d = _doctors[doctorId];
    if (d == null) return;
    if (list.isEmpty) {
      _doctors[doctorId] = d.copyWith(rating: 0, reviewCount: 0);
      return;
    }
    final avg = list.map((r) => r.rating).reduce((a, b) => a + b) / list.length;
    _doctors[doctorId] =
        d.copyWith(rating: double.parse(avg.toStringAsFixed(1)), reviewCount: list.length);
  }

  @override
  Future<void> deleteReview(String doctorId, String reviewId) async {
    _reviews[doctorId]?.removeWhere((r) => r.id == reviewId);
    _recalcRating(doctorId);
    _save();
    _emit();
  }

  // ---------- community ----------
  @override
  Stream<List<CommunityQuestion>> watchQuestions({String? city, String? specialty, String? query}) =>
      _watch(() => _filterQuestions(city: city, specialty: specialty, query: query));

  List<CommunityQuestion> _filterQuestions({String? city, String? specialty, String? query}) {
    final q = (query ?? '').trim().toLowerCase();
    final list = _questions.values.where((e) {
      if (city != null && city.isNotEmpty && e.city != city) return false;
      if (specialty != null && specialty.isNotEmpty && e.specialty != specialty) return false;
      if (q.isNotEmpty && !'${e.title} ${e.body}'.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  @override
  Future<CommunityQuestion?> getQuestion(String id) async => _questions[id];

  @override
  Stream<List<CommunityReply>> watchReplies(String questionId) => _watch(
        () => List<CommunityReply>.from(_replies[questionId] ?? [])
          ..sort((a, b) => b.score.compareTo(a.score)),
      );

  @override
  Future<String> askQuestion(CommunityQuestion question) async {
    final id = question.id.isEmpty ? newId('q_') : question.id;
    final json = question.toJson()..['id'] = id;
    _questions[id] = CommunityQuestion.fromJson(json);
    _save();
    _emit();
    return id;
  }

  @override
  Future<String> addReply(CommunityReply reply) async {
    final id = reply.id.isEmpty ? newId('r_') : reply.id;
    final json = reply.toJson()..['id'] = id;
    _replies.putIfAbsent(reply.questionId, () => []).add(CommunityReply.fromJson(json));
    _save();
    _emit();
    return id;
  }

  @override
  Future<void> voteQuestion(String questionId, String uid, int delta) async {
    final q = _questions[questionId];
    if (q == null) return;
    _questions[questionId] = q.copyWith(
      votes: _toggleVote(q.votes, uid, delta),
    );
    _recountQuestion(questionId);
    _save();
    _emit();
  }

  void _recountQuestion(String questionId) {
    final q = _questions[questionId];
    if (q == null) return;
    final up = q.votes.values.where((v) => v > 0).length;
    final down = q.votes.values.where((v) => v < 0).length;
    _questions[questionId] = q.copyWith(upvotes: up, downvotes: down);
  }

  @override
  Future<void> voteReply(String questionId, String replyId, String uid, int delta) async {
    final list = _replies[questionId];
    if (list == null) return;
    final i = list.indexWhere((r) => r.id == replyId);
    if (i < 0) return;
    final r = list[i];
    final votes = _toggleVote(r.votes, uid, delta);
    list[i] = r.copyWith(
      votes: votes,
      upvotes: votes.values.where((v) => v > 0).length,
      downvotes: votes.values.where((v) => v < 0).length,
    );
    _save();
    _emit();
  }

  /// Toggle semantics: tapping the same vote again removes it.
  Map<String, int> _toggleVote(Map<String, int> votes, String uid, int delta) {
    final out = Map<String, int>.from(votes);
    if (out[uid] == delta) {
      out.remove(uid);
    } else {
      out[uid] = delta;
    }
    return out;
  }

  @override
  Future<void> pinQuestion(String questionId, bool pinned) async {
    final q = _questions[questionId];
    if (q == null) return;
    _questions[questionId] = q.copyWith(pinned: pinned);
    _save();
    _emit();
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    _questions.remove(questionId);
    _replies.remove(questionId);
    _save();
    _emit();
  }

  @override
  Future<void> deleteReply(String questionId, String replyId) async {
    _replies[questionId]?.removeWhere((r) => r.id == replyId);
    _save();
    _emit();
  }

  // ---------- doctor stats ----------
  String _weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  void _rollStatsWeek() {
    final wk = _weekKey(DateTime.now());
    if (_statsWeek != wk) {
      _statsWeek = wk;
      _stats.clear();
    }
  }

  @override
  Future<void> recordProfileView(String doctorId) async {
    _rollStatsWeek();
    final s = _stats.putIfAbsent(doctorId, () => {'views': 0, 'whatsapp': 0});
    s['views'] = (s['views'] ?? 0) + 1;
    _prefs.setString(_kStats, jsonEncode({'week': _statsWeek, 'data': _stats}));
    _emit();
  }

  @override
  Future<void> recordWhatsappClick(String doctorId) async {
    _rollStatsWeek();
    final s = _stats.putIfAbsent(doctorId, () => {'views': 0, 'whatsapp': 0});
    s['whatsapp'] = (s['whatsapp'] ?? 0) + 1;
    _prefs.setString(_kStats, jsonEncode({'week': _statsWeek, 'data': _stats}));
    _emit();
  }

  @override
  Future<Map<String, int>> getWeeklyStats(String doctorId) async {
    _rollStatsWeek();
    final s = _stats[doctorId];
    return {'views': s?['views'] ?? 0, 'whatsapp': s?['whatsapp'] ?? 0};
  }

  // ---------- config ----------
  @override
  Stream<List<String>> watchCities() => _watch(() => List.of(_cities));

  @override
  Stream<List<String>> watchSpecialties() => _watch(() => List.of(_specialties));

  @override
  Stream<List<String>> watchTestCategories() => _watch(() => List.of(_testCategories));

  @override
  Future<void> setCities(List<String> cities) async {
    _cities = cities.where((c) => c.trim().isNotEmpty).toList();
    _save();
    _emit();
  }

  @override
  Future<void> setSpecialties(List<String> specialties) async {
    _specialties = specialties.where((c) => c.trim().isNotEmpty).toList();
    _save();
    _emit();
  }

  @override
  Future<void> setTestCategories(List<String> categories) async {
    _testCategories = categories.where((c) => c.trim().isNotEmpty).toList();
    _save();
    _emit();
  }

  // ---------- admin ----------
  @override
  Stream<AdminCounts> watchAdminCounts() => _watch(
        () => AdminCounts(
          doctors: _doctors.values.where((d) => d.approved).length,
          labs: _labs.values.where((l) => l.approved).length,
          hospitals: _hospitals.values.where((h) => h.approved).length,
          pending: _doctors.values.where((d) => !d.approved).length +
              _labs.values.where((l) => !l.approved).length +
              _hospitals.values.where((h) => !h.approved).length,
          users: _users.length,
          reviews: _reviews.values.fold(0, (n, l) => n + l.length),
        ),
      );

  // ---------- my entities ----------
  @override
  Stream<List<Doctor>> watchMyDoctors(String uid) =>
      _watch(() => _doctors.values.where((d) => d.ownerUid == uid).toList());

  @override
  Stream<List<Lab>> watchMyLabs(String uid) =>
      _watch(() => _labs.values.where((l) => l.ownerUid == uid).toList());

  @override
  Stream<List<Hospital>> watchMyHospitals(String uid) =>
      _watch(() => _hospitals.values.where((h) => h.ownerUid == uid).toList());

  // ---------- photos ----------
  @override
  Future<String> uploadPhoto(String entityKind, String entityId, String localPath) async =>
      localPath; // demo mode: keep the local file path

  // ---------- users ----------
  @override
  Future<void> upsertUser(AppUser user) async {
    _users[user.uid] = user;
    _save();
    _emit();
  }

  @override
  Stream<AppUser?> watchUser(String uid) => _watch(() => _users[uid]);
}
