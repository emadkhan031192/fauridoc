import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../models/doctor.dart';
import '../providers/providers.dart';
import '../utils/open_status.dart';
import '../widgets/theme.dart';
import 'manage_entity_screen.dart';

/// Doctor's own dashboard (page-15): weekly stats, views chart,
/// leave mode, rating, edit entry.
class DashboardScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const DashboardScreen({super.key, required this.doctorId});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _leaveBusy = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleLeave(Doctor d, bool on) async {
    setState(() => _leaveBusy = true);
    try {
      final till = on ? _fmtDay(DateTime.now().add(const Duration(days: 7))) : null;
      await ref.read(repositoryProvider).updateDoctor(
            d.copyWith(leaveTill: till),
          );
      setState(() {});
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _leaveBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      body: Column(
        children: [
          FutureBuilder<Doctor?>(
            future: repo.getDoctor(widget.doctorId),
            builder: (context, snap) {
              final name = snap.data?.name ?? '';
              final subtitle = name.isEmpty
                  ? null
                  : _fillOnly(tr(ref, 'dash.onlyYou'), name)
                      .replaceAll(' - ', ' \u00B7 ');
              return _Header(
                  ur: ur,
                  title: tr(ref, 'dash.title'),
                  subtitle: subtitle);
            },
          ),
          Expanded(
            child: FutureBuilder<Doctor?>(
              future: repo.getDoctor(widget.doctorId),
              builder: (context, snap) {
                if (snap.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final d = snap.data;
                if (d == null) {
                  return Center(
                      child: Text(tr(ref, 'admin.deleted'),
                          style: FdType.body(ur, size: 15)));
                }
                return FutureBuilder<Map<String, int>>(
                  future: repo.getWeeklyStats(widget.doctorId),
                  builder: (context, sSnap) {
                    final stats =
                        sSnap.data ?? const <String, int>{};
                    return _body(ref, ur, d, stats);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
      WidgetRef ref, bool ur, Doctor d, Map<String, int> stats) {
    final views = stats['views'] ?? 0;
    final whatsapp = stats['whatsapp'] ?? 0;
    final calls = stats['calls'] ?? 0;
    final mapOpens = stats['map'] ?? 0;

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(FdDim.page, 6, FdDim.page, 24),
      children: [
        _StatsCard(
            ur: ur,
            views: views,
            whatsapp: whatsapp,
            calls: calls,
            mapOpens: mapOpens),
        const SizedBox(height: 12),
        _ViewsCard(ur: ur),
        const SizedBox(height: 12),
        _LeaveCard(
          ur: ur,
          doctor: d,
          busy: _leaveBusy,
          onToggle: (on) => _toggleLeave(d, on),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _RatingCard(ur: ur, doctor: d)),
              const SizedBox(width: 10),
              Expanded(
                child: _PressScale(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              ManageEntityScreen(doctor: d))),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: FdColors.primary, width: 1.5),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_outlined,
                            color: FdColors.primary, size: 22),
                        const SizedBox(height: 4),
                        Text(tr(ref, 'dash.editProfile'),
                            style: TextStyle(
                              fontFamily: FdType.family(ur),
                              fontSize: ur ? (15) * 0.9 : (15),
                              fontWeight: FontWeight.w800,
                              color: FdColors.primary,
                              height: FdType.height(ur, 1.3),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fillOnly(String template, String name) =>
      template.replaceAll('{name}', name);
}

/// Dark teal stats card: big views + 3 translucent tiles (spec).
class _StatsCard extends StatelessWidget {
  final bool ur;
  final int views;
  final int whatsapp;
  final int calls;
  final int mapOpens;

  const _StatsCard({
    required this.ur,
    required this.views,
    required this.whatsapp,
    required this.calls,
    required this.mapOpens,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Container(
        decoration: BoxDecoration(
          color: FdColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(ref, 'dash.thisWeek').toUpperCase(),
                style: TextStyle(
                  fontFamily: FdType.family(ur),
                  fontSize: ur ? (12) * 0.9 : (12),
                  fontWeight: FontWeight.w700,
                  letterSpacing: ur ? 0 : 0.96,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: FdType.height(ur, 1.3),
                )),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$views',
                    style: const TextStyle(
                      fontFamily: FdType.latin,
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.56,
                      color: Colors.white,
                      height: 1.0,
                    )),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(tr(ref, 'dash.profileViews'),
                      style: FdType.body(ur,
                          size: 15,
                          w: FontWeight.w600,
                          color: Colors.white
                              .withValues(alpha: 0.95))),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _StatTile(
                        value: '$whatsapp',
                        label: tr(ref, 'dash.whatsapp'),
                        ur: ur)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatTile(
                        value: '$calls',
                        label: tr(ref, 'dash.calls'),
                        ur: ur)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatTile(
                        value: '$mapOpens',
                        label: tr(ref, 'dash.mapOpens'),
                        ur: ur)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final bool ur;

  const _StatTile(
      {required this.value, required this.label, required this.ur});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                fontFamily: FdType.latin,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              )),
          Text(label,
              style: FdType.body(ur,
                  size: 12,
                  w: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// "Views by day" bar chart card (spec: 128px chart, 6/6/3/3 bars).
class _ViewsCard extends StatelessWidget {
  final bool ur;
  const _ViewsCard({required this.ur});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        // Daily breakdown is not tracked by the repository contract yet
        // (getWeeklyStats returns totals only); render truthful zeros.
        const daily = [0, 0, 0, 0, 0, 0, 0];
        final maxV = daily.reduce((a, b) => a > b ? a : b);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FdColors.line),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(tr(ref, 'dash.viewsByDay'),
                        style: TextStyle(
                          fontFamily: FdType.family(ur),
                          fontSize: ur ? (16) * 0.9 : (16),
                          fontWeight: FontWeight.w800,
                          color: FdColors.ink,
                          height: FdType.height(ur, 1.3),
                        )),
                  ),
                  Text(tr(ref, 'dash.monToSun'),
                      style: FdType.body(ur,
                          size: 12,
                          w: FontWeight.w600,
                          color: FdColors.muted)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 128,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${daily[i]}',
                                style: const TextStyle(
                                  fontFamily: FdType.latin,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E4744),
                                  height: 1.2,
                                )),
                            const SizedBox(height: 4),
                            Container(
                              height: maxV > 0
                                  ? (daily[i] / maxV) * 84
                                  : 0,
                              decoration: BoxDecoration(
                                color: (maxV > 0 &&
                                        daily[i] == maxV)
                                    ? FdColors.primary
                                    : const Color(0xFF8CCABB),
                                borderRadius:
                                    const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                  bottom: Radius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Text(_days[i],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: FdType.latin,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FdColors.muted,
                            height: 1.2,
                          )),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Leave mode toggle + "how patients see it" preview (spec).
class _LeaveCard extends StatelessWidget {
  final bool ur;
  final Doctor doctor;
  final bool busy;
  final ValueChanged<bool> onToggle;

  const _LeaveCard({
    required this.ur,
    required this.doctor,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final onLeave = doctor.leaveTill != null;
        final status = computeOpenStatus(doctor.hours, DateTime.now());
        final preview = (onLeave
                ? tr(ref, 'dash.onLeave')
                    .replaceAll('{till}', doctor.leaveTill!)
                : status.isOpen
                    ? tr(ref, 'dash.currentlyOpen').replaceAll(
                        '{time}', _fmtTime(status.transitionAt ?? ''))
                    : tr(ref, 'dash.currentlyClosed'))
            .replaceAll(' - ', ' \u00B7 ');
        final previewBg =
            onLeave ? const Color(0xFFFFF0DC) : _previewBg;
        final previewDot = onLeave
            ? FdSpec.leaveOrange
            : (status.isOpen ? FdSpec.openGreen : FdSpec.closedGrey);
        final previewFg =
            onLeave ? _amberInk : FdSpec.darkGreen;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FdColors.line),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(ref, 'dash.leaveMode'),
                            style: TextStyle(
                              fontFamily: FdType.family(ur),
                              fontSize: ur ? (16) * 0.9 : (16),
                              fontWeight: FontWeight.w800,
                              color: FdColors.ink,
                              height: FdType.height(ur, 1.3),
                            )),
                        const SizedBox(height: 2),
                        Text(tr(ref, 'dash.leaveDesc'),
                            style: FdType.body(ur,
                                size: 13,
                                w: FontWeight.w500,
                                color: FdColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  busy
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5))
                      : _PressScale(
                          onTap: () => onToggle(!onLeave),
                          child: _FdSwitch(value: onLeave),
                        ),
                ],
              ),
              const SizedBox(height: 12),
              Text(tr(ref, 'dash.howPatientsSee').toUpperCase(),
                  style: TextStyle(
                    fontFamily: FdType.family(ur),
                    fontSize: ur ? (12) * 0.9 : (12),
                    fontWeight: FontWeight.w700,
                    letterSpacing: ur ? 0 : 0.72,
                    color: FdColors.muted,
                    height: FdType.height(ur, 1.3),
                  )),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: previewBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: previewDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(preview,
                          style: TextStyle(
                            fontFamily: FdType.family(ur),
                            fontSize: ur ? (14) * 0.9 : (14),
                            fontWeight: FontWeight.w700,
                            color: previewFg,
                            height: FdType.height(ur, 1.35),
                          )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RatingCard extends StatelessWidget {
  final bool ur;
  final Doctor doctor;
  const _RatingCard({required this.ur, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FdColors.line),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr(ref, 'dash.rating'),
                style: FdType.body(ur,
                    size: 12,
                    w: FontWeight.w600,
                    color: FdColors.muted)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.star,
                    color: FdColors.starGold, size: 18),
                const SizedBox(width: 5),
                Text(
                  doctor.reviewCount > 0
                      ? doctor.rating.toStringAsFixed(1)
                      : '-',
                  style: const TextStyle(
                    fontFamily: FdType.latin,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: FdColors.ink,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              tr(ref, 'dash.reviews')
                  .replaceAll('{n}', '${doctor.reviewCount}'),
              style: FdType.body(ur,
                  size: 12,
                  w: FontWeight.w500,
                  color: FdColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// Spec-only colours: leave preview bg + amber ink (not in FdSpec).
const _previewBg = Color(0xFFE4F3EF);
const _amberInk = Color(0xFF8A4B00);
const _switchOff = Color(0xFFB7C4C0);

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

/// Spec switch display: 52x32 track, 26px knob, teal when on.
/// (Tap handling lives on the parent `_PressScale`.)
class _FdSwitch extends StatelessWidget {
  final bool value;

  const _FdSwitch({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 52,
      height: 32,
      decoration: BoxDecoration(
        color: value ? FdColors.primary : _switchOff,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            top: 3,
            left: value ? 23 : 3,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _fmtDay(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "20:00" -> "8 PM".
String _fmtTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  var h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  final suffix = h >= 12 ? 'PM' : 'AM';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return m == '00' ? '$h12 $suffix' : '$h12:$m $suffix';
}
