import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/community.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'question_detail_screen.dart';

/// Community Q&A: filterable question list + ask-question FAB.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String? _cityFilter;
  String? _specialtyFilter;

  void _onAsk() {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'loginToAsk'))),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AskQuestionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'navCommunity'))),
      body: Column(
        children: [
          _filterRow(),
          Expanded(
            child: StreamBuilder<List<CommunityQuestion>>(
              stream: repo.watchQuestions(
                city: _cityFilter,
                specialty: _specialtyFilter,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final questions = snap.data ?? const <CommunityQuestion>[];
                if (questions.isEmpty) {
                  return Center(child: Text(tr(ref, 'noQuestions')));
                }
                return ListView.builder(
                  itemCount: questions.length,
                  itemBuilder: (context, i) =>
                      _questionTile(questions[i], locale, repo),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAsk,
        icon: const Icon(Icons.add),
        label: Text(tr(ref, 'askQuestion')),
      ),
    );
  }

  Widget _filterRow() {
    final repo = ref.watch(repositoryProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: repo.watchCities(),
              builder: (context, snap) {
                final cities = snap.data ?? const <String>[];
                return DropdownButtonFormField<String?>(
                  initialValue: _cityFilter,
                  decoration: InputDecoration(
                    labelText: tr(ref, 'city'),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(tr(ref, 'allCities')),
                    ),
                    for (final c in cities)
                      DropdownMenuItem<String?>(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _cityFilter = v),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: repo.watchSpecialties(),
              builder: (context, snap) {
                final specialties = snap.data ?? const <String>[];
                return DropdownButtonFormField<String?>(
                  initialValue: _specialtyFilter,
                  decoration: InputDecoration(
                    labelText: tr(ref, 'specialty'),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(tr(ref, 'allSpecialties')),
                    ),
                    for (final s in specialties)
                      DropdownMenuItem<String?>(
                        value: s,
                        child: Text(specialtyLabel(ref.watch(localeProvider), s)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _specialtyFilter = v),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionTile(
    CommunityQuestion q,
    String locale,
    FauridocRepository repo,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuestionDetailScreen(questionId: q.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (q.pinned) ...[
                    const Icon(
                      Icons.push_pin,
                      size: 16,
                      color: FauridocTheme.teal,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      q.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.thumb_up_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${q.score}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 16),
                  StreamBuilder<List<CommunityReply>>(
                    stream: repo.watchReplies(q.id),
                    builder: (context, snap) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text('${snap.data?.length ?? 0}'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    q.userName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Form for posting a new community question.
class AskQuestionScreen extends ConsumerStatefulWidget {
  const AskQuestionScreen({super.key});

  @override
  ConsumerState<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends ConsumerState<AskQuestionScreen> {
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
        SnackBar(content: Text(tr(ref, 'fillAllFields'))),
      );
      return;
    }
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'loginToAsk'))),
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
              city: _city ?? '',
              specialty: _specialty ?? '',
              userId: user.uid,
              userName: user.name,
              isDoctor: user.isDoctor,
              createdAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'questionPosted'))),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'askQuestion'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(labelText: tr(ref, 'questionTitle')),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            decoration: InputDecoration(labelText: tr(ref, 'questionDetails')),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<String>>(
            stream: repo.watchCities(),
            builder: (context, snap) {
              final cities = snap.data ?? const <String>[];
              return DropdownButtonFormField<String>(
                initialValue: cities.contains(_city) ? _city : null,
                decoration: InputDecoration(labelText: tr(ref, 'city')),
                items: [
                  for (final c in cities)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _city = v),
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<String>>(
            stream: repo.watchSpecialties(),
            builder: (context, snap) {
              final specialties = snap.data ?? const <String>[];
              return DropdownButtonFormField<String>(
                initialValue: specialties.contains(_specialty) ? _specialty : null,
                decoration: InputDecoration(labelText: tr(ref, 'specialty')),
                items: [
                  for (final s in specialties)
                    DropdownMenuItem(
                      value: s,
                      child: Text(specialtyLabel(locale, s)),
                    ),
                ],
                onChanged: (v) => setState(() => _specialty = v),
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(tr(ref, 'post')),
          ),
        ],
      ),
    );
  }
}
