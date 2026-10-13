import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/review.dart';
import '../providers/providers.dart';
import '../providers/font_scale.dart';
import '../widgets/theme.dart';
import 'auth_screen.dart';

/// "My reviews": every review the signed-in user has written, newest first.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(fontScaleProvider); // Re-render when the font-size sliders change.
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final user = ref.watch(authProvider);
    final repo = ref.watch(repositoryProvider);

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
        title: Text(tr(ref, 'myrev.title'),
            style: FdType.title(ur, size: 22)),
      ),
      body: user == null
          ? _signInPrompt(ref, ur, context)
          : StreamBuilder<List<Review>>(
              stream: repo.watchReviewsByUser(user.uid),
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
                final reviews = snap.data ?? const <Review>[];
                if (reviews.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(tr(ref, 'myrev.empty'),
                          style: FdType.body(ur,
                              size: 16, color: FdColors.muted),
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: reviews.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _ReviewCard(review: reviews[i]),
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

/// One review card: doctor name, stars, text, date, edit/delete actions.
class _ReviewCard extends ConsumerWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final repo = ref.watch(repositoryProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FutureBuilder(
                  future: repo.getDoctor(review.doctorId),
                  builder: (context, snap) {
                    final name =
                        snap.data?.name ?? tr(ref, 'myrev.unknownDoctor');
                    return Text(name,
                        style: FdType.title(ur, size: 17),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      review.rating >= i ? Icons.star : Icons.star_border,
                      color: FdColors.starGold,
                      size: 18,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(_ago(ref, review.createdAt),
              style: FdType.label(ur, size: 12, color: FdColors.muted)),
          if (review.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.text,
                style: FdType.body(ur, size: 15, color: FdColors.inkSoft)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _edit(ref, context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(tr(ref, 'myrev.edit'),
                      style: FdType.body(ur,
                          size: 14,
                          w: FontWeight.w600,
                          color: FdColors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: FdColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(FdDim.pillRadius)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _delete(ref, context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(tr(ref, 'myrev.delete'),
                      style: FdType.body(ur,
                          size: 14,
                          w: FontWeight.w600,
                          color: FdColors.redInk)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: FdColors.red.withValues(alpha: 0.4),
                        width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(FdDim.pillRadius)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Edit = delete + re-add (one review per person), same pattern as
  /// reviews_screen.dart, including DuplicateReviewException handling.
  Future<void> _edit(WidgetRef ref, BuildContext context) async {
    final user = ref.read(authProvider);
    if (user == null) return;
    final result = await showDialog<_EditedReview>(
      context: context,
      builder: (_) => _EditReviewDialog(
        initialStars: review.rating,
        initialText: review.text,
      ),
    );
    if (result == null || !context.mounted) return;
    final locale = ref.read(localeProvider);
    final repo = ref.read(repositoryProvider);
    try {
      await repo.deleteReview(review.doctorId, review.id);
      await repo.addReview(
        Review(
          id: '',
          doctorId: review.doctorId,
          userId: user.uid,
          userName: user.name,
          rating: result.stars,
          text: result.text,
          createdAt: DateTime.now(),
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translate(locale, 'myrev.updated'))),
        );
      }
    } on DuplicateReviewException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translate(locale, 'myrev.already'))),
        );
      }
    }
  }

  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    final locale = ref.read(localeProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(tr(ref, 'myrev.confirmDelete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(ref, 'myrev.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr(ref, 'myrev.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(repositoryProvider)
        .deleteReview(review.doctorId, review.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate(locale, 'myrev.deleted'))),
      );
    }
  }
}

class _EditedReview {
  final int stars;
  final String text;
  const _EditedReview(this.stars, this.text);
}

/// Edit dialog: star picker + text field.
class _EditReviewDialog extends ConsumerStatefulWidget {
  final int initialStars;
  final String initialText;

  const _EditReviewDialog({
    required this.initialStars,
    required this.initialText,
  });

  @override
  ConsumerState<_EditReviewDialog> createState() => _EditReviewDialogState();
}

class _EditReviewDialogState extends ConsumerState<_EditReviewDialog> {
  late int _stars;
  late final TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _stars = widget.initialStars;
    _textCtrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    return AlertDialog(
      title: Text(tr(ref, 'myrev.updateTitle'),
          style: FdType.title(ur, size: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    _stars >= i ? Icons.star : Icons.star_border,
                    color: FdColors.starGold,
                    size: 34,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textCtrl,
            maxLines: 3,
            minLines: 3,
            style: FdType.body(ur, size: 15, color: FdColors.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: FdColors.bg,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FdColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FdColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: FdColors.primary, width: 1.6),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr(ref, 'myrev.cancel')),
        ),
        TextButton(
          onPressed: () {
            if (_stars < 1) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr(ref, 'myrev.pickStars'))),
              );
              return;
            }
            Navigator.of(context)
                .pop(_EditedReview(_stars, _textCtrl.text.trim()));
          },
          child: Text(tr(ref, 'myrev.update'),
              style: const TextStyle(color: FdColors.primary)),
        ),
      ],
    );
  }
}

/// Relative "x ago" label, same wording as the reviews screen.
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
