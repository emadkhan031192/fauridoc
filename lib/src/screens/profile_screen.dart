import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../models/app_user.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'admin_panel_screen.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';
import 'register_entity_screen.dart';

/// Profile tab (page-13): user card, my listings, language, menu.
/// Body-only: HomeShell owns the bottom navigation.
class ProfileScreen extends ConsumerStatefulWidget {
  final bool demoMode;

  const ProfileScreen({super.key, required this.demoMode});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _go(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).signOut();
  }

  Future<void> _editProfile(AppUser user) async {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: FdColors.line,
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 16),
              Text(tr(ref, 'prof.editProfile'),
                  style: FdType.title(ur, size: 20)),
              const SizedBox(height: 16),
              _sheetField(nameCtrl, tr(ref, 'prof.name'), ur),
              const SizedBox(height: 12),
              _sheetField(phoneCtrl, tr(ref, 'prof.phone'), ur,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 18),
              FdButton(
                label: tr(ref, 'prof.save'),
                isUrdu: ur,
                onTap: () async {
                  final updated = user.copyWith(
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                  );
                  await ref.read(repositoryProvider).upsertUser(updated);
                  // Keep the auth state + demo prefs in sync.
                  ref.read(authProvider.notifier).updateCurrentUser(updated);
                  if (ref.read(authProvider.notifier).isDemoBackend) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('demo_name', updated.name);
                    await prefs.setString('demo_phone', updated.phone);
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                },
              ),
            ],
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
    if (saved == true && mounted) _snack(tr(ref, 'prof.saved'));
  }

  @override
  Widget build(BuildContext context) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final user = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: user == null
            ? _LoggedOutBody(
                ur: ur,
                onSignIn: () => _go(const AuthScreen()),
                onGuest: () =>
                    ref.read(tabIndexProvider.notifier).setTab(0),
              )
            : _LoggedInBody(
                ur: ur,
                user: user,
                onEdit: () => _editProfile(user),
                onAddNew: () => _go(const RegisterEntityScreen()),
                onOpenAdmin: () => _go(const AdminPanelScreen()),
                onSignOut: _signOut,
                onSoon: () => _snack(tr(ref, 'prof.soon')),
                onSaved: () => _go(const _SavedDoctorsScreen()),
                onTapDoctor: (d) {
                  if (user.isDoctor && user.doctorId == d.id) {
                    _go(DashboardScreen(doctorId: d.id));
                  } else {
                    _go(DoctorDetailScreen(doctorId: d.id));
                  }
                },
                onTapLab: (l) => _go(LabDetailScreen(labId: l.id)),
                onTapHospital: (h) =>
                    _go(HospitalDetailScreen(hospitalId: h.id)),
              ),
      ),
    );
  }
}

Widget _sheetField(TextEditingController ctrl, String hint, bool ur,
    {TextInputType keyboardType = TextInputType.text}) {
  return TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    style: FdType.body(ur, size: 16, color: FdColors.ink),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: FdType.body(ur, size: 16, color: FdColors.muted),
      filled: true,
      fillColor: FdColors.bg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FdDim.fieldRadius),
        borderSide: const BorderSide(color: FdColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FdDim.fieldRadius),
        borderSide: const BorderSide(color: FdColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FdDim.fieldRadius),
        borderSide: const BorderSide(color: FdColors.primary, width: 1.6),
      ),
    ),
  );
}

/// Logged-out state: centered sign-in card.
class _LoggedOutBody extends StatelessWidget {
  final bool ur;
  final VoidCallback onSignIn;
  final VoidCallback onGuest;

