import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/strings.dart';
import '../l10n/strings_b.dart';
import '../models/hospital.dart';
import '../providers/providers.dart';
import '../utils/actions.dart';
import '../utils/geo.dart';
import '../widgets/theme.dart';

/// Nearest-emergency screen (design page 06): stylized route map,
/// hospital summary, call/directions/share actions, Rescue 1122 card,
/// and other emergency wards nearby.
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
        desiredAccuracy: LocationAccuracy.low,
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
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final city = ref.watch(cityProvider);
    final async = ref.watch(_emgHospitalsProvider(city));

    return Scaffold(
      backgroundColor: FdColors.bg,
      appBar: AppBar(
        title: Text(
          trB(ref, 'emg.title'),
          style: FdType.title(ur, size: 22),
        ),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: FdColors.primary)),
        error: (_, __) => const SizedBox.shrink(),
        data: (hospitals) {
          final nearest = _nearest(hospitals);
          if (nearest == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(FdDim.page),
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
    );
  }

  Widget _body(Hospital h, List<Hospital> others, bool ur) {
    final dist = _distanceKm(h.lat, h.lng);
    final mins = dist == null ? null : (dist * 2.8).round().clamp(1, 999);
    final phone = h.emergencyPhone.trim().isNotEmpty
        ? h.emergencyPhone.trim()
        : h.phone.trim();
    final depts = h.departments.take(4).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          FdDim.page, 8, FdDim.page, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Route illustration.
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: FdColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: const CustomPaint(
              painter: _RoutePainter(),
              child: SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.name, style: FdType.title(ur, size: 24)),
                    const SizedBox(height: 4),
                    Text(
                      [if (h.address.isNotEmpty) h.address, h.city]
                          .join(', '),
                      style:
                          FdType.body(ur, size: 15, color: FdColors.muted),
                    ),
                  ],
                ),
              ),
              if (dist != null) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDistance(dist),
                      style: FdType.body(ur,
                          size: 22,
                          w: FontWeight.w800,
                          color: FdColors.redInk),
                    ),
                    if (mins != null)
                      Text(
                        fill(trB(ref, 'emg.aboutMin'), {'n': '$mins'}),
                        style: FdType.body(ur,
                            size: 14, color: FdColors.muted),
                      ),
                  ],
                ),
              ],
            ],
          ),
          if (depts.isNotEmpty || h.emergency247) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (h.emergency247)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: FdColors.mint,
                      borderRadius:
                          BorderRadius.circular(FdDim.pillRadius),
                    ),
                    child: Text(
                      trB(ref, 'emg.emergencyOpen247'),
                      style: FdType.body(ur,
                          size: 14,
                          w: FontWeight.w700,
                          color: FdColors.primary),
                    ),
                  ),
                for (final dep in depts)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(FdDim.pillRadius),
                      border: Border.all(color: FdColors.line, width: 1.4),
                    ),
                    child: Text(
                      dep,
                      style: FdType.body(ur,
                          size: 14,
                          w: FontWeight.w600,
                          color: FdColors.inkSoft),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FdButton(
            label: fill(trB(ref, 'emg.callEmergency'), {'phone': phone}),
            style: FdButtonStyle.danger,
            icon: Icons.phone_outlined,
            isUrdu: ur,
            onTap: () => callNumber(context, phone),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FdButton(
                  label: trB(ref, 'emg.directions'),
                  style: FdButtonStyle.primary,
                  icon: Icons.navigation_outlined,
                  isUrdu: ur,
                  onTap: () => openDirections(context, h.lat, h.lng, h.name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FdButton(
                  label: trB(ref, 'emg.shareLocation'),
                  style: FdButtonStyle.outline,
                  icon: Icons.ios_share_outlined,
                  isUrdu: ur,
                  onTap: () => _shareLocation(h),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Rescue 1122 card.
          Container(
            decoration: BoxDecoration(
              color: FdColors.amberCard,
              borderRadius: BorderRadius.circular(FdDim.bannerRadius),
              border: Border.all(
                  color: FdColors.amberStrong.withValues(alpha: 0.35)),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: FdColors.amberStrong,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '1122',
                    style: FdType.body(false,
                        size: 17, w: FontWeight.w800, color: FdColors.ink),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trB(ref, 'emg.ambulanceTitle'),
                        style: FdType.body(ur,
                            size: 17,
                            w: FontWeight.w800,
                            color: FdColors.ink),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        trB(ref, 'emg.ambulanceBody'),
                        style: FdType.body(ur,
                            size: 14, color: FdColors.amberInk),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FdCapsLabel(
              label: trB(ref, 'emg.otherWards'), isUrdu: ur),
          const SizedBox(height: 6),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name, style: FdType.title(ur, size: 18)),
                const SizedBox(height: 3),
                Text(
                  [
                    if (dist != null) formatDistance(dist),
                    if (h.emergency247) trB(ref, 'search.emergency247'),
                  ].join(' · '),
                  style: FdType.body(ur, size: 14, color: FdColors.muted),
                ),
              ],
            ),
          ),
          Material(
            color: FdColors.redSoft,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => callNumber(context, phone),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                child: const Icon(Icons.phone_outlined,
                    color: FdColors.redInk, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stylized route illustration: light map, roads, teal route, user dot,
/// and a red hospital pin — matching the design when live maps are off.
class _RoutePainter extends CustomPainter {
  const _RoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFE9EFEA),
    );

    // Blocks.
    final block = Paint()..color = const Color(0xFFDDE6DD);
    for (final r in [
      Rect.fromLTWH(w * 0.36, h * 0.30, w * 0.20, h * 0.14),
      Rect.fromLTWH(w * 0.68, h * 0.30, w * 0.14, h * 0.20),
      Rect.fromLTWH(w * 0.42, h * 0.62, w * 0.22, h * 0.16),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(10)),
        block,
      );
    }

    // Roads.
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;
    for (final fy in [0.22, 0.52, 0.82]) {
      canvas.drawLine(Offset(0, h * fy), Offset(w, h * fy), road);
    }
    for (final fx in [0.28, 0.62]) {
      canvas.drawLine(Offset(w * fx, 0), Offset(w * fx, h), road);
    }
    // Diagonal road.
    canvas.drawLine(Offset(w * 0.30, h), Offset(w * 0.95, h * 0.35), road);

    // Route: user -> right -> up -> right to hospital.
    final route = Paint()
      ..color = FdColors.primary
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final start = Offset(w * 0.16, h * 0.52);
    final p1 = Offset(w * 0.55, h * 0.52);
    final p2 = Offset(w * 0.55, h * 0.22);
    final end = Offset(w * 0.80, h * 0.22);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(path, route);

    // User dot with halo.
    canvas.drawCircle(
        start, 30, Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.18));
    canvas.drawCircle(start, 11, Paint()..color = const Color(0xFF2563EB));
    canvas.drawCircle(
        start,
        11,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);

    // Hospital pin.
    final pin = Offset(w * 0.80, h * 0.22);
    final pinPaint = Paint()..color = FdColors.red;
    canvas.drawCircle(pin, 24, pinPaint);
    final tail = Path()
      ..moveTo(pin.dx - 13, pin.dy + 16)
      ..lineTo(pin.dx + 13, pin.dy + 16)
      ..lineTo(pin.dx, pin.dy + 36)
      ..close();
    canvas.drawPath(tail, pinPaint);
    final plus = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(pin.dx - 9, pin.dy), Offset(pin.dx + 9, pin.dy), plus);
    canvas.drawLine(
        Offset(pin.dx, pin.dy - 9), Offset(pin.dx, pin.dy + 9), plus);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
