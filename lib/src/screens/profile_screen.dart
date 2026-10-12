import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'admin_panel_screen.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';
import 'manage_entity_screen.dart';
import 'register_entity_screen.dart';
import 'settings_screen.dart';

/// Profile tab: login view for guests, dashboard for signed-in users.
class ProfileScreen extends ConsumerWidget {
  final bool demoMode;

  const ProfileScreen({super.key, required this.demoMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null) return _LoginForm(demoMode: demoMode);
    final showAdmin = user.isAdmin ||
        (demoMode && ref.watch(demoAdminPreviewProvider));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'navProfile'))),
      body: ListView(
        children: [
          ListTile(
            leading: EntityAvatar(name: user.name, radius: 24),
            title: Text(fill(tr(ref, 'hello'), {'name': user.name})),
            subtitle: Text(
              user.email.isNotEmpty ? user.email : user.phone,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.medical_services_outlined),
            title: Text(tr(ref, 'registerDoctor')),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const RegisterEntityScreen(kind: EntityKind.doctor),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: Text(tr(ref, 'registerLab')),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const RegisterEntityScreen(kind: EntityKind.lab),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.local_hospital_outlined),
            title: Text(tr(ref, 'registerHospital')),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const RegisterEntityScreen(kind: EntityKind.hospital),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: Text(tr(ref, 'myListings')),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyListingsScreen()),
            ),
          ),
          if (user.isDoctor && user.doctorId != null)
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: Text(tr(ref, 'doctorStats')),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ManageEntityScreen(doctorId: user.doctorId!),
                ),
              ),
            ),
          if (showAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(tr(ref, 'adminPanel')),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(tr(ref, 'settings')),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(demoMode: demoMode),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: FauridocTheme.emergencyRed),
            title: Text(
              tr(ref, 'logout'),
              style: const TextStyle(color: FauridocTheme.emergencyRed),
            ),
            onTap: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}

/// Sign-in / registration form (demo or Firebase, depending on [demoMode]).
class _LoginForm extends ConsumerStatefulWidget {
  final bool demoMode;

  const _LoginForm({required this.demoMode});

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(ref, 'loginFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoogle = ref.read(authProvider.notifier).canUseGoogle;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'login'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            tr(ref, 'login'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(ref, 'loginSubtitle'),
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          if (widget.demoMode) ...[
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: tr(ref, 'yourName')),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: InputDecoration(labelText: tr(ref, 'phoneNumber')),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr(ref, 'fillAllFields')),
                          ),
                        );
                        return;
                      }
                      _run(
                        () => ref.read(authProvider.notifier).signInDemo(
                              _nameCtrl.text.trim(),
                              _phoneCtrl.text.trim(),
                            ),
                      );
                    },
              child: Text(tr(ref, 'signIn')),
            ),
          ] else ...[
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: tr(ref, 'yourName')),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(labelText: tr(ref, 'email')),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              decoration: InputDecoration(labelText: tr(ref, 'password')),
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => ref
                            .read(authProvider.notifier)
                            .signInWithEmail(
                              _emailCtrl.text.trim(),
                              _passwordCtrl.text,
                            ),
                      ),
              child: Text(tr(ref, 'signIn')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_nameCtrl.text.trim().isEmpty ||
                          _emailCtrl.text.trim().isEmpty ||
                          _passwordCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr(ref, 'fillAllFields')),
                          ),
                        );
                        return;
                      }
                      _run(
                        () => ref
                            .read(authProvider.notifier)
                            .registerWithEmail(
                              _emailCtrl.text.trim(),
                              _passwordCtrl.text,
                              _nameCtrl.text.trim(),
                            ),
                      );
                    },
              child: Text(tr(ref, 'createAccount')),
            ),
            if (canGoogle) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                          () => ref
                              .read(authProvider.notifier)
                              .signInWithGoogle(),
                        ),
                icon: const Icon(Icons.g_mobiledata),
                label: Text(tr(ref, 'signInGoogle')),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.read(tabIndexProvider.notifier).setTab(0),
              child: Text(tr(ref, 'continueAsGuest')),
            ),
          ],
        ],
      ),
    );
  }
}

/// The user's own registrations, with pending-approval pills.
class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final user = ref.watch(authProvider);
    final locale = ref.watch(localeProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(ref, 'myListings'))),
        body: Center(child: Text(tr(ref, 'login'))),
      );
    }
    Widget pendingPill(bool approved) => approved
        ? const SizedBox.shrink()
        : Pill(
            label: tr(ref, 'pendingApprovals'),
            color: FauridocTheme.starAmber,
            textColor: FauridocTheme.ink,
          );
    void push(Widget screen) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => screen),
        );
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'myListings'))),
      body: ListView(
        children: [
          _sectionHeader(ref, 'registerDoctor'),
          StreamBuilder<List<Doctor>>(
            stream: repo.watchMyDoctors(user.uid),
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
                      trailing: pendingPill(d.approved),
                      onTap: () => push(
                        (user.isDoctor && user.doctorId == d.id)
                            ? ManageEntityScreen(doctorId: d.id)
                            : DoctorDetailScreen(doctorId: d.id),
                      ),
                    ),
                ],
              );
            },
          ),
          _sectionHeader(ref, 'registerLab'),
          StreamBuilder<List<Lab>>(
            stream: repo.watchMyLabs(user.uid),
            builder: (context, snap) {
              final items = snap.data ?? const <Lab>[];
              return Column(
                children: [
                  for (final l in items)
                    ListTile(
                      title: Text(l.name),
                      subtitle: Text(
                        '${l.city} · ${l.tests.length} ${tr(ref, 'testsOffered')}',
                      ),
                      trailing: pendingPill(l.approved),
                      onTap: () => push(LabDetailScreen(labId: l.id)),
                    ),
                ],
              );
            },
          ),
          _sectionHeader(ref, 'registerHospital'),
          StreamBuilder<List<Hospital>>(
            stream: repo.watchMyHospitals(user.uid),
            builder: (context, snap) {
              final items = snap.data ?? const <Hospital>[];
              return Column(
                children: [
                  for (final h in items)
                    ListTile(
                      title: Text(h.name),
                      subtitle: Text(h.city),
                      trailing: pendingPill(h.approved),
                      onTap: () => push(HospitalDetailScreen(hospitalId: h.id)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(WidgetRef ref, String key) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        tr(ref, key),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
