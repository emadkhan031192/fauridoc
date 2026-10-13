import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'help_feedback_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';
import 'my_questions_screen.dart';
import 'my_reviews_screen.dart';
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
  /// Guest pressed "Continue as Guest": hide the welcome, show guest content.
  /// Reset the moment a user signs in so the flow always starts fresh.
  bool _guestDismissed = false;

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

    if (user != null && _guestDismissed) {
      // Signed in: the welcome flow is behind us — start fresh next time.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _guestDismissed = false);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: user == null
            ? (_guestDismissed
                ? _GuestDismissedBody(
                    ur: ur,
                    onSignIn: () =>
                        setState(() => _guestDismissed = false),
                    onSaved: () => _go(const _SavedDoctorsScreen()),
                    onHelp: () => _go(const HelpFeedbackScreen()),
                  )
                : _WelcomeBody(
                    onGuest: () =>
                        setState(() => _guestDismissed = true),
                    onPhone: () =>
                        _go(const AuthScreen(startWithPhone: true)),
                  ))
            : _LoggedInBody(
                ur: ur,
                user: user,
                onEdit: () => _editProfile(user),
                onAddNew: () => _go(const RegisterEntityScreen()),
                onOpenAdmin: () => _go(const AdminPanelScreen()),
                onSignOut: _signOut,
                onSaved: () => _go(const _SavedDoctorsScreen()),
                onReviews: () => _go(const MyReviewsScreen()),
                onQuestions: () => _go(const MyQuestionsScreen()),
                onHelp: () => _go(const HelpFeedbackScreen()),
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

/// `.press` from the spec: scale to 0.97 in 80 ms while pressed.
class _Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Press({required this.child, this.onTap});

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: widget.child,
      ),
    );
  }
}

/// Screen title: 28/800, letter-spacing -0.02em (spec §13).
Widget _screenTitle(bool ur, String text) => Text(
      text,
      style: TextStyle(
        fontFamily: FdType.family(ur),
        fontSize: ur ? (28) * 0.9 : (28),
        fontWeight: ur ? FontWeight.w700 : FontWeight.w800,
        letterSpacing: ur ? 0 : -0.56,
        color: FdColors.ink,
        height: FdType.height(ur, 1.2),
      ),
    );

/// Uppercase section label with trailing hairline (spec §13):
/// 12/700, letter-spacing 0.08em, muted.
Widget _capsRow(bool ur, String label) => Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: FdType.family(ur),
            fontSize: ur ? (12) * 0.9 : (12),
            fontWeight: FontWeight.w700,
            letterSpacing: ur ? 0 : 0.96,
            color: FdColors.muted,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
            child: Divider(color: FdColors.line, height: 1, thickness: 1)),
      ],
    );

/// "Fauridoc 1.0 · No ads, no data selling" — 12/500 muted, centered.
Widget _footer(WidgetRef ref, bool ur) => Center(
      child: Text(
        tr(ref, 'prof.footer'),
        style: FdType.body(ur,
            size: 12, w: FontWeight.w500, color: FdColors.muted),
        textAlign: TextAlign.center,
      ),
    );

/// Guest welcome screen: logo, welcome copy, Google sign-in, phone, guest.
/// No phone form is embedded here — phone auth lives on AuthScreen.
class _WelcomeBody extends ConsumerStatefulWidget {
  final VoidCallback onGuest;
  final VoidCallback onPhone;

  const _WelcomeBody({required this.onGuest, required this.onPhone});

  @override
  ConsumerState<_WelcomeBody> createState() => _WelcomeBodyState();
}