  const _LoggedOutBody({
    required this.ur,
    required this.onSignIn,
    required this.onGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FdDim.page),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(FdDim.cardRadius),
              border: Border.all(color: FdColors.line),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: FdColors.mintDeep,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person,
                        color: FdColors.primary, size: 44),
                  ),
                ),
                const SizedBox(height: 18),
                Text(tr(ref, 'prof.signInPrompt'),
                    style: FdType.body(ur, size: 16),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FdButton(
                    label: tr(ref, 'prof.signIn'),
                    isUrdu: ur,
                    onTap: onSignIn),
                const SizedBox(height: 12),
                FdButton(
                    label: tr(ref, 'prof.guest'),
                    style: FdButtonStyle.outline,
                    isUrdu: ur,
                    onTap: onGuest),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logged-in state: user card, listings, language, menu.
class _LoggedInBody extends ConsumerWidget {
  final bool ur;
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onAddNew;
  final VoidCallback onOpenAdmin;
  final VoidCallback onSignOut;
  final VoidCallback onSoon;
  final VoidCallback onSaved;
  final ValueChanged<Doctor> onTapDoctor;
  final ValueChanged<Lab> onTapLab;
  final ValueChanged<Hospital> onTapHospital;

  const _LoggedInBody({
    required this.ur,
    required this.user,
    required this.onEdit,
    required this.onAddNew,
    required this.onOpenAdmin,
    required this.onSignOut,
    required this.onSoon,
    required this.onSaved,
    required this.onTapDoctor,
    required this.onTapLab,
    required this.onTapHospital,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(FdDim.page, 14, FdDim.page, 28),
      children: [
        Text(tr(ref, 'prof.title'), style: FdType.display(ur, size: 34)),
        const SizedBox(height: 16),
        _UserCard(ur: ur, user: user, onEdit: onEdit),
        const SizedBox(height: 24),
        FdSectionHeader(
          title: tr(ref, 'prof.myListings'),
          actionLabel: tr(ref, 'prof.addNew'),
          onAction: onAddNew,
          isUrdu: ur,
        ),
        const SizedBox(height: 12),
        _MyListings(
          ur: ur,
          uid: user.uid,
          onTapDoctor: onTapDoctor,
          onTapLab: onTapLab,
          onTapHospital: onTapHospital,
        ),
        const SizedBox(height: 24),
        FdCapsLabel(label: tr(ref, 'prof.language'), isUrdu: ur),
        const SizedBox(height: 10),
        _LanguageSegment(ur: ur),
        const SizedBox(height: 20),
        _MenuCard(
          ur: ur,
          rows: [
            _MenuRow(
                icon: Icons.star_outline,
                label: tr(ref, 'prof.myReviews'),
                onTap: onSoon),
            _MenuRow(
                icon: Icons.bookmark_outline,
                label: tr(ref, 'prof.savedDoctors'),
                onTap: onSaved),
            _MenuRow(
                icon: Icons.forum_outlined,
                label: tr(ref, 'prof.myQuestions'),
                onTap: onSoon),
            _MenuRow(
                icon: Icons.help_outline,
                label: tr(ref, 'prof.help'),
                onTap: onSoon),
          ],
        ),
        if (user.isAdmin) ...[
          const SizedBox(height: 14),
          _MenuCard(
            ur: ur,
            rows: [
              _MenuRow(
                icon: Icons.admin_panel_settings_outlined,
                label: tr(ref, 'prof.adminPanel'),
                onTap: onOpenAdmin,
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        FdButton(
          label: tr(ref, 'prof.signOut'),
          style: FdButtonStyle.dangerOutline,
          isUrdu: ur,
          onTap: onSignOut,
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final bool ur;
  final AppUser user;
  final VoidCallback onEdit;

  const _UserCard(
      {required this.ur, required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: FdColors.mintDeep,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(user.name),
              style: const TextStyle(
                fontFamily: FdType.latin,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: FdColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: FdType.title(ur, size: 20),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  user.phone.isEmpty
                      ? (user.email.isEmpty ? '' : user.email)
                      : user.phone,
                  style: FdType.body(ur, size: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: FdColors.bg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_outlined,
                  color: FdColors.ink, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(' ').where((w) => w.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return '•';
    return parts.map((w) => w[0]).join().toUpperCase();
  }
}

/// The user's own registrations across all three entity types.
class _MyListings extends ConsumerWidget {
  final bool ur;
  final String uid;
  final ValueChanged<Doctor> onTapDoctor;
  final ValueChanged<Lab> onTapLab;
  final ValueChanged<Hospital> onTapHospital;

  const _MyListings({
    required this.ur,
    required this.uid,
    required this.onTapDoctor,
    required this.onTapLab,
    required this.onTapHospital,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    return StreamBuilder<List<Doctor>>(
      stream: repo.watchMyDoctors(uid),
      builder: (context, dSnap) => StreamBuilder<List<Lab>>(
        stream: repo.watchMyLabs(uid),
        builder: (context, lSnap) => StreamBuilder<List<Hospital>>(
          stream: repo.watchMyHospitals(uid),
          builder: (context, hSnap) {
            final doctors = dSnap.data ?? const <Doctor>[];
            final labs = lSnap.data ?? const <Lab>[];
            final hospitals = hSnap.data ?? const <Hospital>[];
            if (doctors.isEmpty &&
                labs.isEmpty &&
                hospitals.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(FdDim.cardRadius),
                  border: Border.all(color: FdColors.line),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 26),
                child: Column(
                  children: [
                    Text(tr(ref, 'prof.noListings'),
                        style: FdType.title(ur, size: 18)),
                    const SizedBox(height: 6),
                    Text(tr(ref, 'prof.noListingsSub'),
                        style: FdType.body(ur, size: 14),
                        textAlign: TextAlign.center),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final d in doctors)
                  _ListingRow(
                    ur: ur,
                    tile: FdAvatarTile(
                        name: d.name, size: 62, bg: FdColors.peach),
                    title: d.name,
                    subtitle: d.approved
                        ? '${tr(ref, 'prof.typeDoctor')} · ${specialtyLabel(ref.watch(localeProvider), d.specialty)}'
                        : '${tr(ref, 'prof.typeDoctor')} · ${fill(tr(ref, 'prof.pendingSub'), {'ago': _ago(ref, d.createdAt)})}',
                    approved: d.approved,
                    onTap: () => onTapDoctor(d),
                  ),
                for (final l in labs)
                  _ListingRow(
                    ur: ur,
                    tile: const _IconTile(
                        bg: FdColors.lavender,
                        icon: Icons.science_outlined,
                        iconColor: FdColors.lavenderInk),
                    title: l.name,
                    subtitle:
                        '${tr(ref, 'prof.typeLab')} · ${fill(tr(ref, 'prof.pendingSub'), {'ago': _ago(ref, l.createdAt)})}',
                    approved: l.approved,
                    onTap: () => onTapLab(l),
                  ),
                for (final h in hospitals)
                  _ListingRow(
                    ur: ur,
                    tile: const _IconTile(
                        bg: FdColors.redSoft,
                        icon: Icons.add,
                        iconColor: FdColors.redInk),
                    title: h.name,
                    subtitle:
                        '${tr(ref, 'prof.typeHospital')} · ${fill(tr(ref, 'prof.pendingSub'), {'ago': _ago(ref, h.createdAt)})}',
                    approved: h.approved,
                    onTap: () => onTapHospital(h),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _ago(WidgetRef ref, DateTime dt) {
    final days = DateTime.now().difference(dt).inDays;
    if (days <= 0) return tr(ref, 'admin.today');
    if (days == 1) return tr(ref, 'admin.yesterday');
    return fill(tr(ref, 'admin.daysAgo'), {'n': '$days'});
  }
}

class _IconTile extends StatelessWidget {
  final Color bg;
  final IconData icon;
  final Color iconColor;

  const _IconTile(
      {required this.bg, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: iconColor, size: 30),
    );
  }
}

class _ListingRow extends StatelessWidget {
  final bool ur;
  final Widget tile;
  final String title;
  final String subtitle;
  final bool approved;
  final VoidCallback onTap;

  const _ListingRow({
    required this.ur,
    required this.tile,
    required this.title,
    required this.subtitle,
    required this.approved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(FdDim.cardRadius),
          border: Border.all(color: FdColors.line),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(FdDim.cardRadius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  tile,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: FdType.title(ur, size: 18),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(subtitle,
                            style: FdType.body(ur, size: 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: approved
                          ? FdColors.mintDeep
                          : FdColors.amberSoft,
                      borderRadius:
                          BorderRadius.circular(FdDim.pillRadius),
                    ),
                    child: Text(
                      tr(ref,
                          approved ? 'prof.approved' : 'prof.pending'),
                      style: FdType.body(
                        ur,
                        size: 13,
                        w: FontWeight.w700,
                        color: approved
                            ? FdColors.primary
                            : FdColors.amberInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// EN | اردو segmented control on a mint track.
class _LanguageSegment extends ConsumerWidget {
  final bool ur;
  const _LanguageSegment({required this.ur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget half(String label, bool active, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: FdType.body(
                label == 'اردو',
                size: 16,
                w: FontWeight.w700,
                color: active ? FdColors.primary : FdColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: FdColors.mint,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          half('English', !ur,
              () => ref.read(localeProvider.notifier).setLocale('en')),
          half('اردو', ur,
              () => ref.read(localeProvider.notifier).setLocale('ur')),
        ],
      ),
    );
  }
}

class _MenuRow {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuRow(
      {required this.icon, required this.label, required this.onTap});
}

class _MenuCard extends StatelessWidget {
  final bool ur;
  final List<_MenuRow> rows;
  const _MenuCard({required this.ur, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: rows[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    children: [
                      Icon(rows[i].icon,
                          color: FdColors.muted, size: 26),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(rows[i].label,
                            style: FdType.body(ur,
                                size: 16,
                                w: FontWeight.w500,
                                color: FdColors.ink)),
                      ),
                      const Icon(Icons.chevron_right,
                          color: FdColors.muted, size: 24),
                    ],
                  ),
                ),
              ),
            ),
            if (i < rows.length - 1)
              const Divider(color: FdColors.line, height: 1),
          ],
        ],
      ),
    );
  }
}

/// Saved doctors, persisted as id list under 'saved_doctors'.
class _SavedDoctorsScreen extends ConsumerWidget {
  const _SavedDoctorsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    return Scaffold(
      appBar: AppBar(
          title: Text(tr(ref, 'prof.savedDoctors'),
              style: FdType.title(ur, size: 22))),
      body: FutureBuilder<List<Doctor>>(
        future: _loadSaved(ref),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final doctors = snap.data ?? const <Doctor>[];
          if (doctors.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(tr(ref, 'prof.savedEmpty'),
                    style: FdType.body(ur, size: 15),
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(FdDim.page),
            itemCount: doctors.length,
            itemBuilder: (context, i) {
              final d = doctors[i];
              return _ListingRow(
                ur: ur,
                tile: FdAvatarTile(
                    name: d.name, size: 62, bg: FdColors.peach),
                title: d.name,
                subtitle:
                    '${tr(ref, 'prof.typeDoctor')} · ${specialtyLabel(ref.watch(localeProvider), d.specialty)}',
                approved: d.approved,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            DoctorDetailScreen(doctorId: d.id))),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Doctor>> _loadSaved(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('saved_doctors') ?? const [];
    final repo = ref.read(repositoryProvider);
    final out = <Doctor>[];
    for (final id in ids) {
      final d = await repo.getDoctor(id);
      if (d != null) out.add(d);
    }
    return out;
  }
}
