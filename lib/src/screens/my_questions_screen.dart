import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/community.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'auth_screen.dart';
import 'question_detail_screen.dart';

String _ago(WidgetRef ref, DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return tr(ref, 'rev.justNow');
  if (d.inMinutes < 60) {
    return fill(tr(ref, 'rev.minutesAgo'), {'n': '${d.inMinutes}'});
  }
  if (d.inHours < 24) {
    return fill(tr(ref, 'rev.hoursAgo'), {'n': '${d.inHours}'});
  }
  if (d.inDays < 7) {
    return fill(tr(ref, 'rev.daysAgo'), {'n': '${d.inDays}'});
  }
  if (d.inDays < 30) {
    return fill(tr(ref, 'rev.weeksAgo'), {'n': '${d.inDays ~/ 7}'});
  }
  return fill(tr(ref, 'rev.monthsAgo'), {'n': '${d.inDays ~/ 30}'});
}

/// "My questions": every question the signed-in user has asked, newest first.
class MyQuestionsScreen extends ConsumerWidget {
  const MyQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final user = ref.watch(authProvider);
    final FauridocRepository repo = ref.watch(repositoryProvider);

    return Scaffold(
      backgroundColor: FdColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_right
                : Icons.chevron_left,
            size: 30,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(tr(ref, 'myq.title'),
            style: FdType.title(ur, size: 22)),
      ),
      body: user == null
          ? _signInPrompt(ref, ur, context)
          : StreamBuilder<List<CommunityQuestion>>(
              stream: repo.watchQuestions(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(tr(ref, 'error'),
                        style: FdType.body(ur, color: FdColors.muted),
                        textAlign: TextAlign.center),
                  );
                }
                final mine = (snap.data ?? const <CommunityQuestion>[])
                    .where((q) => q.userId == user.uid)
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                if (mine.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(tr(ref, 'myq.empty'),
                          style: FdType.body(ur,
                              size: 16, color: FdColors.muted),
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: mine.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _QuestionRow(question: mine[i]),
                );
              },
            ),
    );
  }

  Widget _signInPrompt(WidgetRef ref, bool ur, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr(ref, 'myrev.signInPrompt'),
                style: FdType.body(ur, size: 16, color: FdColors.muted),
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FdButton(
              label: tr(ref, 'myrev.signIn'),
              isUrdu: ur,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One question card: title, city/specialty chips, score, reply count, date.
/// Taps open the shared question detail screen.
class _QuestionRow extends ConsumerWidget {
  final CommunityQuestion question;

  const _QuestionRow({required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final FauridocRepository repo = ref.watch(repositoryProvider);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              QuestionDetailScreen(questionId: question.id))),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FdColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.title,
                style: FdType.body(ur,
                        size: 16,
                        w: FontWeight.w700,
                        color: FdColors.ink)
                    .copyWith(height: FdType.height(ur, 1.3))),
            if (question.city.trim().isNotEmpty ||
                question.specialty.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (question.city.trim().isNotEmpty)
                    _tag(ur, question.city),
                  if (question.specialty.trim().isNotEmpty)
                    _tag(ur,
                        specialtyLabel(
                            ref.watch(localeProvider),
                            question.specialty)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            StreamBuilder<List<CommunityReply>>(
              stream: repo.watchReplies(question.id),
              builder: (context, snap) {
                final replies = snap.data ?? const <CommunityReply>[];
                return Row(
                  children: [
                    _scorePill(ur, question.score),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${fill(tr(ref, 'com.replies'), {'n': '${replies.length}'})} · ${_ago(ref, question.createdAt)}',
                        style: FdType.body(ur,
                            size: 12,
                            w: FontWeight.w500,
                            color: FdColors.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(bool ur, String label) {
    // Spec: padding 2 9, radius 10, #EEF1F0, 12/600 #2E4744.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: FdType.body(ur,
            size: 12, w: FontWeight.w600, color: const Color(0xFF2E4744)),
      ),
    );
  }

  Widget _scorePill(bool ur, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F3EF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_upward,
              size: 13, color: FdColors.primaryDark),
          const SizedBox(width: 3),
          Text(
            '$score',
            style: const TextStyle(
              fontFamily: FdType.latin,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FdColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