class _WelcomeBodyState extends ConsumerState<_WelcomeBody> {
  bool _busy = false;

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      // Success: the auth state change rebuilds the tab to the logged-in
      // view — no Navigator.pop needed, this is embedded in the tab.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(ref, 'auth.signedIn'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is UnsupportedError
              ? tr(ref, 'auth.googleNeedsFirebase')
              : e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(FdDim.page, 28, FdDim.page, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: FdLogo(size: 84)),
            const SizedBox(height: 22),
            Text(
              tr(ref, 'auth.welcome'),
              style: FdType.display(ur, size: 30),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              tr(ref, 'auth.subtitle'),
              style: FdType.body(ur, size: 15, color: FdColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: FdDim.buttonHeight,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(FdDim.pillRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(FdDim.pillRadius),
                  onTap: _busy ? null : _google,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(FdDim.pillRadius),
                      border: Border.all(
                          color: FdColors.line, width: 1.6),
                    ),
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    child: _busy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('G',
                                  style: TextStyle(
                                      fontFamily: FdType.latin,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4285F4))),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(tr(ref, 'auth.google'),
                                    style: FdType.button(ur,
                                        color: FdColors.ink),
                                    overflow:
                                        TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Divider(color: FdColors.line)),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(tr(ref, 'auth.or'),
                      style: FdType.body(ur, size: 14)),
                ),
                const Expanded(child: Divider(color: FdColors.line)),
              ],
            ),
            const SizedBox(height: 16),
            FdButton(
              label: tr(ref, 'auth.phone'),
              style: FdButtonStyle.outline,
              icon: Icons.phone_outlined,
              isUrdu: ur,
              onTap: _busy ? null : widget.onPhone,
            ),
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: _busy ? null : widget.onGuest,
                child: Text(
                  tr(ref, 'welcome.guest'),
                  style: FdType.body(ur,
                      size: 15,
                      w: FontWeight.w700,
                      color: FdColors.primary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guest dismissed state: language, saved doctors, help, a sign-in button
/// that brings the welcome back — no phone form.
class _GuestDismissedBody extends ConsumerWidget {
  final bool ur;
  final VoidCallback onSignIn;
  final VoidCallback onSaved;
  final VoidCallback onHelp;

  const _GuestDismissedBody({
    required this.ur,
    required this.onSignIn,
    required this.onSaved,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(FdDim.page, 14, FdDim.page, 16),
      children: [
        _screenTitle(ur, tr(ref, 'prof.title')),
        const SizedBox(height: 20),
        _capsRow(ur, tr(ref, 'prof.language')),
        const SizedBox(height: 4),
        _LanguageSegment(ur: ur),
        const SizedBox(height: 14),
        _MenuCard(
          ur: ur,
          rows: [
            _MenuRow(
                icon: Icons.bookmark_outline,
                label: tr(ref, 'prof.savedDoctors'),
                onTap: onSaved),
            _MenuRow(
                icon: Icons.help_outline,
                label: tr(ref, 'prof.help'),
                onTap: onHelp),
          ],
        ),
        const SizedBox(height: 16),
        FdButton(
          label: tr(ref, 'welcome.signIn'),
          isUrdu: ur,
          onTap: onSignIn,
        ),
        const SizedBox(height: 14),
        _footer(ref, ur),
      ],
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
  final VoidCallback onQuestions;
  final VoidCallback onSaved;
  final VoidCallback onReviews;
  final VoidCallback onHelp;
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
    required this.onQuestions,
    required this.onSaved,
    required this.onReviews,
    required this.onHelp,
    required this.onTapDoctor,
    required this.onTapLab,
    required this.onTapHospital,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Spec §13: the admin entry is the last row of the same menu card.
    final menuRows = <_MenuRow>[
      _MenuRow(
          icon: Icons.star_outline,
          label: tr(ref, 'prof.myReviews'),
          onTap: onReviews),
      _MenuRow(
          icon: Icons.bookmark_outline,
          label: tr(ref, 'prof.savedDoctors'),
          onTap: onSaved),
      _MenuRow(
          icon: Icons.forum_outlined,
          label: tr(ref, 'prof.myQuestions'),
          onTap: onQuestions),
      _MenuRow(
          icon: Icons.help_outline,
          label: tr(ref, 'prof.help'),
          onTap: onHelp),
      if (user.isAdmin)
        _MenuRow(
          icon: Icons.admin_panel_settings_outlined,
          label: tr(ref, 'prof.adminPanel'),
          onTap: onOpenAdmin,
          badge: tr(ref, 'prof.adminBadge'),
        ),
    ];
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(FdDim.page, 14, FdDim.page, 16),
      children: [
        _screenTitle(ur, tr(ref, 'prof.title')),
        const SizedBox(height: 16),
        _UserCard(ur: ur, user: user, onEdit: onEdit),
        const SizedBox(height: 8),
        _UidRow(ur: ur, uid: user.uid),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(tr(ref, 'prof.myListings'),
                  style:
                      FdType.title(ur, size: 17, w: FontWeight.w800)),
            ),
            _Press(
              onTap: onAddNew,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4),
                child: Text(tr(ref, 'prof.addNew'),
                    style: FdType.body(ur,
                        size: 14,
                        w: FontWeight.w700,
                        color: FdColors.primary)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MyListings(
          ur: ur,
          uid: user.uid,
          onTapDoctor: onTapDoctor,
          onTapLab: onTapLab,
          onTapHospital: onTapHospital,
        ),
        const SizedBox(height: 22),
        _capsRow(ur, tr(ref, 'prof.language')),
        const SizedBox(height: 4),
        _LanguageSegment(ur: ur),
        const SizedBox(height: 14),
        _MenuCard(ur: ur, rows: menuRows),
        const SizedBox(height: 14),
        _Press(
          onTap: onSignOut,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border:
                  Border.all(color: FdColors.line, width: 1.5),
            ),
            child: Text(tr(ref, 'prof.signOut'),
                style: FdType.body(ur,
                    size: 15,
                    w: FontWeight.w700,
                    color: const Color(0xFFA11F1F))),
          ),
        ),
        const SizedBox(height: 14),
        _footer(ref, ur),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FdColors.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: FdColors.mint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(user.name),
              style: const TextStyle(
                fontFamily: FdType.latin,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: FdColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: FdType.title(ur, size: 18, w: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                // Spec shows "number · city"; AppUser carries no city,
                // so show phone (or email) without inventing one.
                Text(
                  user.phone.isEmpty
                      ? (user.email.isEmpty ? '' : user.email)
                      : user.phone,
                  style: FdType.body(ur,
                      size: 13,
                      w: FontWeight.w500,
                      color: FdColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Press(
            onTap: onEdit,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: FdColors.bg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_outlined,
                  color: FdColors.ink, size: 20),
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

/// Tappable UID row under the user card: shows the first 12 characters,
/// copies the full UID to the clipboard on tap.
class _UidRow extends ConsumerWidget {
  final bool ur;
  final String uid;
  const _UidRow({required this.ur, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final short =
        uid.length <= 12 ? uid : '${uid.substring(0, 12)}…';
    return _Press(
      onTap: () {
        Clipboard.setData(ClipboardData(text: uid));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(ref, 'prof.copied'))));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${tr(ref, 'prof.uid')}: $short',
                style: FdType.body(ur,
                    size: 12,
                    w: FontWeight.w600,
                    color: FdColors.muted)),
            const SizedBox(width: 6),
            const Icon(Icons.copy_outlined,
                size: 14, color: FdColors.muted),
          ],
        ),
      ),
    );
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
                    tile: _InitialsTile(
                        name: d.name,
                        bg: FdColors.peach,
                        fg: FdColors.peachInk),
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

/// 44px rounded tile with initials (spec §13 listing rows): 15/800.
class _InitialsTile extends StatelessWidget {
  final String name;
  final Color bg;
  final Color fg;

  const _InitialsTile(
      {required this.name, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .replaceFirst(RegExp(r'^Dr\.\s*'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '•' : initials,
        style: TextStyle(
          fontFamily: FdType.latin,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 22),
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
        margin: const EdgeInsets.only(bottom: 8),
        child: _Press(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FdColors.line),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                tile,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: FdType.title(ur,
                              size: 15, w: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: FdType.body(ur,
                              size: 12.5,
                              w: FontWeight.w500,
                              color: FdColors.muted),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: approved
                        ? const Color(0xFFE4F3EF)
                        : const Color(0xFFFFF0DC),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    tr(ref,
                        approved ? 'prof.approved' : 'prof.pending'),
                    style: FdType.body(
                      ur,
                      size: 12,
                      w: FontWeight.w700,
                      color: approved
                          ? FdColors.primaryDark
                          : const Color(0xFF8A4B00),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// EN | اردو segmented control (spec §13): grey track, 42px halves.
class _LanguageSegment extends ConsumerWidget {
  final bool ur;
  const _LanguageSegment({required this.ur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget half(
        String label, bool labelUr, bool active, VoidCallback onTap) {
      return Expanded(
        child: _Press(
          onTap: onTap,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: active
                  ? [
                      const BoxShadow(
                        color: Color.fromRGBO(15, 42, 46, 0.14),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      )
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: FdType.body(
                labelUr,
                size: 14,
                w: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? FdColors.primary : FdColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEEC),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          half('English', false, !ur,
              () => ref.read(localeProvider.notifier).setLocale('en')),
          half('اردو', true, ur,
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
  final String? badge;
  const _MenuRow(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.badge});
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FdColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _Press(
              onTap: rows[i].onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 54),
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(rows[i].icon,
                        color: FdColors.muted, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(rows[i].label,
                          style: FdType.body(ur,
                              size: 15,
                              w: FontWeight.w600,
                              color: FdColors.ink)),
                    ),
                    if (rows[i].badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 2),
                        decoration: BoxDecoration(
                          color: FdColors.ink,
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: Text(rows[i].badge!,
                            style: const TextStyle(
                                fontFamily: FdType.latin,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Icon(Icons.chevron_right,
                        color: Color(0xFF9AA9A5), size: 16),
                  ],
                ),
              ),
            ),
            if (i < rows.length - 1)
              const Divider(
                  color: Color(0xFFEEF1F0), height: 1, thickness: 1),
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
                tile: _InitialsTile(
                    name: d.name,
                    bg: FdColors.peach,
                    fg: FdColors.peachInk),
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
