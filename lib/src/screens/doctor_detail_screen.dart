import 'dart:io';

import 'package:fauridoc/design/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/day_hours.dart';
import '../models/doctor.dart';
import '../models/review.dart';
import '../providers/providers.dart';
import '../utils/actions.dart';
import '../utils/open_status.dart';
import '../widgets/theme.dart';
import 'reviews_screen.dart';

/// Per-user bookmarked doctors, persisted as a string list in prefs.
final _savedDoctorsProvider =
    NotifierProvider<_SavedDoctorsNotifier, Set<String>>(
        _SavedDoctorsNotifier.new);

class _SavedDoctorsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('saved_doctors')?.toSet() ?? {};
  }

  Future<bool> toggle(String id) async {
    final next = Set<String>.of(state);
    final added = next.add(id);
    if (!added) next.remove(id);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_doctors', next.toList());
    return added;
  }
}

String _initials(String name) {
  final parts = name
      .replaceFirst(RegExp(r'^Dr\.\s*'), '')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0])
      .join()
      .toUpperCase();
  return parts.isEmpty ? '•' : parts;
}

String _fmtFee(int fee) =>
    fee.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Spec-only colours that have no FdSpec/FdColors token.
const _statusCardBg = Color(0xFFE4F3EF);
const _statusLine2 = Color(0xFF2F6A5E);
const _rowDivider = Color(0xFFEEF1F0);
const _bodyInk = Color(0xFF2E4744);

/// Type helper matching the HTML spec sizes exactly (1 CSS px = 1 logical px).
/// Urdu switches to Nastaliq at w700 with extra line height, per app convention.
TextStyle _t(bool ur, double size, FontWeight w, Color color,
    {double ls = 0, double lh = 1.4}) {
  return TextStyle(
    fontFamily: ur ? FdSpec.urduFont : FdSpec.latinFont,
    fontSize: size,
    fontWeight: ur ? FontWeight.w700 : w,
    color: color,
    letterSpacing: (ls == 0 || ur) ? null : ls,
    height: ur ? lh + 0.9 : lh,
  );
}

/// Press feedback: scale to 0.97 in 80 ms (HTML `.press` class).
class _Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Press({required this.child, this.onTap});

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? FdSpec.pressScale : 1.0,
        duration: FdSpec.pressDuration,
        child: widget.child,
      ),
    );
  }
}

/// Spec star glyph (from the design SVG path), painted at any size.
class _Star extends StatelessWidget {
  final double size;

  const _Star({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StarPainter(filled: true, unfilledStroke: FdSpec.muted),
    );
  }
}

class _StarPainter extends CustomPainter {
  final bool filled;
  final Color unfilledStroke;

