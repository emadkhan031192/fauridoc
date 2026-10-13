import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/app_user.dart';
import '../models/community.dart';
import '../providers/providers.dart';
import '../providers/font_scale.dart';
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

/// A question with its replies, voting, and admin moderation actions —
/// restyled to the Fd design system. Logic unchanged from the original.
class QuestionDetailScreen extends ConsumerStatefulWidget {
  final String questionId;

  const QuestionDetailScreen({super.key, required this.questionId});

  @override
  ConsumerState<QuestionDetailScreen> createState() =>
      _QuestionDetailScreenState();
}

class _QuestionDetailScreenState
    extends ConsumerState<QuestionDetailScreen> {
  final _replyCtrl = TextEditingController();
  int _refresh = 0;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _voteQuestion(int delta) async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'com.loginToAsk'))),
      );
      return;
    }
    await ref
        .read(repositoryProvider)
        .voteQuestion(widget.questionId, user.uid, delta);
    setState(() => _refresh++);
  }

  Future<void> _voteReply(CommunityReply reply, int delta) async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'com.loginToAsk'))),
      );
      return;
    }
    await ref
        .read(repositoryProvider)
        .voteReply(widget.questionId, reply.id, user.uid, delta);
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'com.loginToAsk'))),
      );
      return;
    }
    await ref.read(repositoryProvider).addReply(
          CommunityReply(
            id: '',
            questionId: widget.questionId,
            body: text,
            userId: user.uid,
            userName: user.name,
            isDoctor: user.isDoctor,
            createdAt: DateTime.now(),
          ),
        );
    _replyCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'com.replyPosted'))),
      );
    }
  }

  Future<void> _togglePin(CommunityQuestion q) async {
    await ref
        .read(repositoryProvider)
        .pinQuestion(widget.questionId, !q.pinned);
    setState(() => _refresh++);
  }

  Future<void> _deleteQuestion() async {
    final ok = await _confirmDelete(context, tr(ref, 'com.confirmDelete'));
    if (ok != true) return;
    await ref.read(repositoryProvider).deleteQuestion(widget.questionId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteReply(CommunityReply reply) async {
    final ok =
        await _confirmDelete(context, tr(ref, 'com.confirmDeleteReply'));
    if (ok != true) return;
    await ref
        .read(repositoryProvider)
        .deleteReply(widget.questionId, reply.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'com.deleted'))),
      );
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, String message) {
    final ur = fdIsUrdu(ref.read(localeProvider));
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message, style: FdType.body(ur, color: FdColors.ink)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(ref, 'com.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr(ref, 'com.delete'),
                style: const TextStyle(color: FdColors.redInk)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fontScaleProvider); // Re-render when the font-size sliders change.
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
        title: Text(tr(ref, 'com.title'),
            style: FdType.title(ur, size: 22)),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<CommunityQuestion?>(
              key: ValueKey(_refresh),
              future: repo.getQuestion(widget.questionId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final q = snap.data;
                if (q == null) {
                  return Center(
                      child: Text(tr(ref, 'com.noQuestions')));
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(ref, ur, q, user, isAdmin),
                      const SizedBox(height: 20),
                      Text(
                        tr(ref, 'com.repliesTitle'),
                        style: FdType.title(ur, size: 21),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<List<CommunityReply>>(
                        stream: repo.watchReplies(widget.questionId),
                        builder: (context, rsnap) {
                          final replies =
                              rsnap.data ?? const <CommunityReply>[];
                          if (replies.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              child: Text(
                                tr(ref, 'com.noQuestions'),
                                style: FdType.body(ur,
                                    color: FdColors.muted),
                              ),
                            );
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics:
                                const NeverScrollableScrollPhysics(),
                            itemCount: replies.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) => _replyTile(
                                ref, ur, replies[i], user, isAdmin),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _composer(ref, ur, user),
        ],
      ),
    );
  }

  // ---------- vote column ----------

  Widget _voteColumn({
    required int score,
    required int myVote,
    required Future<void> Function(int delta) onVote,
  }) {
    // Spec: 44px column, 44x36 chevron buttons (22px), 15/800 score.
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FdPress(
            onTap: () => onVote(1),
            child: SizedBox(
              width: 44,
              height: 36,
              child: Icon(
                Icons.keyboard_arrow_up,
                size: 22,
                color: myVote == 1
                    ? FdColors.primary
                    : const Color(0xFF7B8E8A),
              ),
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: FdType.latin,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: myVote != 0
                  ? FdColors.primary
                  : FdColors.ink,
            ),
          ),
          _FdPress(
            onTap: () => onVote(-1),
            child: SizedBox(
              width: 44,
              height: 36,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 22,
                color: myVote == -1
                    ? FdColors.primary
                    : const Color(0xFF7B8E8A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- question header ----------

  Widget _header(WidgetRef ref, bool ur, CommunityQuestion q, AppUser? user,
      bool isAdmin) {
    final locale = ref.watch(localeProvider);
    final myVote = user == null ? 0 : (q.votes[user.uid] ?? 0);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
      decoration: BoxDecoration(
        color: q.pinned ? const Color(0xFFFFF8EC) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: q.pinned
              ? const Color(0xFFF4D9B2)
              : FdColors.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _voteColumn(
            score: q.score,
            myVote: myVote,
            onVote: _voteQuestion,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (q.pinned) ...[
                  Row(
                    children: [
                      const Icon(Icons.push_pin,
                          size: 13, color: Color(0xFF8A4B00)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          tr(ref, 'com.pinnedBy'),
                          style: FdType.body(ur,
                              size: 12,
                              w: FontWeight.w700,
                              color: const Color(0xFF8A4B00)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Text(q.title,
                    style: FdType.body(ur,
                            size: 16,
                            w: FontWeight.w700,
                            color: FdColors.ink)
                        .copyWith(height: FdType.height(ur, 1.3))),
                if (q.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(q.body,
                      style: FdType.body(ur,
                          size: 14, color: FdColors.inkSoft)),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (q.city.trim().isNotEmpty) _tag(q.city),
                    if (q.specialty.trim().isNotEmpty)
                      _tag(specialtyLabel(locale, q.specialty)),
                    if (q.isDoctor) _doctorPill(ref),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${q.userName} · ${_ago(ref, q.createdAt)}',
                  style: FdType.body(ur,
                      size: 12,
                      w: FontWeight.w500,
                      color: FdColors.muted),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  const Divider(color: FdColors.line, height: 1),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _togglePin(q),
                        child: Text(
                            tr(ref,
                                q.pinned ? 'com.unpin' : 'com.pin'),
                            style: const TextStyle(
                                color: FdColors.primary)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _deleteQuestion,
                        child: Text(tr(ref, 'com.delete'),
                            style: const TextStyle(
                                color: FdColors.redInk)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: FdType.latin,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2E4744),
        ),
      ),
    );
  }

  Widget _doctorPill(WidgetRef ref) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: FdColors.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        tr(ref, 'com.doctor'),
        style: const TextStyle(
          fontFamily: FdType.latin,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  // ---------- reply rows ----------

  static const _avatarTints = [
    (Color(0xFFFBE0E6), Color(0xFFB3261E)),
    (Color(0xFFE2F3ED), Color(0xFF0B6B5D)),
    (Color(0xFFE3EBFD), Color(0xFF3B4A9E)),
    (Color(0xFFFFF0DB), Color(0xFF8A5A00)),
  ];

  Widget _replyTile(WidgetRef ref, bool ur, CommunityReply r, AppUser? user,
      bool isAdmin) {
    final myVote = user == null ? 0 : (r.votes[user.uid] ?? 0);
    final tint =
        _avatarTints[r.userName.hashCode.abs() % _avatarTints.length];
    final initial = r.userName.trim().isEmpty
        ? '•'
        : r.userName.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FdColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: tint.$1, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(initial,
                    style: FdType.body(false,
                        size: 16, w: FontWeight.w700, color: tint.$2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(r.userName,
                              style: FdType.body(ur,
                                  size: 14,
                                  w: FontWeight.w700,
                                  color: FdColors.ink)),
                        ),
                        if (r.isDoctor) ...[
                          const SizedBox(width: 6),
                          _doctorPill(ref),
                        ],
                      ],
                    ),
                    Text(_ago(ref, r.createdAt),
                        style: FdType.body(ur,
                            size: 12, color: FdColors.muted)),
                  ],
                ),
              ),
              _voteColumn(
                score: r.score,
                myVote: myVote,
                onVote: (d) => _voteReply(r, d),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: FdColors.muted),
                  onPressed: () => _deleteReply(r),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.body,
              style:
                  FdType.body(ur, size: 14, color: FdColors.inkSoft)),
        ],
      ),
    );
  }

  // ---------- composer ----------

  Widget _composer(WidgetRef ref, bool ur, AppUser? user) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: FdColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: TextField(
                  controller: _replyCtrl,
                  style:
                      FdType.body(ur, size: 16, color: FdColors.ink),
                  decoration: InputDecoration(
                    hintText: tr(ref, 'com.replyHint'),
                    hintStyle: FdType.body(ur,
                        size: 16, color: FdColors.muted),
                    filled: true,
                    fillColor: FdColors.bg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(FdDim.pillRadius),
                      borderSide:
                          const BorderSide(color: FdColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(FdDim.pillRadius),
                      borderSide:
                          const BorderSide(color: FdColors.line),
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendReply(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: FdColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sendReply,
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.send,
                      color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spec `.press`: scale to 0.97 in 80 ms on press.
class _FdPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _FdPress({required this.child, this.onTap});

  @override
  State<_FdPress> createState() => _FdPressState();
}

class _FdPressState extends State<_FdPress> {
  double _scale = 1;

  void _set(double s) {
    if (_scale != s) setState(() => _scale = s);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(0.97),
      onTapUp: (_) => _set(1),
      onTapCancel: () => _set(1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 80),
        child: widget.child,
      ),
    );
  }
}
