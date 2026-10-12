import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/app_user.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../utils/actions.dart';
import 'register_entity_screen.dart';

/// Admin dashboard: counts, pending approvals, entity management,
/// and editable config lists.
class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final user = ref.watch(authProvider);
    final isAdmin = (user?.isAdmin ?? false) ||
        (repo.isDemo && ref.watch(demoAdminPreviewProvider));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'adminPanel'))),
      body: isAdmin
          ? const _AdminBody()
          : Center(
              child: Text('${tr(ref, 'adminPanel')} - ${tr(ref, 'login')}'),
            ),
    );
  }
}

class _AdminBody extends ConsumerWidget {
  const _AdminBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final locale = ref.watch(localeProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<AdminCounts>(
            stream: repo.watchAdminCounts(),
            builder: (context, snap) {
              final c = snap.data ?? const AdminCounts();
              final cards = [
                (tr(ref, 'totalDoctors'), c.doctors),
                (tr(ref, 'totalLabs'), c.labs),
                (tr(ref, 'totalHospitals'), c.hospitals),
                (tr(ref, 'pendingApprovals'), c.pending),
                (tr(ref, 'totalUsers'), c.users),
                (tr(ref, 'totalReviews'), c.reviews),
              ];
              return GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final (label, count) in cards)
                    Card(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _pendingSection<Doctor>(
            ref: ref,
            titleKey: 'pendingDoctors',
            stream: repo.watchPendingDoctors(),
            titleOf: (d) => d.name,
            subtitleOf: (d) =>
                '${d.city} · ${specialtyLabel(locale, d.specialty)}',
            idOf: (d) => d.id,
            decide: (id, approve) =>
                ref.read(repositoryProvider).approveDoctor(id, approve: approve),
          ),
          _pendingSection<Lab>(
            ref: ref,
            titleKey: 'pendingLabs',
            stream: repo.watchPendingLabs(),
            titleOf: (l) => l.name,
            subtitleOf: (l) => l.city,
            idOf: (l) => l.id,
            decide: (id, approve) =>
                ref.read(repositoryProvider).approveLab(id, approve: approve),
          ),
          _pendingSection<Hospital>(
            ref: ref,
            titleKey: 'pendingHospitals',
            stream: repo.watchPendingHospitals(),
            titleOf: (h) => h.name,
            subtitleOf: (h) => h.city,
            idOf: (h) => h.id,
            decide: (id, approve) => ref
                .read(repositoryProvider)
                .approveHospital(id, approve: approve),
          ),
          const SizedBox(height: 8),
          _manageHeader(
            context,
            ref,
            'manageDoctors',
            () => const RegisterEntityScreen(kind: EntityKind.doctor),
          ),
          StreamBuilder<List<Doctor>>(
            stream: repo.watchDoctors(),
            builder: (context, snap) {
              final items = snap.data ?? const <Doctor>[];
              return Column(
                children: [
                  for (final d in items)
                    ListTile(
                      title: Text(d.name),
                      subtitle: Text(
                        '${d.city} · ${specialtyLabel(locale, d.specialty)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(
                          context,
                          () => repo.deleteDoctor(d.id),
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RegisterEntityScreen(
                            kind: EntityKind.doctor,
                            doctor: d,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          _manageHeader(
            context,
            ref,
            'manageLabs',
            () => const RegisterEntityScreen(kind: EntityKind.lab),
          ),
          StreamBuilder<List<Lab>>(
            stream: repo.watchLabs(),
            builder: (context, snap) {
              final items = snap.data ?? const <Lab>[];
              return Column(
                children: [
                  for (final l in items)
                    ListTile(
                      title: Text(l.name),
                      subtitle: Text(l.city),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(
                          context,
                          () => repo.deleteLab(l.id),
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RegisterEntityScreen(
                            kind: EntityKind.lab,
                            lab: l,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          _manageHeader(
            context,
            ref,
            'manageHospitals',
            () => const RegisterEntityScreen(kind: EntityKind.hospital),
          ),
          StreamBuilder<List<Hospital>>(
            stream: repo.watchHospitals(),
            builder: (context, snap) {
              final items = snap.data ?? const <Hospital>[];
              return Column(
                children: [
                  for (final h in items)
                    ListTile(
                      title: Text(h.name),
                      subtitle: Text(h.city),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(
                          context,
                          () => repo.deleteHospital(h.id),
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RegisterEntityScreen(
                            kind: EntityKind.hospital,
                            hospital: h,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.location_city_outlined),
            title: Text(tr(ref, 'editCities')),
            onTap: () => _editList(
              context,
              'editCities',
              repo.watchCities(),
              repo.setCities,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.medical_services_outlined),
            title: Text(tr(ref, 'editSpecialties')),
            onTap: () => _editList(
              context,
              'editSpecialties',
              repo.watchSpecialties(),
              repo.setSpecialties,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: Text(tr(ref, 'editTestCategories')),
            onTap: () => _editList(
              context,
              'editTestCategories',
              repo.watchTestCategories(),
              repo.setTestCategories,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingSection<T>({
    required WidgetRef ref,
    required String titleKey,
    required Stream<List<T>> stream,
    required String Function(T) titleOf,
    required String Function(T) subtitleOf,
    required String Function(T) idOf,
    required Future<void> Function(String id, bool approve) decide,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text(
            tr(ref, titleKey),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        StreamBuilder<List<T>>(
          stream: stream,
          builder: (context, snap) {
            final items = snap.data ?? <T>[];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                for (final e in items)
                  ListTile(
                    title: Text(titleOf(e)),
                    subtitle: Text(subtitleOf(e)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => decide(idOf(e), true),
                          child: Text(tr(ref, 'approve')),
                        ),
                        TextButton(
                          onPressed: () => decide(idOf(e), false),
                          child: Text(tr(ref, 'reject')),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _manageHeader(
    BuildContext context,
    WidgetRef ref,
    String titleKey,
    Widget Function() create,
  ) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text(
            tr(ref, titleKey),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => create()),
          ),
          icon: const Icon(Icons.add),
          label: Text(tr(ref, 'createDirectly')),
        ),
      ],
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final ok = await showDialog<bool>(
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
    if (ok == true) {
      await action();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateOf(context, 'deleted'))),
        );
      }
    }
  }

  static Future<void> _editList(
    BuildContext context,
    String titleKey,
    Stream<List<String>> stream,
    Future<void> Function(List<String>) save,
  ) async {
    final current = await stream.first;
    if (!context.mounted) return;
    final ctrl = TextEditingController(text: current.join('\n'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(translateOf(ctx, titleKey)),
        content: TextField(
          controller: ctrl,
          maxLines: 8,
          decoration: InputDecoration(
            hintText: translateOf(ctx, 'onePerLine'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(translateOf(ctx, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(translateOf(ctx, 'save')),
          ),
        ],
      ),
    );
    final text = ctrl.text;
    ctrl.dispose();
    if (ok == true) {
      final items = text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await save(items);
    }
  }
}
