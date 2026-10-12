import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/app_user.dart';
import '../models/community.dart';
import '../providers/providers.dart';
import '../utils/actions.dart';
import '../widgets/theme.dart';

/// A question with its replies, voting, and admin moderation actions.
class QuestionDetailScreen extends ConsumerStatefulWidget {
  final String questionId;

  const QuestionDetailScreen({super.key, required this.questionId});

  @override
  ConsumerState<QuestionDetailScreen> createState() =>
      _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> {
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
        SnackBar(content: Text(tr(ref, 'loginToAsk'))),
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
        SnackBar(content: Text(tr(ref, 'loginToAsk'))),
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
        SnackBar(content: Text(tr(ref, 'loginToAsk'))),
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
        SnackBar(content: Text(tr(ref, 'replyPosted'))),
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
    final ok = await _confirmDelete(context);
    if (ok != true) return;
    await ref.read(repositoryProvider).deleteQuestion(widget.questionId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteReply(CommunityReply reply) async {
    final ok = await _confirmDelete(context);
    if (ok != true) return;
    await ref
        .read(repositoryProvider)
        .deleteReply(widget.questionId, reply.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'deleted'))),
      );
    }
  }

  static Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(translateOf(ctx, 'confirmDelete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(translateOf(ctx, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(translateOf(ctx, 'delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final user = ref.watch(authProvider);
    final isAdmin = (user?.isAdmin ?? false) ||
        (repo.isDemo && ref.watch(demoAdminPreviewProvider));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'navCommunity'))),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<CommunityQuestion?>(
              key: ValueKey(_refresh),
              future: repo.getQuestion(widget.questionId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final q = snap.data;
                if (q == null) {
                  return Center(child: Text(tr(ref, 'noQuestions')));
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(q, user, isAdmin),
                      const SizedBox(height: 16),
                      Text(
                        tr(ref, 'replies'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<CommunityReply>>(
                        stream: repo.watchReplies(widget.questionId),
                        builder: (context, rsnap) {
                          final replies =
                              rsnap.data ?? const <CommunityReply>[];
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: replies.length,
                            itemBuilder: (context, i) =>
                                _replyTile(replies[i], user, isAdmin),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _composer(user),
        ],
      ),
    );
  }

  Widget _voteRow({
    required int score,
    required int myVote,
    required Future<void> Function(int delta) onVote,
    double iconSize = 20,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.thumb_up),
          iconSize: iconSize,
          color: myVote == 1 ? FauridocTheme.teal : Colors.grey,
          onPressed: () => onVote(1),
        ),
        Text(
          '$score',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        IconButton(
          icon: const Icon(Icons.thumb_down),
          iconSize: iconSize,
          color: myVote == -1 ? FauridocTheme.teal : Colors.grey,
          onPressed: () => onVote(-1),
        ),
      ],
    );
  }

  Widget _header(CommunityQuestion q, AppUser? user, bool isAdmin) {
    final locale = ref.watch(localeProvider);
    final myVote = user == null ? 0 : (q.votes[user.uid] ?? 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (q.pinned) ...[
                  const Icon(
                    Icons.push_pin,
                    size: 18,
                    color: FauridocTheme.teal,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    q.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (q.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(q.body),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${q.city} · ${specialtyLabel(locale, q.specialty)}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
                if (q.isDoctor) Pill(label: tr(ref, 'doctorBadge')),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  q.userName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const Spacer(),
                _voteRow(
                  score: q.score,
                  myVote: myVote,
                  onVote: _voteQuestion,
                ),
              ],
            ),
            if (isAdmin) ...[
              const Divider(),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _togglePin(q),
                    child: Text(tr(ref, q.pinned ? 'unpin' : 'pin')),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _deleteQuestion,
                    child: Text(
                      tr(ref, 'delete'),
                      style: const TextStyle(
                        color: FauridocTheme.emergencyRed,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _replyTile(CommunityReply r, AppUser? user, bool isAdmin) {
    final myVote = user == null ? 0 : (r.votes[user.uid] ?? 0);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.body),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  r.userName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 8),
                if (r.isDoctor) Pill(label: tr(ref, 'doctorBadge')),
                const Spacer(),
                _voteRow(
                  score: r.score,
                  myVote: myVote,
                  onVote: (d) => _voteReply(r, d),
                  iconSize: 16,
                ),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: FauridocTheme.emergencyRed,
                    ),
                    onPressed: () => _deleteReply(r),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(AppUser? user) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyCtrl,
                decoration: InputDecoration(
                  hintText: tr(ref, 'replyHint'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendReply(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, color: FauridocTheme.teal),
              onPressed: _sendReply,
            ),
          ],
        ),
      ),
    );
  }
}
