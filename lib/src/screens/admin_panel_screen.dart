import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../l10n/strings.dart';
import '../data/firestore_repository.dart';
import '../data/seed_loader.dart';
import '../models/app_user.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'manage_entity_screen.dart';

/// Admin panel (page-16): live counts, pending approvals with
/// approve/reject, full CRUD over all records, editable config lists.
/// Guarded by the admin flag (or the demo admin-preview toggle).
class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final repo = ref.watch(repositoryProvider);
    final user = ref.watch(authProvider);
    final isAdmin = (user?.isAdmin ?? false) ||
        (repo.isDemo && ref.watch(demoAdminPreviewProvider));

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(tr(ref, 'admin.adminOnly'),
                style: FdType.body(ur, size: 16),
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _Header(
              ur: ur,
              title: tr(ref, 'admin.title'),
              subtitle: tr(ref, 'admin.liveCounts')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  FdDim.page, 6, FdDim.page, 24),
              children: [
                _CountsGrid(ur: ur),
                const SizedBox(height: 22),
                _PendingSection(ur: ur),
                const SizedBox(height: 24),
                _SearchSection<Doctor>(
                  ur: ur,
                  title: tr(ref, 'admin.allDoctors'),
                  stream: repo.watchDoctors,
                  nameOf: (d) => d.name,
                  subOf: (d) =>
                      '${specialtyLabel(ref.watch(localeProvider), d.specialty)} · ${d.city}',
                  tileOf: (d) => FdAvatarTile(
                      name: d.name, size: 54, bg: FdColors.peach),
                  onEdit: (d) => _goManage(context, doctor: d),
                  onDelete: (d) => repo.deleteDoctor(d.id),
                  onAdd: () => _goManage(context),
                  addLabel: tr(ref, 'admin.addDoctor'),
                ),
                const SizedBox(height: 26),
                _SearchSection<Lab>(
                  ur: ur,
                  title: tr(ref, 'admin.allLabs'),
                  stream: repo.watchLabs,
                  nameOf: (l) => l.name,
                  subOf: (l) => l.city,
                  tileOf: (_) => const _TileIcon(
                bg: FdColors.lavender,
                icon: Icons.science_outlined,
                iconColor: FdColors.lavenderInk),
                  onEdit: (l) => _goManage(context, lab: l),
                  onDelete: (l) => repo.deleteLab(l.id),
                  onAdd: () => _goManage(context),
                  addLabel: tr(ref, 'admin.addLab'),
                ),
                const SizedBox(height: 26),
                _SearchSection<Hospital>(
                  ur: ur,
                  title: tr(ref, 'admin.allHospitals'),
                  stream: repo.watchHospitals,
                  nameOf: (h) => h.name,
                  subOf: (h) => h.city,
                  tileOf: (_) => const _TileIcon(
                bg: FdColors.redSoft,
                icon: Icons.add,
                iconColor: FdColors.redInk),
                  onEdit: (h) => _goManage(context, hospital: h),
                  onDelete: (h) => repo.deleteHospital(h.id),
                  onAdd: () => _goManage(context),
                  addLabel: tr(ref, 'admin.addHospital'),
                ),
                const SizedBox(height: 24),
                Text(tr(ref, 'admin.manageLists'),
              style: _sectionTitle(ur)),
                const SizedBox(height: 12),
                _ListEditor(
                  ur: ur,
                  title: tr(ref, 'admin.cities'),
                  watch: repo.watchCities,
                  save: repo.setCities,
                ),
                const SizedBox(height: 12),
                _ListEditor(
                  ur: ur,
                  title: tr(ref, 'admin.specialties'),
                  watch: repo.watchSpecialties,
                  save: repo.setSpecialties,
                ),
                const SizedBox(height: 12),
                _ListEditor(
                  ur: ur,
                  title: tr(ref, 'admin.testCategories'),
                  watch: repo.watchTestCategories,
                  save: repo.setTestCategories,
                ),
                if (!repo.isDemo) ...[
                  const SizedBox(height: 26),
                  _SeedImportCard(ur: ur),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goManage(BuildContext context,
      {Doctor? doctor, Lab? lab, Hospital? hospital}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ManageEntityScreen(
            doctor: doctor, lab: lab, hospital: hospital)));
  }
}

