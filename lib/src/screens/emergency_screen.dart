import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/strings.dart';
import '../l10n/strings_b.dart';
import '../models/hospital.dart';
import '../providers/providers.dart';
import '../providers/font_scale.dart';
import '../utils/actions.dart';
import '../utils/geo.dart';
import '../widgets/theme.dart';

/// Spec-exact colors not present in the shared tokens.
const _openPillBg = Color(0xFFE4F3EF);
const _openPillInk = Color(0xFF0B5446);
const _deptChipBg = Color(0xFFEEF1F0);
const _amberCard = Color(0xFFFFF0DC);
const _amberBorder = Color(0xFFF4D9B2);
const _rescueBadge = Color(0xFFFF7A1A);
const _rescueInk = Color(0xFF2A1300);
const _amberBody = Color(0xFF6B4A0E);
const _mapBg = Color(0xFFE7EDEA);
const _mapBlock = Color(0xFFD5E4DC);
const _userDot = Color(0xFF2F6BFF);

/// Nearest-emergency screen (design page 06): custom header, stylized
/// route-map card with hospital summary, call/directions/share actions,
/// Rescue 1122 card, and other emergency wards nearby.
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

final _emgHospitalsProvider =
    StreamProvider.autoDispose.family<List<Hospital>, String>(
  (ref, city) => ref.watch(repositoryProvider).watchHospitals(city: city),
);

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  Position? _pos;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted) setState(() => _pos = p);
    } catch (_) {
      // Distances are simply omitted.
    }
  }

  double? _distanceKm(double? lat, double? lng) {
    final p = _pos;
    if (p == null || lat == null || lng == null) return null;
    return haversineKm(p.latitude, p.longitude, lat, lng);
  }

  Hospital? _nearest(List<Hospital> hospitals) {
    if (hospitals.isEmpty) return null;
    return hospitals.firstWhere(
      (h) => h.emergency247,
      orElse: () => hospitals.first,
    );
  }

  void _shareLocation(Hospital h) {
    final link = (h.lat != null && h.lng != null)
        ? 'https://www.google.com/maps/search/?api=1&query=${h.lat},${h.lng}'
        : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${h.name} ${h.address} ${h.city}')}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(trB(ref, 'emg.locationCopied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fontScaleProvider); // Re-render when the font-size sliders change.
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final city = ref.watch(cityProvider);
    final async = ref.watch(_emgHospitalsProvider(city));

    return Scaffold(
      backgroundColor: FdColors.bg,
      body: Column(
        children: [
          _header(ur),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: FdColors.primary)),
              error: (_, _) => const SizedBox.shrink(),
              data: (hospitals) {
                final nearest = _nearest(hospitals);
                if (nearest == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        fill(trB(ref, 'emg.noHospital'), {'city': city}),
                        style: FdType.body(ur, color: FdColors.muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final others = hospitals
                    .where((h) => h.id != nearest.id && h.emergency247)
                    .toList();
                return _body(nearest, others, ur);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Plain 44px back button + 20/800 title, 48px top padding (spec).
  Widget _header(bool ur) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 48, 10, 0),
      child: Row(
        children: [
          _Press(
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
            child: Text(
              trB(ref, 'emg.title'),
              style: FdType.title(ur, size: 20, w: FontWeight.w800)
                  .copyWith(letterSpacing: ur ? 0 : -0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Hospital h, List<Hospital> others, bool ur) {
    final dist = _distanceKm(h.lat, h.lng);
    final mins = dist == null ? null : (dist * 2.8).round().clamp(1, 999);
    final phone = h.emergencyPhone.trim().isNotEmpty
        ? h.emergencyPhone.trim()
        : h.phone.trim();
    final depts = h.departments.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Route-map card with hospital summary.
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FdColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 168,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _RoutePainter(),
                    child: SizedBox.expand(),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h.name,
                                  style: FdType.title(ur,
                                          size: 21,
                                          w: FontWeight.w800)
                                      .copyWith(
                                    letterSpacing: ur ? 0 : -0.32,
                                    height: ur ? null : 1.15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [h.address, h.city]
                                      .where((s) => s.trim().isNotEmpty)
                                      .join(', '),
                                  style: FdType.body(ur,
                                      size: 14,
                                      w: FontWeight.w500,
                                      color: FdColors.muted),
                                ),
                              ],
                            ),
                          ),
                          if (dist != null) ...[
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatDistance(dist),
                                  style: FdType.body(ur,
                                          size: 22,
                                          w: FontWeight.w800,
                                          color: FdColors.red)
                                      .copyWith(
                                          letterSpacing: ur ? 0 : -0.22),
                                ),
                                if (mins != null)
                                  Text(
                                    fill(trB(ref, 'emg.aboutMin'),
                                        {'n': '$mins'}),
                                    style: FdType.body(ur,
                                        size: 12,
                                        w: FontWeight.w600,
                                        color: FdColors.muted),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      if (depts.isNotEmpty || h.emergency247) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (h.emergency247)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _openPillBg,
                                  borderRadius:
                                      BorderRadius.circular(11),
                                ),
                                child: Text(
                                  trB(ref, 'emg.emergencyOpen247'),
                                  style: FdType.body(ur,
                                      size: 12,
                                      w: FontWeight.w700,
                                      color: _openPillInk),
                                ),
                              ),
                            for (final dep in depts)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _deptChipBg,
                                  borderRadius:
                                      BorderRadius.circular(11),
                                ),
                                child: Text(
                                  dep,
                                  style: FdType.body(ur,
                                      size: 12,
                                      w: FontWeight.w700,
                                      color: FdColors.muted),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Press(
            onTap: () => callNumber(context, phone),
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: FdColors.red,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone_outlined,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      fill(trB(ref, 'emg.callEmergency'),
                          {'phone': phone}),
                      style: FdType.body(ur,
                          size: 17,
                          w: FontWeight.w800,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: trB(ref, 'emg.directions'),
                  icon: Icons.navigation_outlined,
                  filled: true,
                  isUrdu: ur,
                  onTap: () =>
                      openDirections(context, h.lat, h.lng, h.name),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: trB(ref, 'emg.shareLocation'),
                  icon: Icons.ios_share_outlined,
                  filled: false,
                  isUrdu: ur,
                  onTap: () => _shareLocation(h),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Rescue 1122 card.
          Container(
            decoration: BoxDecoration(
              color: _amberCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _amberBorder),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _rescueBadge,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '1122',
                    style: FdType.body(false,
                        size: 13,
                        w: FontWeight.w800,
                        color: _rescueInk),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        trB(ref, 'emg.ambulanceTitle'),
                        style: FdType.body(ur,
                            size: 14,
                            w: FontWeight.w700,
                            color: FdColors.ink),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        trB(ref, 'emg.ambulanceBody'),
                        style: FdType.body(ur,
                            size: 12,
                            w: FontWeight.w500,
                            color: _amberBody),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
            child: Row(
              children: [
                Text(
                  trB(ref, 'emg.otherWards').toUpperCase(),
                  style: FdType.body(ur,
                          size: 12,
                          w: FontWeight.w700,
                          color: FdColors.muted)
                      .copyWith(letterSpacing: ur ? 0 : 0.96),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Divider(color: FdColors.line, height: 1),
                ),
              ],
            ),
          ),
          for (final o in others) _wardRow(o, ur),
        ],
      ),
    );
  }

  Widget _wardRow(Hospital h, bool ur) {
    final dist = _distanceKm(h.lat, h.lng);
    final phone = h.emergencyPhone.trim().isNotEmpty
        ? h.emergencyPhone.trim()
        : h.phone.trim();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(h.name,
                          style: FdType.body(ur,
                              size: 15,
                              w: FontWeight.w700,
                              color: FdColors.ink)),
                      const SizedBox(height: 1),
                      Text(
                        [
                          if (dist != null) formatDistance(dist),
                          if (h.emergency247)
                            trB(ref, 'search.emergency247'),
                        ].join(' · '),
                        style: FdType.body(ur,
                            size: 12.5,
                            w: FontWeight.w500,
                            color: FdColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _Press(
                  onTap: () => callNumber(context, phone),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: FdColors.redSoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.phone_outlined,
                        color: FdColors.red, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(color: FdColors.line, height: 1),
      ],
    );
  }
}

/// 52px action button: filled teal or white with 1.5px teal border.
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool isUrdu;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    this.isUrdu = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Press(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: filled ? FdColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: filled
              ? null
              : Border.all(color: FdColors.primary, width: 1.5),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: filled ? Colors.white : FdColors.primary,
                size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: FdType.body(isUrdu,
                    size: 15,
                    w: FontWeight.w700,
                    color: filled ? Colors.white : FdColors.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stylized route illustration matching the design: light map, white roads,
/// teal route from the user dot to the red hospital pin.
class _RoutePainter extends CustomPainter {
  const _RoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sx = w / 350;
    final sy = h / 168;

    // Base.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = _mapBg,
    );

    // Roads.
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 9 * sx
      ..style = PaintingStyle.stroke;
    for (final ry in [40.0, 108.0]) {
      canvas.drawLine(Offset(0, ry * sy), Offset(w, ry * sy), road);
    }
    for (final rx in [70.0, 190.0, 290.0]) {
      canvas.drawLine(Offset(rx * sx, 0), Offset(rx * sx, h), road);
    }
    // Diagonal road.
    canvas.drawLine(
      Offset(0, 140 * sy),
      Offset(120 * sx, 110 * sy),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 6 * sx
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(120 * sx, 110 * sy),
      Offset(240 * sx, 70 * sy),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 6 * sx
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(240 * sx, 70 * sy),
      Offset(350 * sx, 50 * sy),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 6 * sx
        ..style = PaintingStyle.stroke,
    );

    // Blocks.
    final block = Paint()..color = _mapBlock;
    for (final r in [
      Rect.fromLTWH(96 * sx, 52 * sy, 70 * sx, 42 * sy),
      Rect.fromLTWH(206 * sx, 118 * sy, 64 * sx, 36 * sy),
      Rect.fromLTWH(304 * sx, 50 * sy, 34 * sx, 46 * sy),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(6 * sx)),
        block,
      );
    }

    // Route: user -> right -> up -> right to the hospital pin.
    final route = Paint()
      ..color = FdColors.primary
      ..strokeWidth = 5 * sx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final start = Offset(44 * sx, 128 * sy);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(190 * sx, 128 * sy)
      ..lineTo(190 * sx, 40 * sy)
      ..lineTo(290 * sx, 40 * sy);
    canvas.drawPath(path, route);

    // User dot: white ring + blue center.
    canvas.drawCircle(start, 9 * sx, Paint()..color = Colors.white);
    canvas.drawCircle(start, 6 * sx, Paint()..color = _userDot);

    // Hospital pin with white plus at (290, 40).
    final pin = Offset(290 * sx, 40 * sy);
    final red = Paint()..color = FdColors.red;
    canvas.drawCircle(pin, 11 * sx, red);
    final tail = Path()
      ..moveTo(pin.dx - 7 * sx, pin.dy + 7 * sy)
      ..lineTo(pin.dx + 7 * sx, pin.dy + 7 * sy)
      ..lineTo(pin.dx, pin.dy + 20 * sy)
      ..close();
    canvas.drawPath(tail, red);
    final plus = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.4 * sx
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(pin.dx - 4.5 * sx, pin.dy),
        Offset(pin.dx + 4.5 * sx, pin.dy), plus);
    canvas.drawLine(Offset(pin.dx, pin.dy - 4.5 * sx),
        Offset(pin.dx, pin.dy + 4.5 * sx), plus);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Press feedback: scale to 0.97 over 80 ms (spec `.press` class).
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
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: widget.child,
      ),
    );
  }
}
