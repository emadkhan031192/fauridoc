import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/community.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';
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

/// Community Q&A — design page-12 (body-only; HomeShell owns the bottom
/// nav): title + Ask pill, filter chips, pinned amber card, question cards
/// with vote columns and doctor-answer previews.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  /// 'all' | 'city' | `spec:<name>`
  String _filter = 'all';

  void _onAsk() {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'com.loginToAsk'))),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AskSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final repo = ref.watch(repositoryProvider);
    final city = ref.watch(cityProvider);

    String? cityFilter;
    String? specFilter;
    if (_filter == 'city') {
      cityFilter = city;
    } else if (_filter.startsWith('spec:')) {
      specFilter = _filter.substring(5);
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(FdDim.page, 14, FdDim.page, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(tr(ref, 'com.title'),
                      style: FdType.display(ur,
                          size: 28, w: FontWeight.w800)),
                ),
                _askPill(ref, ur),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _chipsRow(ref, ur, repo, city),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<CommunityQuestion>>(
              stream: repo.watchQuestions(
                city: cityFilter,
                specialty: specFilter,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final questions = snap.data ?? const <CommunityQuestion>[];
                final pinned =
                    questions.where((q) => q.pinned).toList();
                final rest =
                    questions.where((q) => !q.pinned).toList();
                if (questions.isEmpty) {
                  return Center(
                    child: Text(tr(ref, 'com.noQuestions'),
                        style:
                            FdType.body(ur, color: FdColors.muted)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  itemCount: pinned.length + rest.length,
                  itemBuilder: (context, i) {
                    final q = i < pinned.length
                        ? pinned[i]
                        : rest[i - pinned.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: q.pinned
                          ? _pinnedCard(ref, ur, q)
                          : _questionCard(ref, ur, repo, q),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- header widgets ----------

  Widget _askPill(WidgetRef ref, bool ur) {
    // Spec: 44px pill, padding 0 18 0 14, 18px icon, 14/700 label.
    return _FdPress(
      onTap: _onAsk,
      child: Container(
        height: 44,
        padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
        decoration: BoxDecoration(
          color: FdColors.primary,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              tr(ref, 'com.ask'),
              style: FdType.body(ur,
                  size: 14,
                  w: FontWeight.w700,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipsRow(
      WidgetRef ref, bool ur, FauridocRepository repo, String city) {
    return StreamBuilder<List<String>>(
      stream: repo.watchSpecialties(),
      builder: (context, snap) {
        final specs = (snap.data ?? const <String>[]).take(8).toList();
        final items = <Widget>[
          _filterChip(ref, tr(ref, 'com.all'), _filter == 'all',
              () => setState(() => _filter = 'all'), dark: true),
          _filterChip(ref, city, _filter == 'city',
              () => setState(() => _filter = 'city')),
          for (final s in specs)
            _filterChip(
              ref,
              specialtyLabel(ref.watch(localeProvider), s),
              _filter == 'spec:$s',
              () => setState(() => _filter = 'spec:$s'),
            ),
        ];
        return SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: FdDim.page),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => items[i],
          ),
        );
      },
    );
  }

  /// Filter chip — spec: 36px, padding 0 14, 13/600, 1px border.
  /// Selected "All" is ink with an ink border; selected others are teal.
  Widget _filterChip(WidgetRef ref, String label, bool selected,
      VoidCallback onTap, {bool dark = false}) {
    final bg = selected
        ? (dark ? FdColors.ink : FdColors.primary)
        : Colors.white;
    return _FdPress(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? (dark ? Border.all(color: FdColors.ink) : null)
              : Border.all(color: FdColors.line),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: FdType.latin,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : FdColors.ink,
          ),
        ),
      ),
    );
  }

  // ---------- cards ----------

  Widget _pinnedCard(WidgetRef ref, bool ur, CommunityQuestion q) {
    // Spec: #FFF8EC bg, #F4D9B2 border, padding 12 12 12 6, radius 16.
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4D9B2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _voteColumn(ref, q),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                GestureDetector(
                  onTap: () => _openQuestion(q.id),
                  child: Text(q.title,
                      style: FdType.body(ur,
                              size: 16,
                              w: FontWeight.w700,
                              color: FdColors.ink)
                          .copyWith(height: FdType.height(ur, 1.3))),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tag(tr(ref, 'com.allCities')),
                    _tag(tr(ref, 'com.announcement')),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(WidgetRef ref, bool ur, FauridocRepository repo,
      CommunityQuestion q) {
    final user = ref.watch(authProvider);
    final isAdmin = (user?.isAdmin ?? false) ||
        (repo.isDemo && ref.watch(demoAdminPreviewProvider));
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FdColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _voteColumn(ref, q),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openQuestion(q.id),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(q.title,
                            style: FdType.body(ur,
                                    size: 16,
                                    w: FontWeight.w700,
                                    color: FdColors.ink)
                                .copyWith(
                                    height: FdType.height(ur, 1.3))),
                      ),
                      if (isAdmin)
                        _adminMenu(ref, repo, q),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (q.city.trim().isNotEmpty) _tag(q.city),
                    if (q.specialty.trim().isNotEmpty)
                      _tag(specialtyLabel(
                          ref.watch(localeProvider), q.specialty)),
                  ],
                ),
                StreamBuilder<List<CommunityReply>>(
                  stream: repo.watchReplies(q.id),
                  builder: (context, snap) {
                    final replies =
                        snap.data ?? const <CommunityReply>[];
                    CommunityReply? doctorReply;
                    for (final r in replies) {
                      if (r.isDoctor) {
                        doctorReply = r;
                        break;
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (doctorReply != null) ...[
                          const SizedBox(height: 6),
                          _doctorAnswer(ref, ur, doctorReply),
                        ],
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _openQuestion(q.id),
                          child: Text(
                            '${q.userName} · ${_ago(ref, q.createdAt)} · ${fill(tr(ref, 'com.replies'), {'n': '${replies.length}'})}',
                            style: FdType.body(ur,
                                size: 12,
                                w: FontWeight.w500,
                                color: FdColors.muted),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctorAnswer(WidgetRef ref, bool ur, CommunityReply r) {
    // Spec: #E4F3EF box, padding 10 12, radius 12, gap 3.
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F3EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.userName,
                    style: FdType.body(ur,
                        size: 13,
                        w: FontWeight.w700,
                        color: const Color(0xFF0B5446))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 1),
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
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(r.body,
              style: FdType.body(ur,
                      size: 13,
                      w: FontWeight.w500,
                      color: const Color(0xFF1F4A41))
                  .copyWith(height: FdType.height(ur, 1.45))),
        ],
      ),
    );
  }

  Widget _tag(String label) {
    // Spec: padding 2 9, radius 10, #EEF1F0, 12/600 #2E4744.
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

  // ---------- voting ----------

  Widget _voteColumn(WidgetRef ref, CommunityQuestion q) {
    // Spec: 44px column, 44x36 chevron buttons (22px), 15/800 score.
    final user = ref.read(authProvider);
    final myVote = user == null ? 0 : (q.votes[user.uid] ?? 0);
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _voteBtn(
            Icons.keyboard_arrow_up,
            myVote == 1,
            () => _vote(q, 1),
          ),
          Text(
            '${q.score}',
            style: TextStyle(
              fontFamily: FdType.latin,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color:
                  myVote != 0 ? FdColors.primary : FdColors.ink,
            ),
          ),
          _voteBtn(
            Icons.keyboard_arrow_down,
            myVote == -1,
            () => _vote(q, -1),
          ),
        ],
      ),
    );
  }

  Widget _voteBtn(IconData icon, bool active, VoidCallback onTap) {
    return _FdPress(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 36,
        child: Icon(
          icon,
          size: 22,
          color: active
              ? FdColors.primary
              : const Color(0xFF7B8E8A),
        ),
      ),
    );
  }

  Future<void> _vote(CommunityQuestion q, int delta) async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'com.loginToAsk'))),
      );
      return;
    }
    await ref
        .read(repositoryProvider)
        .voteQuestion(q.id, user.uid, delta);
  }

  void _openQuestion(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionDetailScreen(questionId: id),
      ),
    );
  }

  // ---------- admin ----------

  Widget _adminMenu(
      WidgetRef ref, FauridocRepository repo, CommunityQuestion q) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: FdColors.muted, size: 22),
      onSelected: (v) async {
        if (v == 'pin') {
          await repo.pinQuestion(q.id, !q.pinned);
        } else if (v == 'delete') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              content: Text(tr(ref, 'com.confirmDelete')),
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
          if (ok == true) {
            await repo.deleteQuestion(q.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr(ref, 'com.deleted'))),
              );
            }
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'pin',
          child: Text(tr(ref, q.pinned ? 'com.unpin' : 'com.pin')),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(tr(ref, 'com.delete'),
              style: const TextStyle(color: FdColors.redInk)),
        ),
      ],
    );
  }
}

