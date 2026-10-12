import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fauridoc/src/data/demo_repository.dart';
import 'package:fauridoc/src/data/repository.dart';
import 'package:fauridoc/src/data/seeds.dart';
import 'package:fauridoc/src/models/community.dart';
import 'package:fauridoc/src/models/doctor.dart';
import 'package:fauridoc/src/models/review.dart';

void main() {
  late DemoRepository repo;

  setUp(() async {
    // Fresh in-memory prefs per test: setMockInitialValues resets the
    // SharedPreferences singleton, so every repo below re-seeds from scratch.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = DemoRepository(prefs);
  });

  test('seeds 10 approved doctors', () async {
    // watch* streams only emit on mutation, so subscribe first, then poke
    // with a no-op mutation (state-equal, but emits a tick).
    final doctorsFuture = repo.watchDoctors().first;
    await repo.setCities(defaultCities);
    final doctors = await doctorsFuture;
    expect(doctors.length, 10);
    expect(doctors.every((d) => d.approved), isTrue);
  });

  test('register creates pending; approve/reject toggles visibility', () async {
    final doctorsFuture = repo.watchDoctors().first;
    final pendingFuture = repo.watchPendingDoctors().first;
    final id = await repo.registerDoctor(
      Doctor(
        id: '',
        name: 'Test Doctor',
        specialty: 'General Physician',
        city: 'Mardan',
        ownerUid: 'u1',
      ),
    );
    expect((await doctorsFuture).any((d) => d.id == id), isFalse);
    expect((await pendingFuture).any((d) => d.id == id), isTrue);

    var visibleFuture = repo.watchDoctors().first;
    await repo.approveDoctor(id, approve: true);
    expect((await visibleFuture).any((d) => d.id == id), isTrue);

    visibleFuture = repo.watchDoctors().first;
    await repo.approveDoctor(id, approve: false);
    expect((await visibleFuture).any((d) => d.id == id), isFalse);
  });

  test('one review per user per doctor; rating is recomputed', () async {
    await repo.addReview(
      Review(
        id: '',
        doctorId: 'seed_dr_1',
        userId: 'u1',
        userName: 'Tester',
        rating: 5,
        text: 'Great',
      ),
    );
    await expectLater(
      repo.addReview(
        Review(
          id: '',
          doctorId: 'seed_dr_1',
          userId: 'u1',
          userName: 'Tester',
          rating: 4,
          text: 'Again',
        ),
      ),
      throwsA(isA<DuplicateReviewException>()),
    );
    await repo.addReview(
      Review(
        id: '',
        doctorId: 'seed_dr_1',
        userId: 'u2',
        userName: 'Other',
        rating: 5,
        text: 'Good',
      ),
    );

    final doctor = await repo.getDoctor('seed_dr_1');
    expect(doctor, isNotNull);
    expect(doctor!.reviewCount, 2);
    expect(doctor.rating, 5.0);
  });

  test('question votes toggle on repeat', () async {
    final questionsFuture = repo.watchQuestions().first;
    final qid = await repo.askQuestion(
      CommunityQuestion(id: '', title: 'Q', userId: 'u1', userName: 'U1'),
    );
    await questionsFuture; // drain the ask emission

    Future<CommunityQuestion> voteAndRead(int delta) async {
      final future = repo.watchQuestions().first;
      await repo.voteQuestion(qid, 'u1', delta);
      return (await future).firstWhere((q) => q.id == qid);
    }

    expect((await voteAndRead(1)).upvotes, 1);
    expect((await voteAndRead(1)).upvotes, 0); // same delta toggles off
    expect((await voteAndRead(-1)).downvotes, 1);
  });

  test('admin counts show 10 approved seed doctors', () async {
    final countsFuture = repo.watchAdminCounts().first;
    await repo.setCities(defaultCities); // harmless no-op that emits a tick
    expect((await countsFuture).doctors, 10);
  });
}
