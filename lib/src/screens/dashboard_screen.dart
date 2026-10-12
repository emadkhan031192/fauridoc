import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Widget build(BuildContext context, WidgetRef ref) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Doctor?>(
          future: repo.getDoctor(widget.doctorId),
          builder: (context, snap) {
            final name = snap.data?.name ?? '';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(ref, 'dash.title'),
                    style: FdType.title(ur, size: 22)),
                if (name.isNotEmpty)
                  Text(
                    _fillOnly(tr(ref, 'dash.onlyYou'), name),
                    style: FdType.body(ur, size: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            );
          },
        ),
      ),
      body: FutureBuilder<Doctor?>(
        future: repo.getDoctor(widget.doctorId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
              final stats = sSnap.data ?? const <String, int>{};
              return _body(ref, ur, d, stats);
            },
          );
        },
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
          const EdgeInsets.fromLTRB(FdDim.page, 8, FdDim.page, 28),
      children: [
        _StatsCard(
            ur: ur,
            views: views,
            whatsapp: whatsapp,
            calls: calls,
            mapOpens: mapOpens),
        const SizedBox(height: 16),
        _ViewsCard(ur: ur),
        const SizedBox(height: 16),
        _LeaveCard(
          ur: ur,
          doctor: d,
          busy: _leaveBusy,
          onToggle: (on) => _toggleLeave(d, on),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _RatingCard(ur: ur, doctor: d)),
            const SizedBox(width: 14),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            ManageEntityScreen(doctor: d))),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(FdDim.cardRadius),
                    border: Border.all(
                        color: FdColors.primary, width: 1.6),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.edit_outlined,
                          color: FdColors.primary, size: 28),
                      const SizedBox(height: 10),
                      Text(tr(ref, 'dash.editProfile'),
                          style: FdType.body(ur,
                              size: 16,
                              w: FontWeight.w700,
                              color: FdColors.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fillOnly(String template, String name) =>
      template.replaceAll('{name}', name);
}

/// Dark teal stats card: big views + 3 translucent tiles.
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
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(ref, 'dash.thisWeek').toUpperCase(),
                style: FdType.label(ur,
                    size: 13,
                    w: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.75))),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$views',
                    style: const TextStyle(
                      fontFamily: FdType.latin,
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    )),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(tr(ref, 'dash.profileViews'),
                      style: FdType.body(ur,
                          size: 18,
                          w: FontWeight.w600,
                          color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                    child: _StatTile(
                        value: '$whatsapp',
                        label: tr(ref, 'dash.whatsapp'),
                        ur: ur)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatTile(
                        value: '$calls',
                        label: tr(ref, 'dash.calls'),
                        ur: ur)),
                const SizedBox(width: 12),
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
        borderRadius: BorderRadius.circular(20),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                fontFamily: FdType.latin,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
          const SizedBox(height: 4),
          Text(label,
              style: FdType.body(ur,
                  size: 13.5, w: FontWeight.w500, color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// "Views by day" bar chart card.
class _ViewsCard extends StatelessWidget {
  final bool ur;
  const _ViewsCard({required this.ur});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        // Daily breakdown is not tracked by the repository contract yet
        // (getWeeklyStats returns totals only); render truthful zeros and
        // note the limitation instead of inventing data.
        const daily = [0, 0, 0, 0, 0, 0, 0];
        final maxV = daily.reduce((a, b) => a > b ? a : b);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(FdDim.cardRadius),
            border: Border.all(color: FdColors.line),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(tr(ref, 'dash.viewsByDay'),
                        style: FdType.title(ur, size: 20)),
                  ),
                  Text(tr(ref, 'dash.monToSun'),
                      style: FdType.body(ur, size: 14)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 190,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${daily[i]}',
                                style: const TextStyle(
                                  fontFamily: FdType.latin,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: FdColors.ink,
                                )),
                            const SizedBox(height: 6),
                            Container(
                              height: 14 +
                                  (maxV > 0
                                      ? (daily[i] / maxV) * 104
                                      : 0),
                              decoration: BoxDecoration(
                                color: (maxV > 0 && daily[i] == maxV)
                                    ? FdColors.primary
                                    : const Color(0xFF8CCABB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(_days[i],
                                style: const TextStyle(
                                  fontFamily: FdType.latin,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: FdColors.muted,
                                )),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(tr(ref, 'dash.dailyNote'),
                  style: FdType.body(ur, size: 12, color: FdColors.muted),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}

/// Leave mode toggle + "how patients see it" preview.
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
        final preview = onLeave
            ? tr(ref, 'dash.onLeave')
                .replaceAll('{till}', doctor.leaveTill!)
            : status.isOpen
                ? tr(ref, 'dash.currentlyOpen').replaceAll(
                    '{time}', _fmtTime(status.transitionAt ?? ''))
                : tr(ref, 'dash.currentlyClosed');
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(FdDim.cardRadius),
            border: Border.all(color: FdColors.line),
          ),
          padding: const EdgeInsets.all(20),
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
                            style: FdType.title(ur, size: 20)),
                        const SizedBox(height: 6),
                        Text(tr(ref, 'dash.leaveDesc'),
                            style: FdType.body(ur, size: 14)),
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
                      : Switch(
                          value: onLeave,
                          activeThumbColor: FdColors.primary,
                          onChanged: onToggle,
                        ),
                ],
              ),
              const SizedBox(height: 18),
              Text(tr(ref, 'dash.howPatientsSee').toUpperCase(),
                  style: FdType.label(ur, size: 13, w: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: FdColors.mint,
                  borderRadius:
                      BorderRadius.circular(FdDim.fieldRadius),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: onLeave
                            ? FdColors.amberStrong
                            : (status.isOpen
                                ? const Color(0xFF22C55E)
                                : FdColors.muted),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(preview,
                          style: FdType.body(ur,
                              size: 16,
                              w: FontWeight.w700,
                              color: FdColors.primary)),
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
          borderRadius: BorderRadius.circular(FdDim.cardRadius),
          border: Border.all(color: FdColors.line),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(ref, 'dash.rating'),
                style: FdType.body(ur, size: 14)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star,
                    color: FdColors.starGold, size: 26),
                const SizedBox(width: 6),
                Text(
                  doctor.reviewCount > 0
                      ? doctor.rating.toStringAsFixed(1)
                      : '-',
                  style: const TextStyle(
                    fontFamily: FdType.latin,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: FdColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr(ref, 'dash.reviews')
                  .replaceAll('{n}', '${doctor.reviewCount}'),
              style: FdType.body(ur, size: 14),
            ),
          ],
        ),
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
