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
  /// 'all' | 'city' | 'spec:<name>'
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
                      style: FdType.display(ur, size: 32)),
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: pinned.length + rest.length,
                  itemBuilder: (context, i) {
                    final q = i < pinned.length
                        ? pinned[i]
                        : rest[i - pinned.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
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
    return Material(
      color: FdColors.primary,
      borderRadius: BorderRadius.circular(FdDim.pillRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
        onTap: _onAsk,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, color: Colors.white, size: 22),
              const SizedBox(width: 6),
              Text(
                tr(ref, 'com.ask'),
                style: FdType.button(ur, size: 17),
              ),
            ],
          ),
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
          height: FdDim.chipHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: FdDim.page),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => items[i],
          ),
        );
      },
    );
  }

  /// Filter chip — dark ink when the "All" chip is selected, teal otherwise.
  Widget _filterChip(WidgetRef ref, String label, bool selected,
      VoidCallback onTap, {bool dark = false}) {
    final bg = selected
        ? (dark ? FdColors.ink : FdColors.primary)
        : Colors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(FdDim.pillRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
        onTap: onTap,
        child: Container(
          height: FdDim.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FdDim.pillRadius),
            border: selected
                ? null
                : Border.all(color: FdColors.line, width: 1.4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: FdType.latin,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : FdColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  // ---------- cards ----------

  Widget _pinnedCard(WidgetRef ref, bool ur, CommunityQuestion q) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FdColors.amberCard,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(
            color: FdColors.amberStrong.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _voteColumn(ref, q),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.push_pin,
                        size: 16, color: FdColors.amberInk),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr(ref, 'com.pinnedBy'),
                        style: FdType.body(ur,
                            size: 14,
                            w: FontWeight.w700,
                            color: FdColors.amberInk),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openQuestion(q.id),
                  child: Text(q.title,
                      style: FdType.body(ur,
                          size: 19,
                          w: FontWeight.w700,
                          color: FdColors.ink)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _tag(tr(ref, 'com.allCities')),
                    _tag(tr(ref, 'com.announcement')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${q.userName} · ${_ago(ref, q.createdAt)}',
                  style:
                      FdType.body(ur, size: 14, color: FdColors.muted),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _voteColumn(ref, q),
          const SizedBox(width: 12),
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
                                size: 19,
                                w: FontWeight.w700,
                                color: FdColors.ink)),
                      ),
                      if (isAdmin)
                        _adminMenu(ref, repo, q),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                          const SizedBox(height: 10),
                          _doctorAnswer(ref, ur, doctorReply),
                        ],
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => _openQuestion(q.id),
                          child: Text(
                            '${q.userName} · ${_ago(ref, q.createdAt)} · ${fill(tr(ref, 'com.replies'), {'n': '${replies.length}'})}',
                            style: FdType.body(ur,
                                size: 14, color: FdColors.muted),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FdColors.mint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.userName,
                    style: FdType.body(ur,
                        size: 16,
                        w: FontWeight.w700,
                        color: FdColors.ink)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: FdColors.primary,
                  borderRadius:
                      BorderRadius.circular(FdDim.pillRadius),
                ),
                child: Text(
                  tr(ref, 'com.doctor'),
                  style: FdType.body(false,
                      size: 12.5,
                      w: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.body,
              style: FdType.body(ur,
                  size: 15.5, color: FdColors.inkSoft)),
        ],
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: FdColors.bg,
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: FdType.latin,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: FdColors.inkSoft,
        ),
      ),
    );
  }

  // ---------- voting ----------

  Widget _voteColumn(WidgetRef ref, CommunityQuestion q) {
    final user = ref.read(authProvider);
    final myVote = user == null ? 0 : (q.votes[user.uid] ?? 0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _voteBtn(
          Icons.keyboard_arrow_up,
          myVote == 1,
          () => _vote(q, 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '${q.score}',
            style: TextStyle(
              fontFamily: FdType.latin,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color:
                  myVote != 0 ? FdColors.primary : FdColors.ink,
            ),
          ),
        ),
        _voteBtn(
          Icons.keyboard_arrow_down,
          myVote == -1,
          () => _vote(q, -1),
        ),
      ],
    );
  }

  Widget _voteBtn(IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 30,
          color: active ? FdColors.primary : FdColors.muted,
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
            if (context.mounted) {
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
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String? _city;
  String? _specialty;
  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
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
              title: _titleCtrl.text.trim(),
              body: _bodyCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final repo = ref.watch(repositoryProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: FdDim.page,
          right: FdDim.page,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(ref, 'com.askTitle'),
                  style: FdType.title(ur, size: 21)),
              const SizedBox(height: 14),
              TextField(
                controller: _titleCtrl,
                style:
                    FdType.body(ur, size: 16, color: FdColors.ink),
                decoration: InputDecoration(
                  hintText: tr(ref, 'com.qTitleHint'),
                  hintStyle:
                      FdType.body(ur, size: 16, color: FdColors.muted),
                  filled: true,
                  fillColor: FdColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: FdColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: FdColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyCtrl,
                maxLines: 3,
                style:
                    FdType.body(ur, size: 16, color: FdColors.ink),
                decoration: InputDecoration(
                  hintText: tr(ref, 'com.qBodyHint'),
                  hintStyle:
                      FdType.body(ur, size: 16, color: FdColors.muted),
                  filled: true,
                  fillColor: FdColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: FdColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: FdColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<List<String>>(
                      stream: repo.watchCities(),
                      builder: (context, snap) {
                        final cities =
                            snap.data ?? const <String>[];
                        final val = cities.contains(_city)
                            ? _city
                            : null;
                        return DropdownButtonFormField<String>(
                          initialValue: val,
                          decoration: InputDecoration(
                            labelText: tr(ref, 'city'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            isDense: true,
                          ),
                          items: [
                            for (final c in cities)
                              DropdownMenuItem(
                                  value: c, child: Text(c)),
                          ],
                          onChanged: (v) =>
                              setState(() => _city = v),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StreamBuilder<List<String>>(
                      stream: repo.watchSpecialties(),
                      builder: (context, snap) {
                        final specs =
                            snap.data ?? const <String>[];
                        final val = specs.contains(_specialty)
                            ? _specialty
                            : null;
                        return DropdownButtonFormField<String>(
                          initialValue: val,
                          decoration: InputDecoration(
                            labelText: tr(ref, 'specialty'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            isDense: true,
                          ),
                          items: [
                            for (final s in specs)
                              DropdownMenuItem(
                                value: s,
                                child: Text(
                                    specialtyLabel(locale, s)),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _specialty = v),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FdButton(
                  label: tr(ref, 'com.post'),
                  isUrdu: ur,
                  onTap: _busy ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
