import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor.dart';
import '../providers/providers.dart';
import 'doctor_detail_screen.dart';
import 'register_entity_screen.dart';

/// A doctor's own dashboard: weekly stats, edit, leave mode, preview.
class ManageEntityScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const ManageEntityScreen({super.key, required this.doctorId});

  @override
  ConsumerState<ManageEntityScreen> createState() => _ManageEntityScreenState();
}

class _ManageEntityScreenState extends ConsumerState<ManageEntityScreen> {
  final _leaveCtrl = TextEditingController();
  bool _leaveInit = false;
  int _refresh = 0;

  @override
  void dispose() {
    _leaveCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLeave() async {
    final repo = ref.read(repositoryProvider);
    final d = await repo.getDoctor(widget.doctorId);
    if (d == null || !mounted) return;
    final v = _leaveCtrl.text.trim();
    await repo.updateDoctor(d.copyWith(leaveTill: v.isEmpty ? d.leaveTill : v));
    setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'doctorStats'))),
      body: FutureBuilder<Doctor?>(
        key: ValueKey(_refresh),
        future: repo.getDoctor(widget.doctorId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data;
          if (d == null) return Center(child: Text(tr(ref, 'error')));
          if (!_leaveInit) {
            _leaveCtrl.text = d.leaveTill ?? '';
            _leaveInit = true;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                d.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, int>>(
                future: repo.getWeeklyStats(widget.doctorId),
                builder: (context, ssnap) {
                  final stats = ssnap.data ?? const <String, int>{};
                  final views = stats['views'] ?? 0;
                  final clicks = stats['whatsapp'] ?? 0;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '$views ${tr(ref, 'profileViews')}, '
                        '$clicks ${tr(ref, 'whatsappClicks')} '
                        '${tr(ref, 'thisWeek')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RegisterEntityScreen(
                      kind: EntityKind.doctor,
                      doctor: d,
                    ),
                  ),
                ),
                icon: const Icon(Icons.edit),
                label: Text(tr(ref, 'edit')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _leaveCtrl,
                decoration: InputDecoration(
                  labelText: tr(ref, 'leaveTillHint'),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _saveLeave,
                child: Text(tr(ref, 'save')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        DoctorDetailScreen(doctorId: widget.doctorId),
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined),
                // No 'preview' l10n key exists; falls back to the key text.
                label: Text(tr(ref, 'preview')),
              ),
            ],
          );
        },
      ),
    );
  }
}