String _commas(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _ago(WidgetRef ref, DateTime dt) {
  final days = DateTime.now().difference(dt).inDays;
  if (days <= 0) return tr(ref, 'admin.today');
  if (days == 1) return tr(ref, 'admin.yesterday');
  return fill(tr(ref, 'admin.daysAgo'), {'n': '$days'});
}

/// Spec section titles: 17/800 ink.
TextStyle _sectionTitle(bool ur) => TextStyle(
      fontFamily: FdType.family(ur),
      fontSize: ur ? (17) * 0.9 : (17),
      fontWeight: FontWeight.w800,
      color: FdColors.ink,
      height: FdType.height(ur, 1.3),
    );

/// 3x2 live-count tiles (spec: 22/800 values, 12/600 labels, gap 8).
class _CountsGrid extends ConsumerWidget {
  final bool ur;
  const _CountsGrid({required this.ur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<AdminCounts>(
      stream: ref.watch(repositoryProvider).watchAdminCounts(),
      builder: (context, snap) {
        final c = snap.data ?? const AdminCounts();
        final tiles = [
          _CountTile(
              value: _commas(c.doctors),
              label: tr(ref, 'admin.doctors'),
              ur: ur),
          _CountTile(
              value: _commas(c.labs),
              label: tr(ref, 'admin.labs'),
              ur: ur),
          _CountTile(
              value: _commas(c.hospitals),
              label: tr(ref, 'admin.hospitals'),
              ur: ur),
          _CountTile(
              value: _commas(c.pending),
              label: tr(ref, 'admin.pending'),
              ur: ur,
              highlight: true),
          _CountTile(
              value: _commas(c.users),
              label: tr(ref, 'admin.users'),
              ur: ur),
          _CountTile(
              value: _commas(c.reviews),
              label: tr(ref, 'admin.reviews'),
              ur: ur),
        ];
        Widget row(int from) => Row(
              children: [
                for (var i = from; i < from + 3; i++) ...[
                  if (i > from) const SizedBox(width: 8),
                  Expanded(child: tiles[i]),
                ],
              ],
            );
        return Column(
          children: [
            row(0),
            const SizedBox(height: 8),
            row(3),
          ],
        );
      },
    );
  }
}

class _CountTile extends StatelessWidget {
  final String value;
  final String label;
  final bool ur;
  final bool highlight;

  const _CountTile({
    required this.value,
    required this.label,
    required this.ur,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlight ? _pendingBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: highlight ? _pendingBorder : FdColors.line),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                fontFamily: FdType.latin,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.44,
                color:
                    highlight ? _amberInk : FdColors.ink,
                height: 1.15,
              ),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: FdType.body(
                ur,
                size: 12,
                w: FontWeight.w600,
                color:
                    highlight ? _amberInk : FdColors.muted,
              ),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// Spec-only colours (not in FdSpec): pending tile + amber ink,
// reject button border/red.
const _pendingBg = Color(0xFFFFF0DC);
const _pendingBorder = Color(0xFFF4D9B2);
const _amberInk = Color(0xFF8A4B00);
const _rejectBorder = Color(0xFFE3B6B2);
const _rejectRed = Color(0xFFA11F1F);

/// Spec back bar: 44px back chevron + 20/800 title + 13/500 subtitle.
class _Header extends StatelessWidget {
  final bool ur;
  final String title;
  final String? subtitle;

  const _Header(
      {required this.ur, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final rtl =
        Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 48, 10, 8),
      child: Row(
        children: [
          _PressScale(
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                rtl ? Icons.chevron_right : Icons.chevron_left,
                color: FdColors.ink,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: FdType.family(ur),
                    fontSize: ur ? (20) * 0.9 : (20),
                    fontWeight: FontWeight.w800,
                    letterSpacing: ur ? 0 : -0.2,
                    color: FdColors.ink,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: FdType.body(ur,
                        size: 13,
                        w: FontWeight.w500,
                        color: FdColors.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Press feedback: scale to 0.97 in 80 ms (spec `.press` class).
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressScale({required this.child, this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp:
          widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? FdSpec.pressScale : 1.0,
        duration: FdSpec.pressDuration,
        child: widget.child,
      ),
    );
  }
}

enum _PendingKind { doctor, lab, hospital }

class _PendingItem {
  final _PendingKind kind;
  final String id;
  final String name;
  final String city;
  final String sub;
  final DateTime createdAt;
  const _PendingItem({
    required this.kind,
    required this.id,
    required this.name,
    required this.city,
    required this.sub,
    required this.createdAt,
  });
}

/// Pending approval cards with Approve / Reject / detail.
class _PendingSection extends ConsumerWidget {
  final bool ur;
  const _PendingSection({required this.ur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    return StreamBuilder<List<Doctor>>(
      stream: repo.watchPendingDoctors(),
      builder: (context, dSnap) => StreamBuilder<List<Lab>>(
        stream: repo.watchPendingLabs(),
        builder: (context, lSnap) => StreamBuilder<List<Hospital>>(
          stream: repo.watchPendingHospitals(),
          builder: (context, hSnap) {
            final items = <_PendingItem>[
              for (final d in (dSnap.data ?? const <Doctor>[]))
                _PendingItem(
                  kind: _PendingKind.doctor,
                  id: d.id,
                  name: d.name,
                  city: d.city,
                  sub: d.specialty,
                  createdAt: d.createdAt,
                ),
              for (final l in (lSnap.data ?? const <Lab>[]))
                _PendingItem(
                  kind: _PendingKind.lab,
                  id: l.id,
                  name: l.name,
                  city: l.city,
                  sub: '',
                  createdAt: l.createdAt,
                ),
              for (final h in (hSnap.data ?? const <Hospital>[]))
                _PendingItem(
                  kind: _PendingKind.hospital,
                  id: h.id,
                  name: h.name,
                  city: h.city,
                  sub: '',
                  createdAt: h.createdAt,
                ),
            ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(tr(ref, 'admin.pendingApproval'),
                          style: TextStyle(
                            fontFamily: FdType.family(ur),
                            fontSize: ur ? (17) * 0.9 : (17),
                            fontWeight: FontWeight.w800,
                            color: FdColors.ink,
                            height: FdType.height(ur, 1.3),
                          )),
                    ),
                    Text(
                      fill(tr(ref, 'admin.waiting'),
                          {'n': '${items.length}'}),
                      style: FdType.body(ur,
                          size: 13,
                          w: FontWeight.w700,
                          color: _amberInk),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final it in items)
                  _PendingCard(ur: ur, item: it),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PendingCard extends ConsumerWidget {
  final bool ur;
  final _PendingItem item;
  const _PendingCard({required this.ur, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final typeLabel = switch (item.kind) {
      _PendingKind.doctor => tr(ref, 'prof.typeDoctor'),
      _PendingKind.lab => tr(ref, 'prof.typeLab'),
      _PendingKind.hospital => tr(ref, 'prof.typeHospital'),
    };
    // Spec shows the specialty for doctors ("ENT · Mardan · …"),
    // the entity type for labs/hospitals.
    final typeToken =
        item.kind == _PendingKind.doctor && item.sub.isNotEmpty
            ? specialtyLabel(ref.watch(localeProvider), item.sub)
            : typeLabel;
    final tile = switch (item.kind) {
      _PendingKind.doctor => const _SpecTile(
          bg: Color(0xFFDDF0EA),
          icon: Icons.person_outline,
          iconColor: FdSpec.darkGreen),
      _PendingKind.lab => const _SpecTile(
          bg: FdColors.lavender,
          icon: Icons.science_outlined,
          iconColor: FdColors.lavenderInk),
      _PendingKind.hospital => const _SpecTile(
          bg: Color(0xFFF8DDDB),
          icon: Icons.add,
          iconColor: FdColors.red),
    };

    Future<void> approve() async {
      switch (item.kind) {
        case _PendingKind.doctor:
          await repo.approveDoctor(item.id, approve: true);
        case _PendingKind.lab:
          await repo.approveLab(item.id, approve: true);
        case _PendingKind.hospital:
          await repo.approveHospital(item.id, approve: true);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(ref, 'admin.approvedMsg'))));
      }
    }

    Future<void> reject() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(item.name),
          content: Text(tr(ref, 'admin.confirmDelete')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr(ref, 'admin.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr(ref, 'admin.delete'),
                  style: const TextStyle(color: FdColors.redInk)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      switch (item.kind) {
        case _PendingKind.doctor:
          await repo.deleteDoctor(item.id);
        case _PendingKind.lab:
          await repo.deleteLab(item.id);
        case _PendingKind.hospital:
          await repo.deleteHospital(item.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(ref, 'admin.rejected'))));
      }
    }

    void openDetail() async {
      if (item.kind == _PendingKind.doctor) {
        final d = await repo.getDoctor(item.id);
        if (d != null && context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ManageEntityScreen(doctor: d)));
        }
      } else if (item.kind == _PendingKind.lab) {
        final l = await repo.getLab(item.id);
        if (l != null && context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ManageEntityScreen(lab: l)));
        }
      } else {
        final h = await repo.getHospital(item.id);
        if (h != null && context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ManageEntityScreen(hospital: h)));
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FdColors.line),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              tile,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: TextStyle(
                          fontFamily: FdType.family(ur),
                          fontSize: ur ? (15) * 0.9 : (15),
                          fontWeight: FontWeight.w700,
                          color: FdColors.ink,
                          height: FdType.height(ur, 1.3),
                        ),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Text(
                      fill(tr(ref, 'admin.submitted'), {
                        'type': typeToken,
                        'city': item.city,
                        'ago': _ago(ref, item.createdAt),
                      }).replaceAll(' - ', ' \u00B7 '),
                      style: FdType.body(ur,
                          size: 12.5,
                          w: FontWeight.w500,
                          color: FdColors.muted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 12,
                child: _PressScale(
                  onTap: approve,
                  child: _ActionButton(
                      ur: ur,
                      label: tr(ref, 'admin.approve'),
                      primary: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 10,
                child: _PressScale(
                  onTap: reject,
                  child: _ActionButton(
                      ur: ur,
                      label: tr(ref, 'admin.reject'),
                      primary: false),
                ),
              ),
              const SizedBox(width: 8),
              _PressScale(
                onTap: openDetail,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: FdColors.line, width: 1.5),
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: FdColors.ink, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 44px rounded-square entity icon tile (spec).
class _SpecTile extends StatelessWidget {
  final Color bg;
  final IconData icon;
  final Color iconColor;

  const _SpecTile({
    required this.bg,
    required this.icon,
    required this.iconColor,
  });

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

/// 46px Approve (teal) / Reject (red-outline) button (spec).
class _ActionButton extends StatelessWidget {
  final bool ur;
  final String label;
  final bool primary;

  const _ActionButton(
      {required this.ur, required this.label, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? FdColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: primary
            ? null
            : Border.all(color: _rejectBorder, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: FdType.family(ur),
          fontSize: ur ? (14) * 0.9 : (14),
          fontWeight: FontWeight.w700,
          color: primary ? Colors.white : _rejectRed,
          height: FdType.height(ur, 1.3),
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final Color bg;
  final IconData icon;
  final Color iconColor;

  const _TileIcon({
    required this.bg,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(58 * 0.3),
      ),
      child: Icon(icon, color: iconColor, size: 58 * 0.5),
    );
  }
}

/// Searchable "all records" section with edit/delete per row.
class _SearchSection<T> extends ConsumerStatefulWidget {
  final bool ur;
  final String title;
  final Stream<List<T>> Function() stream;
  final String Function(T) nameOf;
  final String Function(T) subOf;
  final Widget Function(T) tileOf;
  final void Function(T) onEdit;
  final Future<void> Function(T) onDelete;

  /// Optional "+ Add" pill in the header (create mode: called with no
  /// entity). Null hides the button.
  final VoidCallback? onAdd;
  final String? addLabel;

  const _SearchSection({
    required this.ur,
    required this.title,
    required this.stream,
    required this.nameOf,
    required this.subOf,
    required this.tileOf,
    required this.onEdit,
    required this.onDelete,
    this.onAdd,
    this.addLabel,
  });

  @override
  ConsumerState<_SearchSection<T>> createState() =>
      _SearchSectionState<T>();
}

class _SearchSectionState<T>
    extends ConsumerState<_SearchSection<T>> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child:
                    Text(widget.title, style: _sectionTitle(widget.ur))),
            if (widget.onAdd != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: FdColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                      widget.addLabel ?? tr(ref, 'admin.add'),
                      style: FdType.body(widget.ur,
                          size: 13,
                          w: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        FdSearchField(
          hint: tr(ref, 'admin.searchHint'),
          isUrdu: widget.ur,
          controller: _ctrl,
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<T>>(
          stream: widget.stream(),
          builder: (context, snap) {
            final all = snap.data ?? <T>[];
            final items = _q.isEmpty
                ? all
                : all
                    .where((e) => widget
                        .nameOf(e)
                        .toLowerCase()
                        .contains(_q))
                    .toList();
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('—',
                    style: FdType.body(widget.ur, size: 14),
                    textAlign: TextAlign.center),
              );
            }
            return Column(
              children: [
                for (final it in items.take(30))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: FdColors.line),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        widget.tileOf(it),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(widget.nameOf(it),
                                  style:
                                      FdType.title(widget.ur, size: 16),
                                  overflow: TextOverflow.ellipsis),
                              Text(widget.subOf(it),
                                  style: FdType.body(widget.ur,
                                      size: 13),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: FdColors.primary, size: 22),
                          tooltip: tr(ref, 'admin.edit'),
                          onPressed: () => widget.onEdit(it),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: FdColors.redInk, size: 22),
                          tooltip: tr(ref, 'admin.delete'),
                          onPressed: () =>
                              _confirmDelete(context, ref, it),
                        ),
                      ],
                    ),
                  ),
                if (items.length > 30)
                  Text('+${items.length - 30}',
                      style: FdType.body(widget.ur, size: 13)),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, T it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.nameOf(it)),
        content: Text(tr(ref, 'admin.confirmDelete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(ref, 'admin.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr(ref, 'admin.delete'),
                style: const TextStyle(color: FdColors.redInk)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await widget.onDelete(it);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(ref, 'admin.deleted'))));
    }
  }
}

/// Chips editor for cities / specialties / test categories.
class _ListEditor extends ConsumerStatefulWidget {
  final bool ur;
  final String title;
  final Stream<List<String>> Function() watch;
  final Future<void> Function(List<String>) save;

  const _ListEditor({
    required this.ur,
    required this.title,
    required this.watch,
    required this.save,
  });

  @override
  ConsumerState<_ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends ConsumerState<_ListEditor> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: _sectionTitle(widget.ur)),
          const SizedBox(height: 10),
          StreamBuilder<List<String>>(
            stream: widget.watch(),
            builder: (context, snap) {
              final items = snap.data ?? const <String>[];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final it in items)
                    Container(
                      decoration: BoxDecoration(
                        color: FdColors.mint,
                        borderRadius:
                            BorderRadius.circular(FdDim.pillRadius),
                      ),
                      padding: const EdgeInsets.only(
                          left: 14, right: 6, top: 8, bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(it,
                              style: FdType.body(widget.ur,
                                  size: 14,
                                  w: FontWeight.w600,
                                  color: FdColors.ink)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    try {
                                      await widget.save(items
                                          .where((e) => e != it)
                                          .toList());
                                    } finally {
                                      if (mounted) {
                                        setState(() => _busy = false);
                                      }
                                    }
                                  },
                            child: const Icon(Icons.close,
                                color: FdColors.muted, size: 18),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _ctrl,
                    style: FdType.body(widget.ur,
                        size: 15, color: FdColors.ink),
                    decoration: InputDecoration(
                      hintText: tr(ref, 'admin.add'),
                      hintStyle: FdType.body(widget.ur,
                          size: 15, color: FdColors.muted),
                      filled: true,
                      fillColor: FdColors.bg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                child: FdButton(
                  label: tr(ref, 'admin.add'),
                  isUrdu: widget.ur,
                  onTap: _busy
                      ? null
                      : () async {
                          final v = _ctrl.text.trim();
                          if (v.isEmpty) return;
                          setState(() => _busy = true);
                          try {
                            final cur =
                                await widget.watch().first;
                            if (!cur.contains(v)) {
                              await widget
                                  .save([...cur, v]);
                            }
                            _ctrl.clear();
                          } finally {
                            if (mounted) {
                              setState(() => _busy = false);
                            }
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One-time import of the bundled research seeds into Firestore.
/// Visible only in Firestore mode (demo mode already ships the seeds).
class _SeedImportCard extends ConsumerStatefulWidget {
  final bool ur;
  const _SeedImportCard({required this.ur});

  @override
  ConsumerState<_SeedImportCard> createState() => _SeedImportCardState();
}

class _SeedImportCardState extends ConsumerState<_SeedImportCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ur = widget.ur;
    return Container(
      decoration: BoxDecoration(
        color: FdColors.mint,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'admin.importSeedsTitle'),
              style: FdType.title(ur, size: 18)),
          const SizedBox(height: 8),
          Text(tr(ref, 'admin.importSeedsBody'),
              style: FdType.body(ur, size: 14)),
          const SizedBox(height: 16),
          FdButton(
            label: _busy
                ? tr(ref, 'admin.importing')
                : tr(ref, 'admin.importSeeds'),
            isUrdu: ur,
            onTap: _busy ? null : _run,
          ),
        ],
      ),
    );
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final bundle = await loadSeedBundle();
      final counts = await (repo as FirestoreRepository).importSeedBundle(bundle);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(fill(tr(ref, 'admin.imported'), {
          'd': '${counts['doctors']}',
          'l': '${counts['labs']}',
          'h': '${counts['hospitals']}',
        })),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
