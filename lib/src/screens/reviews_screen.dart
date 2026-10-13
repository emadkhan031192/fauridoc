import 'package:fauridoc/design/tokens.dart';
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

/// Spec-only colours that have no FdSpec token.
const _trackBg = Color(0xFFEEF1F0);
const _reviewedBg = Color(0xFFE4F3EF);
const _reviewedBorder = Color(0xFFBFE0D6);
const _reviewedInk = Color(0xFF0B5446);
const _reviewedNote = Color(0xFF2F6A5E);
const _deleteRed = Color(0xFFA11F1F);
const _unfilledStar = Color(0xFFB7C4C0);
const _inputBorder = Color(0xFFD5DEDA);
const _bodyInk = Color(0xFF2E4744);

/// Type helper matching the HTML spec sizes exactly (1 CSS px = 1 logical px).
/// Urdu switches to Nastaliq at w700 with extra line height, per app convention.
TextStyle _t(bool ur, double size, FontWeight w, Color color,
    {double ls = 0, double lh = 1.4}) {
  return TextStyle(
    fontFamily: ur ? FdSpec.urduFont : FdSpec.latinFont,
    fontSize: size,
    fontWeight: ur ? FontWeight.w700 : w,
    color: color,
    letterSpacing: (ls == 0 || ur) ? null : ls,
    height: ur ? lh + 0.9 : lh,
  );
}

/// Press feedback: scale to 0.97 in 80 ms (HTML `.press` class).
class _Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Press({required this.child, this.onTap});

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? FdSpec.pressScale : 1.0,
        duration: FdSpec.pressDuration,
        child: widget.child,
      ),
    );
  }
}

/// Spec star glyph (from the design SVG path), painted at any size.
class _Star extends StatelessWidget {
  final double size;
  final bool filled;

  const _Star({required this.size, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StarPainter(filled: filled),
    );
  }
}

class _StarPainter extends CustomPainter {
  final bool filled;