  _StarPainter({required this.filled, required this.unfilledStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(12, 2.5)
      ..lineTo(14.9, 8.6)
      ..lineTo(21.5, 9.4)
      ..lineTo(16.6, 14)
      ..lineTo(17.9, 20.6)
      ..lineTo(12, 17.3)
      ..lineTo(6.1, 20.6)
      ..lineTo(7.4, 14)
      ..lineTo(2.5, 9.4)
      ..lineTo(9.1, 8.6)
      ..close();
    final s = size.width / 24;
    final scaled = path
        .transform((Matrix4.identity()..scaleByDouble(s, s, 1.0, 1.0)).storage);
    if (filled) {
      canvas.drawPath(
          scaled, Paint()..color = FdSpec.star..style = PaintingStyle.fill);
      canvas.drawPath(
        scaled,
        Paint()
          ..color = FdSpec.star
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      canvas.drawPath(
        scaled,
        Paint()
          ..color = unfilledStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _dayFull(String key, bool ur) {
  const en = {
    'mon': 'Monday',
    'tue': 'Tuesday',
    'wed': 'Wednesday',
    'thu': 'Thursday',
    'fri': 'Friday',
    'sat': 'Saturday',
    'sun': 'Sunday',
  };
  const urNames = {
    'mon': 'پیر',
    'tue': 'منگل',
    'wed': 'بدھ',
    'thu': 'جمعرات',
    'fri': 'جمعہ',
    'sat': 'ہفتہ',
    'sun': 'اتوار',
  };
  return (ur ? urNames : en)[key] ?? key;
}

/// Doctor profile — design page-07: 196px tinted hero with initials,
/// rating pill, live status card, fee/parking tiles, clinic photos,
/// info card, working-hours table, patient review preview,
/// sticky Call / WhatsApp / Map bar.
class DoctorDetailScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const DoctorDetailScreen({super.key, required this.doctorId});

  @override
  ConsumerState<DoctorDetailScreen> createState() =>
      _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen> {
  late Future<Doctor?> _doctorFuture;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(repositoryProvider);
    _doctorFuture = repo.getDoctor(widget.doctorId);
    repo.recordProfileView(widget.doctorId);
  }

  void _retry() {
    setState(() {
      _doctorFuture =
          ref.read(repositoryProvider).getDoctor(widget.doctorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      backgroundColor: FdSpec.pageBg,
      body: FutureBuilder(
        future: _doctorFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data;
          if (d == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr(ref, 'error'),
                        style: FdType.body(ur, size: 15),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FdButton(
                        label: tr(ref, 'retry'),
                        isUrdu: ur,
                        onTap: _retry),
                  ],
                ),
              ),
            );
          }
          final status = computeOpenStatus(d.hours, DateTime.now());
          final onLeave =
              d.leaveTill != null && d.leaveTill!.trim().isNotEmpty;
          return Column(
            children: [
              _header(context, ref, d.name),
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            d.name,
                            style: _t(ur, 25, FontWeight.w800, FdSpec.ink,
                                ls: -0.5, lh: 1.15),
                          ),
                        ),
                        if (d.verified) ...[
                          const SizedBox(width: 7),
                          const FdVerifiedBadge(size: 22),
                        ],
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        specialtyLabel(locale, d.specialty),
                        style: _t(ur, 15, FontWeight.w600, FdSpec.primary),
                      ),
                    ),
                    if (d.qualification.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          d.qualification,
                          style: _t(ur, 14, FontWeight.w500, FdSpec.muted),
                        ),
                      ),
                    const SizedBox(height: 10),
                    _reviewsPill(ref, ur, d.rating, d.reviewCount),
                    const SizedBox(height: 14),
                    _statusCard(ref, ur, status, onLeave, d.leaveTill),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _factTile(
                            ur,
                            tr(ref, 'doc.consultationFee'),
                            d.fee != null
                                ? fill(tr(ref, 'rs'), {'p': _fmtFee(d.fee!)})
                                : '–',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _factTile(
                            ur,
                            tr(ref, 'doc.parking'),
                            d.hasParking
                                ? tr(ref, 'doc.available')
                                : tr(ref, 'doc.notAvailable'),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 22, bottom: 10),
                      child: Text(tr(ref, 'doc.clinicPhotos'),
                          style: _t(ur, 17, FontWeight.w800, FdSpec.ink,
                              lh: 1.3)),
                    ),
                    _photos(ref, ur, d.clinicPhotos),
                    Padding(
                      padding: const EdgeInsets.only(top: 22, bottom: 6),
                      child: Text(tr(ref, 'doc.clinic'),
                          style: _t(ur, 17, FontWeight.w800, FdSpec.ink,
                              lh: 1.3)),
                    ),
                    _infoCard(ref, ur, d),
                    Padding(
                      padding: const EdgeInsets.only(top: 22, bottom: 6),
                      child: Text(tr(ref, 'workingHours'),
                          style: _t(ur, 17, FontWeight.w800, FdSpec.ink,
                              lh: 1.3)),
                    ),
                    _hoursTable(ref, ur, d.hours),
                    _patientsSay(ref, ur, repo, d.reviewCount),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder(
        future: _doctorFuture,
        builder: (context, snap) {
          final d = snap.data;
          if (d == null) return const SizedBox.shrink();
          return _actionBar(context, ref, ur, d.phone, d.whatsapp, d.lat,
              d.lng, d.name);
        },
      ),
    );
  }

  // ---------- hero ----------

  Widget _header(BuildContext context, WidgetRef ref, String name) {
    final saved = ref.watch(_savedDoctorsProvider).contains(widget.doctorId);
    return Container(
      height: 196,
      color: FdSpec.doctorHeroBg,
      child: Stack(
        children: [
          Center(
            child: Text(
              _initials(name),
              style: TextStyle(
                fontFamily: FdSpec.latinFont,
                fontSize: 84,
                fontWeight: FontWeight.w800,
                letterSpacing: -2.52,
                color: FdSpec.doctorHeroFg.withValues(alpha: 0.28),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(top: 48, left: 14, right: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _circleBtn(
                  icon: Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_right
                      : Icons.chevron_left,
                  onTap: () => Navigator.of(context).pop(),
                ),
                _circleBtn(
                  icon: saved ? Icons.bookmark : Icons.bookmark_border,
                  iconColor: saved ? FdSpec.primary : FdSpec.ink,
                  onTap: () async {
                    final added = await ref
                        .read(_savedDoctorsProvider.notifier)
                        .toggle(widget.doctorId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tr(ref,
                              added ? 'doc.saved' : 'doc.unsaved')),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = FdSpec.ink,
  }) {
    return _Press(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x2E0F2A2E),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  // ---------- body widgets ----------

  Widget _reviewsPill(
      WidgetRef ref, bool ur, double rating, int reviewCount) {
    if (reviewCount <= 0) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _Press(
          onTap: _openReviews,
          child: FdNewPill(label: tr(ref, 'doc.newReviews'), isUrdu: ur),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: _Press(
        onTap: _openReviews,
        child: Container(
          height: 36,
          padding: const EdgeInsets.only(left: 10, right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FdSpec.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Star(size: 16),
              const SizedBox(width: 6),
              Text(
                rating.toStringAsFixed(1),
                style: _t(ur, 14, FontWeight.w700, FdSpec.ink),
              ),
              Text(
                ' · ${fill(tr(ref, 'doc.reviewsCount'), {'n': '$reviewCount'})}',
                style: _t(ur, 14, FontWeight.w500, FdSpec.muted),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  color: FdSpec.muted, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  void _openReviews() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewsScreen(doctorId: widget.doctorId),
      ),
    );
  }

  Widget _statusCard(WidgetRef ref, bool ur, OpenStatus status, bool onLeave,
      String? leaveTill) {
    final String line1;
    final String line2;
    final Color dot;
    if (onLeave) {
      line1 = tr(ref, 'doc.onLeave');
      line2 = (leaveTill != null && leaveTill.trim().isNotEmpty)
          ? fill(tr(ref, 'doc.backOn'), {'date': leaveTill.trim()})
          : '';
      dot = FdSpec.leaveOrange;
    } else if (status.isOpen) {
      line1 = tr(ref, 'doc.currentlyOpen');
      line2 = status.transitionAt != null
          ? fill(tr(ref, 'doc.openUntilToday'),
              {'time': formatTime12(status.transitionAt!)})
          : '';
      dot = FdSpec.openGreen;
    } else {
      line1 = tr(ref, 'doc.currentlyClosed');
      line2 = status.transitionAt != null
          ? fill(tr(ref, 'doc.opensAt'),
              {'time': formatTime12(status.transitionAt!)})
          : '';
      dot = FdSpec.closedGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _statusCardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dot.withValues(alpha: 0.2),
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line1,
                    style:
                        _t(ur, 15, FontWeight.w800, FdSpec.darkGreen)),
                if (line2.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(line2,
                        style: _t(ur, 13, FontWeight.w500, _statusLine2)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            tr(ref, 'doc.updatedByDoctor'),
            style: _t(ur, 12, FontWeight.w700, FdSpec.darkGreen),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  Widget _factTile(bool ur, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FdSpec.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _t(ur, 12, FontWeight.w600, FdSpec.muted)),
          const SizedBox(height: 2),
          Text(value,
              style: _t(ur, 18, FontWeight.w800, FdSpec.ink, lh: 1.3)),
        ],
      ),
    );
  }

  Widget _photos(WidgetRef ref, bool ur, List<String> photos) {
    if (photos.isNotEmpty) {
      return Row(
        children: [
          for (var i = 0; i < photos.length; i++) ...[
            Expanded(child: _PhotoTile(path: photos[i])),
            if (i < photos.length - 1) const SizedBox(width: 8),
          ],
        ],
      );
    }
    final tiles = [
      (const Color(0xFFDDF0EA), const Color(0xFF0B5446),
          tr(ref, 'doc.reception')),
      (const Color(0xFFE3E9FF), const Color(0xFF2B3F9E),
          tr(ref, 'doc.waitingArea')),
      (const Color(0xFFF8E1EC), const Color(0xFF8E2A57),
          tr(ref, 'doc.consultingRoom')),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          Expanded(
            child: Container(
              height: 84,
              decoration: BoxDecoration(
                color: tiles[i].$1,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              alignment: Alignment.bottomLeft,
              child: Text(
                tiles[i].$3,
                style:
                    _t(ur, 11, FontWeight.w700, tiles[i].$2, lh: 1.3),
              ),
            ),
          ),
          if (i < tiles.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _infoCard(WidgetRef ref, bool ur, Doctor d) {
    TextStyle valueStyle =
        _t(ur, 14, FontWeight.w600, FdSpec.ink, lh: 1.35);
    final rows = <({String label, Widget value})>[];
    if (d.clinicName.trim().isNotEmpty) {
      rows.add((
        label: tr(ref, 'doc.clinicName'),
        value: Text(d.clinicName, style: valueStyle)
      ));
    }
    if (d.address.trim().isNotEmpty) {
      rows.add((
        label: tr(ref, 'doc.address'),
        value: Text(d.address, style: valueStyle)
      ));
    }
    if (d.phone.trim().isNotEmpty) {
      rows.add((
        label: tr(ref, 'doc.phone'),
        value: Text(d.phone, style: valueStyle)
      ));
    }
    if (d.whatsapp.trim().isNotEmpty) {
      rows.add((
        label: tr(ref, 'doc.whatsapp'),
        value: Text(d.whatsapp, style: valueStyle)
      ));
    }
    if (d.languages.isNotEmpty) {
      rows.add((
        label: tr(ref, 'languages'),
        value: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final lang in d.languages)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _rowDivider,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(lang,
                    style: _t(ur, 13, FontWeight.w600, FdSpec.ink)),
              ),
          ],
        )
      ));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FdSpec.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? const Border(
                        bottom: BorderSide(color: _rowDivider))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(rows[i].label,
                        style:
                            _t(ur, 13, FontWeight.w600, FdSpec.muted)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: rows[i].value),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _hoursTable(WidgetRef ref, bool ur, Map<String, DayHours> hours) {
    final todayIdx = DateTime.now().weekday - 1; // Mon=0..Sun=6
    final todayLabel = _todayLabel(ref, ur);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FdSpec.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < 7; i++) ...[
            Builder(builder: (context) {
              final key = weekdayKeys[i];
              final h = hours[key] ?? DayHours.closedDay();
              final isToday = i == todayIdx;
              final closed = h.closed;
              final Color fg = closed ? FdSpec.closedGrey : FdSpec.ink;
              final FontWeight w =
                  isToday ? FontWeight.w800 : FontWeight.w500;
              return Container(
                height: 40,
                decoration: BoxDecoration(
                  border: i < 6
                      ? const Border(
                          bottom: BorderSide(color: _rowDivider))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(_dayFull(key, ur),
                            style: _t(ur, 14, w, fg)),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 1),
                            decoration: BoxDecoration(
                              color: FdSpec.primary,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(todayLabel,
                                style: _t(ur, 11, FontWeight.w700,
                                    Colors.white,
                                    lh: 1.3)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      closed
                          ? tr(ref, 'closed')
                          : '${formatTime12(h.open)} – ${formatTime12(h.close)}',
                      style: _t(ur, 14, w, fg),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _todayLabel(WidgetRef ref, bool ur) {
    final t = tr(ref, 'admin.today');
    if (ur || t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  Widget _patientsSay(
      WidgetRef ref, bool ur, FauridocRepository repo, int reviewCount) {
    if (reviewCount <= 0) return const SizedBox.shrink();
    return StreamBuilder<List<Review>>(
      stream: repo.watchReviews(widget.doctorId),
      builder: (context, snap) {
        final reviews = snap.data ?? const <Review>[];
        if (reviews.isEmpty) return const SizedBox.shrink();
        final sorted = List<Review>.of(reviews)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final r = sorted.first;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr(ref, 'doc.whatPatientsSay'),
                    style: _t(ur, 17, FontWeight.w800, FdSpec.ink, lh: 1.3),
                  ),
                  _Press(
                    onTap: _openReviews,
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      child: Text(
                        fill(tr(ref, 'doc.seeAllReviews'),
                            {'n': '$reviewCount'}),
                        style: _t(ur, 14, FontWeight.w700, FdSpec.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FdSpec.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(r.userName,
                            style:
                                _t(ur, 14, FontWeight.w700, FdSpec.ink)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _Star(size: 13),
                          const SizedBox(width: 3),
                          Text(
                            r.rating.toDouble().toStringAsFixed(1),
                            style: _t(
                                ur, 13, FontWeight.w700, FdSpec.ink),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (r.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      r.text,
                      style:
                          _t(ur, 14, FontWeight.w500, _bodyInk, lh: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- sticky action bar ----------

  Widget _actionBar(BuildContext context, WidgetRef ref, bool ur,
      String phone, String whatsapp, double? lat, double? lng, String name) {
    final waNumber = whatsapp.trim().isNotEmpty ? whatsapp : phone;
    final hasCall = phone.trim().isNotEmpty;
    final hasWa = waNumber.trim().isNotEmpty;
    final showPinOnly = !hasCall && !hasWa;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: FdSpec.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
          child: Row(
            children: [
              if (hasCall)
                Expanded(
                  flex: 13,
                  child: _Press(
                    onTap: () => callNumber(context, phone),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: FdSpec.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(tr(ref, 'doc.call'),
                              style: _t(ur, 15, FontWeight.w700,
                                  Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (hasCall && hasWa) const SizedBox(width: 10),
              if (hasWa)
                Expanded(
                  flex: 16,
                  child: _Press(
                    onTap: () => openWhatsapp(
                      context,
                      ref,
                      waNumber,
                      doctorId: widget.doctorId,
                    ),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: FdSpec.primary, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble,
                              color: FdSpec.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(tr(ref, 'doc.whatsapp'),
                              style: _t(ur, 15, FontWeight.w700,
                                  FdSpec.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (hasCall || hasWa) const SizedBox(width: 10),
              if (showPinOnly)
                Expanded(
                  child: _Press(
                    onTap: () =>
                        openDirections(context, lat, lng, name),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: FdSpec.border, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: FdSpec.ink, size: 20),
                          const SizedBox(width: 8),
                          Text(tr(ref, 'lab.viewOnMap'),
                              style: _t(ur, 15, FontWeight.w700,
                                  FdSpec.primary)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                _Press(
                  onTap: () =>
                      openDirections(context, lat, lng, name),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: FdSpec.border, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.location_on_outlined,
                        color: FdSpec.ink, size: 22),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Photo tile that handles network URLs, local files, and bundled assets.
class _PhotoTile extends StatelessWidget {
  final String path;
  const _PhotoTile({required this.path});

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (path.startsWith('http')) {
      img = Image.network(path,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink());
    } else if (path.startsWith('/')) {
      img = Image.file(File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink());
    } else {
      img = Image.asset(path,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink());
    }
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: FdSpec.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: img,
    );
  }
}