/// Bottom-sheet form for asking a question.
class _AskSheet extends ConsumerStatefulWidget {
  const _AskSheet();

  @override
  ConsumerState<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends ConsumerState<_AskSheet> {
  final _qCtrl = TextEditingController();
  String? _city;
  String? _specialty;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _city = ref.read(cityProvider);
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_qCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'com.fillTitle'))),
      );
      return;
    }
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'com.loginToAsk'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).askQuestion(
            CommunityQuestion(
              id: '',
              title: _qCtrl.text.trim(),
              body: '',
              city: _city ?? ref.read(cityProvider),
              specialty: _specialty ?? '',
              userId: user.uid,
              userName: user.name,
              isDoctor: user.isDoctor,
              createdAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'com.posted'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickMoreCity(List<String> rest) async {
    final urMore = fdIsUrdu(ref.read(localeProvider));
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr(ref, 'city'),
            style: FdType.title(urMore, size: 18)),
        children: [
          for (final c in rest)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(c),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                child: Text(c,
                    style: FdType.body(urMore,
                        size: 16, color: FdColors.ink)),
              ),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _city = picked);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final repo = ref.watch(repositoryProvider);
    // Spec: padding 18 20 30, radius 24 24 0 0.
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom:
              MediaQuery.of(context).viewInsets.bottom + 30,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(tr(ref, 'com.askTitle'),
                        style: FdType.title(ur,
                            size: 20, w: FontWeight.w800)),
                  ),
                  _FdPress(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      margin:
                          const EdgeInsets.only(right: -10),
                      alignment: Alignment.center,
                      child: const Icon(Icons.close,
                          size: 22, color: FdColors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _qCtrl,
                minLines: 3,
                maxLines: 3,
                style: FdType.body(ur,
                    size: 15,
                    w: FontWeight.w500,
                    color: FdColors.ink),
                decoration: InputDecoration(
                  hintText: tr(ref, 'com.qTitleHint'),
                  hintStyle: FdType.body(ur,
                      size: 15,
                      w: FontWeight.w500,
                      color: FdColors.muted),
                  filled: true,
                  fillColor: FdColors.bg,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFD5DEDA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFD5DEDA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: FdColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(ref, 'city').toUpperCase(),
                style: FdType.label(ur,
                    size: 12,
                    w: FontWeight.w700,
                    color: FdColors.muted),
              ),
              const SizedBox(height: 6),
              StreamBuilder<List<String>>(
                stream: repo.watchCities(),
                builder: (context, snap) {
                  final cities = snap.data ?? const <String>[];
                  final shown = cities.take(3).toList();
                  final rest = cities.skip(3).toList();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in shown)
                        _sheetChip(c, _city == c,
                            () => setState(() => _city = c)),
                      if (rest.isNotEmpty)
                        _sheetChip(tr(ref, 'com.more'), rest.contains(_city),
                            () => _pickMoreCity(rest)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                tr(ref, 'specialty').toUpperCase(),
                style: FdType.label(ur,
                    size: 12,
                    w: FontWeight.w700,
                    color: FdColors.muted),
              ),
              const SizedBox(height: 6),
              StreamBuilder<List<String>>(
                stream: repo.watchSpecialties(),
                builder: (context, snap) {
                  final specs = snap.data ?? const <String>[];
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in specs)
                        _sheetChip(
                          specialtyLabel(locale, s),
                          _specialty == s,
                          () => setState(() => _specialty =
                              _specialty == s ? null : s),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _FdPress(
                onTap: _busy ? null : _submit,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FdColors.primary,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Text(
                    tr(ref, 'com.post'),
                    style: FdType.body(ur,
                        size: 16,
                        w: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetChip(String label, bool selected, VoidCallback onTap) {
    // Spec: 36px, padding 0 14, radius 18, 13/600;
    // selected = ink fill, else white with line border.
    return _FdPress(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? FdColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border:
              selected ? null : Border.all(color: FdColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: FdType.latin,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : FdColors.ink,
          ),
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