  _StarPainter({required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(12, 2.5)
      ..lineTo(14.9, 8.6)
      ..lineTo(21.5, 9.4)
      ..lineTo(16.6, 14)
      ..lineTo(17.9, 20.6)
      ..lineTo(12, 17.3)
      ..lineTo(6.1, 20.6)
      ..lineTo(7.4, 14)
      ..lineTo(2.5, 9.4)
      ..lineTo(9.1, 8.6)
      ..close();
    final s = size.width / 24;
    final scaled = path
        .transform((Matrix4.identity()..scaleByDouble(s, s, 1.0, 1.0)).storage);
    if (filled) {
      canvas.drawPath(
          scaled, Paint()..color = FdSpec.star..style = PaintingStyle.fill);
      canvas.drawPath(
        scaled,
        Paint()
          ..color = FdSpec.star
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      canvas.drawPath(
        scaled,
        Paint()
          ..color = _unfilledStar
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Reviews for one doctor — design page-11: rating summary with bars,
/// "Rate your visit" composer / "You reviewed" state, sortable review list.
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
  String? _editingId; // review id being edited (composer prefilled)
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _startEdit(Review r) {
    setState(() {
      _editingId = r.id;
      _stars = r.rating;
      _textCtrl.text = r.text;
    });
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
      final repo = ref.read(repositoryProvider);
      if (_editingId != null) {
        // One review per person: replace the existing review using only the
        // existing repo calls (delete + add).
        await repo.deleteReview(widget.doctorId, _editingId!);
      }
      await repo.addReview(
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
        _editingId = null;
        _textCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'rev.posted'))),
      );
    } on DuplicateReviewException {
      if (!mounted) return;
      setState(() => _editingId = null);
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
      setState(() => _editingId = null);
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
      backgroundColor: FdSpec.pageBg,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 48, 10, 8),
            child: Row(
              children: [
                _Press(
                  onTap: () => Navigator.of(context).pop(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                      color: FdSpec.ink,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: FutureBuilder(
                    future: repo.getDoctor(widget.doctorId),
                    builder: (context, snap) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(ref, 'rev.title'),
                            style: _t(ur, 20, FontWeight.w800, FdSpec.ink,
                                ls: -0.2, lh: 1.15)),
                        Text(
                          snap.data?.name ?? '',
                          style: _t(ur, 13, FontWeight.w500, FdSpec.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Review>>(
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
                Review? myReview;
                if (user != null) {
                  for (final r in reviews) {
                    if (r.userId == user.uid) {
                      myReview = r;
                      break;
                    }
                  }
                }
                final editing = _editingId != null;
                return ListView(
                  padding:
                      const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  children: [
                    if (reviews.isNotEmpty) ...[
                      _summaryCard(ref, ur, reviews),
                    ],
                    if (myReview != null && !editing)
                      _reviewedCard(ref, ur, myReview)
                    else
                      _composerCard(ref, ur, topMargin: reviews.isNotEmpty),
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tr(ref, 'rev.allReviews'),
                              style: _t(ur, 17, FontWeight.w800, FdSpec.ink,
                                  lh: 1.3)),
                          _Press(
                            onTap: () => setState(
                                () => _newestFirst = !_newestFirst),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tr(ref, _newestFirst
                                      ? 'rev.newest'
                                      : 'rev.oldest'),
                                  style: _t(ur, 13, FontWeight.w700,
                                      FdSpec.primary),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down,
                                    color: FdSpec.primary, size: 13),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (sorted.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(tr(ref, 'rev.noReviews'),
                              style: _t(ur, 15, FontWeight.w400,
                                  FdSpec.muted),
                              textAlign: TextAlign.center),
                        ),
                      )
                    else
                      for (var i = 0; i < sorted.length; i++)
                        _reviewRow(
                            ref, ur, sorted[i], user?.uid, isAdmin),
                  ],
                );
              },
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FdSpec.border),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: _t(ur, 46, FontWeight.w800, FdSpec.ink,
                    ls: -1.38, lh: 1.0),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++) ...[
                    _Star(size: 15, filled: i <= avg.round()),
                    if (i < 5) const SizedBox(width: 1),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                fill(tr(ref, 'rev.count'), {'n': '${reviews.length}'}),
                style: _t(ur, 12, FontWeight.w600, FdSpec.muted),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var s = 5; s >= 1; s--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 8,
                          child: Text('$s',
                              style: _t(ur, 12, FontWeight.w700,
                                  FdSpec.muted)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: _trackBg,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: reviews.isEmpty
                                    ? 0
                                    : (counts[s] ?? 0) / reviews.length,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: FdSpec.star,
                                    borderRadius:
                                        BorderRadius.circular(3),
                                  ),
                                ),
                              ),
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

  Widget _composerCard(WidgetRef ref, bool ur, {required bool topMargin}) {
    return Container(
      margin: EdgeInsets.only(top: topMargin ? 14 : 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FdSpec.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'rev.rateYourVisit'),
              style: _t(ur, 16, FontWeight.w800, FdSpec.ink, lh: 1.3)),
          Transform.translate(
            offset: const Offset(-6, 0),
            child: Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  _Press(
                    onTap:
                        _busy ? null : () => setState(() => _stars = i),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: _Star(size: 32, filled: i <= _stars),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextField(
              controller: _textCtrl,
              maxLines: 3,
              minLines: 3,
              style: _t(ur, 15, FontWeight.w500, FdSpec.ink, lh: 1.4),
              decoration: InputDecoration(
                hintText: tr(ref, 'rev.hint'),
                hintStyle:
                    _t(ur, 15, FontWeight.w500, FdSpec.muted, lh: 1.4),
                filled: true,
                fillColor: FdSpec.pageBg,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: FdSpec.primary, width: 1.6),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(tr(ref, 'rev.onePerPerson'),
                      style: _t(ur, 12, FontWeight.w500, FdSpec.muted,
                          lh: 1.35)),
                ),
                const SizedBox(width: 12),
                _Press(
                  onTap: _busy ? null : _post,
                  child: Container(
                    height: 46,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: FdSpec.primary,
                      borderRadius: BorderRadius.circular(23),
                    ),
                    alignment: Alignment.center,
                    child: Text(tr(ref, 'rev.post'),
                        style: _t(ur, 15, FontWeight.w700,
                            Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- "you reviewed" state ----------

  Widget _reviewedCard(WidgetRef ref, bool ur, Review myReview) {
    return FutureBuilder(
      future: ref.watch(repositoryProvider).getDoctor(widget.doctorId),
      builder: (context, snap) {
        final name = snap.data?.name ?? '';
        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _reviewedBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _reviewedBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FdVerifiedBadge(size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fill(tr(ref, 'rev.youReviewed'), {'name': name}),
                      style: _t(ur, 16, FontWeight.w800, _reviewedInk,
                          lh: 1.3),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tr(ref, 'rev.reviewedNote'),
                  style:
                      _t(ur, 13, FontWeight.w500, _reviewedNote, lh: 1.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    _Press(
                      onTap: () => _startEdit(myReview),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: FdSpec.primary, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(tr(ref, 'admin.edit'),
                            style: _t(ur, 14, FontWeight.w700,
                                FdSpec.primary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Press(
                      onTap: () => _delete(myReview.id),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: FdSpec.border, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(tr(ref, 'rev.delete'),
                            style: _t(
                                ur, 14, FontWeight.w700, _deleteRed)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- review rows ----------

  static const _avatarTints = [
    (Color(0xFFF8E1EC), Color(0xFF8E2A57)),
    (Color(0xFFDDF0EA), Color(0xFF0B5446)),
    (Color(0xFFE3E9FF), Color(0xFF2B3F9E)),
    (Color(0xFFFFE6D2), Color(0xFF8A3F00)),
  ];

  Widget _reviewRow(WidgetRef ref, bool ur, Review r, String? myUid,
      bool isAdmin) {
    final tint =
        _avatarTints[r.userName.hashCode.abs() % _avatarTints.length];
    final initial = r.userName.trim().isEmpty
        ? '•'
        : r.userName.trim()[0].toUpperCase();
    final canDelete = isAdmin || (myUid != null && myUid == r.userId);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FdSpec.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(color: tint.$1, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(initial,
                    style: TextStyle(
                        fontFamily: FdSpec.latinFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tint.$2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.userName,
                        style: _t(ur, 14, FontWeight.w700, FdSpec.ink)),
                    Text(_ago(ref, r.createdAt),
                        style: _t(ur, 12, FontWeight.w500, FdSpec.muted)),
                  ],
                ),
              ),
              const _Star(size: 14),
              const SizedBox(width: 3),
              Text(
                r.rating.toDouble().toStringAsFixed(1),
                style: _t(ur, 13, FontWeight.w800, FdSpec.ink),
              ),
              if (canDelete) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: FdSpec.muted),
                  onPressed: () => _delete(r.id),
                ),
              ],
            ],
          ),
          if (r.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(r.text,
                  style: _t(ur, 14, FontWeight.w500, _bodyInk, lh: 1.5)),
            ),
        ],
      ),
    );
  }
}
