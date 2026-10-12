import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/review.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';

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

/// Reviews for one doctor — design page-11: rating summary with bars,
/// "Rate your visit" composer, sortable review list.
class ReviewsScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const ReviewsScreen({super.key, required this.doctorId});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  int _stars = 0;
  bool _newestFirst = true;
  bool _busy = false;
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'rev.loginFirst'))),
      );
      return;
    }
    if (_stars < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'rev.pickStars'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).addReview(
            Review(
              id: '',
              doctorId: widget.doctorId,
              userId: user.uid,
              userName: user.name,
              rating: _stars,
              text: _textCtrl.text.trim(),
              createdAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      setState(() {
        _stars = 0;
        _textCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'rev.posted'))),
      );
    } on DuplicateReviewException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'rev.already'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String reviewId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(tr(ref, 'rev.confirmDelete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(ref, 'rev.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr(ref, 'rev.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(repositoryProvider)
        .deleteReview(widget.doctorId, reviewId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'rev.deleted'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final repo = ref.watch(repositoryProvider);
    final user = ref.watch(authProvider);
    final isAdmin = (user?.isAdmin ?? false) ||
        (repo.isDemo && ref.watch(demoAdminPreviewProvider));

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
        title: FutureBuilder(
          future: repo.getDoctor(widget.doctorId),
          builder: (context, snap) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(ref, 'rev.title'),
                  style: FdType.title(ur, size: 22)),
              Text(
                snap.data?.name ?? '',
                style: FdType.body(ur, size: 14, color: FdColors.muted),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Review>>(
        stream: repo.watchReviews(widget.doctorId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reviews = snap.data ?? const <Review>[];
          final sorted = List<Review>.of(reviews)
            ..sort((a, b) => _newestFirst
                ? b.createdAt.compareTo(a.createdAt)
                : a.createdAt.compareTo(b.createdAt));
          return ListView(
            padding:
                const EdgeInsets.fromLTRB(FdDim.page, 8, FdDim.page, 24),
            children: [
              if (reviews.isNotEmpty) ...[
                _summaryCard(ref, ur, reviews),
                const SizedBox(height: 14),
              ],
              _composerCard(ref, ur),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(tr(ref, 'rev.allReviews'),
                        style: FdType.title(ur, size: 21)),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _newestFirst = !_newestFirst),
                    child: Row(
                      children: [
                        Text(
                          tr(ref,
                              _newestFirst ? 'rev.newest' : 'rev.oldest'),
                          style: FdType.body(ur,
                              size: 15,
                              w: FontWeight.w600,
                              color: FdColors.primary),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down,
                            color: FdColors.primary, size: 22),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(tr(ref, 'rev.noReviews'),
                        style:
                            FdType.body(ur, color: FdColors.muted),
                        textAlign: TextAlign.center),
                  ),
                )
              else
                for (var i = 0; i < sorted.length; i++) ...[
                  _reviewRow(ref, ur, sorted[i], user?.uid, isAdmin),
                  if (i < sorted.length - 1)
                    const Divider(color: FdColors.line, height: 28),
                ],
            ],
          );
        },
      ),
    );
  }

  // ---------- summary ----------

  Widget _summaryCard(WidgetRef ref, bool ur, List<Review> reviews) {
    final avg =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) /
            reviews.length;
    final counts = <int, int>{for (var s = 1; s <= 5; s++) s: 0};
    for (final r in reviews) {
      counts[r.rating.clamp(1, 5)] = (counts[r.rating.clamp(1, 5)] ?? 0) + 1;
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: FdType.display(ur, size: 52),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= avg.round() ? Icons.star : Icons.star_border,
                      color: FdColors.starGold,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fill(tr(ref, 'rev.count'), {'n': '${reviews.length}'}),
                style: FdType.body(ur, size: 14, color: FdColors.muted),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                for (var s = 5; s >= 1; s--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Text('$s',
                              style: FdType.body(ur,
                                  size: 14,
                                  w: FontWeight.w600,
                                  color: FdColors.muted)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: reviews.isEmpty
                                  ? 0
                                  : (counts[s] ?? 0) / reviews.length,
                              minHeight: 9,
                              backgroundColor: FdColors.line
                                  .withValues(alpha: 0.6),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      FdColors.starGold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- composer ----------

  Widget _composerCard(WidgetRef ref, bool ur) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'rev.rateYourVisit'),
              style: FdType.title(ur, size: 19)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => setState(() => _stars = i),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      i <= _stars ? Icons.star : Icons.star_border,
                      color: i <= _stars
                          ? FdColors.starGold
                          : FdColors.muted.withValues(alpha: 0.5),
                      size: 40,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _textCtrl,
            maxLines: 4,
            minLines: 3,
            style: FdType.body(ur, size: 16, color: FdColors.ink),
            decoration: InputDecoration(
              hintText: tr(ref, 'rev.hint'),
              hintStyle:
                  FdType.body(ur, size: 16, color: FdColors.muted),
              filled: true,
              fillColor: FdColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: FdColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: FdColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: FdColors.primary, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(tr(ref, 'rev.onePerPerson'),
                    style: FdType.body(ur,
                        size: 13.5, color: FdColors.muted)),
              ),
              const SizedBox(width: 12),
              FdButton(
                label: tr(ref, 'rev.post'),
                isUrdu: ur,
                onTap: _busy ? null : _post,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- review rows ----------

  static const _avatarTints = [
    (Color(0xFFFBE0E6), Color(0xFFB3261E)),
    (Color(0xFFE2F3ED), Color(0xFF0B6B5D)),
    (Color(0xFFE3EBFD), Color(0xFF3B4A9E)),
    (Color(0xFFFFF0DB), Color(0xFF8A5A00)),
  ];

  Widget _reviewRow(WidgetRef ref, bool ur, Review r, String? myUid,
      bool isAdmin) {
    final tint = _avatarTints[r.userName.hashCode.abs() % _avatarTints.length];
    final initial = r.userName.trim().isEmpty
        ? '•'
        : r.userName.trim()[0].toUpperCase();
    final canDelete = isAdmin || (myUid != null && myUid == r.userId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: tint.$1, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(initial,
                  style: FdType.body(false,
                      size: 20, w: FontWeight.w700, color: tint.$2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.userName,
                      style: FdType.body(ur,
                          size: 17,
                          w: FontWeight.w700,
                          color: FdColors.ink)),
                  Text(_ago(ref, r.createdAt),
                      style: FdType.body(ur,
                          size: 14, color: FdColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.star, color: FdColors.starGold, size: 20),
            const SizedBox(width: 4),
            Text(
              r.rating.toDouble().toStringAsFixed(1),
              style: FdType.body(ur,
                  size: 17, w: FontWeight.w700, color: FdColors.ink),
            ),
            if (canDelete) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: FdColors.muted),
                onPressed: () => _delete(r.id),
              ),
            ],
          ],
        ),
        if (r.text.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(r.text,
              style:
                  FdType.body(ur, size: 16, color: FdColors.inkSoft)),
        ],
      ],
    );
  }
}
