import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/hospital.dart';
import '../providers/providers.dart';
import '../providers/user_location.dart';
import '../utils/actions.dart';
import '../widgets/theme.dart';

/// Spec-exact colors not present in the shared tokens.
const _badgeInk = Color(0xFFA11F1F);
const _deptBorder = Color(0xFFEBB8B4);
const _hairline = Color(0xFFEEF1F0);
const _mapBg = Color(0xFFE7EDEA);
const _mapBlock = Color(0xFFD5E4DC);

/// Hospital profile — design page-09: 150px pink hero with plus outline,
/// name + verified tick, rating row with "Emergency 24/7" badge, red
/// emergency-number card, info card, department chips, location map card,
/// sticky Call emergency / Directions bar.
class HospitalDetailScreen extends ConsumerStatefulWidget {
  final String hospitalId;

  const HospitalDetailScreen({super.key, required this.hospitalId});

  @override
  ConsumerState<HospitalDetailScreen> createState() =>
      _HospitalDetailScreenState();
}

class _HospitalDetailScreenState
    extends ConsumerState<HospitalDetailScreen> {
  late final Future<Hospital?> _hospitalFuture;

  @override
  void initState() {
    super.initState();
    _hospitalFuture =
        ref.read(repositoryProvider).getHospital(widget.hospitalId);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final pos = ref.watch(userLocationProvider).value;

    return Scaffold(
      backgroundColor: FdColors.bg,
      body: FutureBuilder(
        future: _hospitalFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final h = snap.data;
          if (h == null) {
            return Center(child: Text(tr(ref, 'error')));
          }
          final dist = distanceText(pos, h.lat, h.lng);
          final emergencyNo = h.emergencyPhone.trim().isNotEmpty
              ? h.emergencyPhone.trim()
              : h.phone.trim();
          return Column(
            children: [
              _header(context),
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h.name,
                            style: FdType.title(ur,
                                    size: 25, w: FontWeight.w800)
                                .copyWith(
                              letterSpacing: ur ? 0 : -0.5,
                              height: ur ? null : 1.15,
                            ),
                          ),
                        ),
                        if (h.verified) ...[
                          const SizedBox(width: 7),
                          const FdVerifiedBadge(size: 22),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        tr(ref, 'hosp.hospital'),
                        h.city,
                        if (dist != null)
                          fill(tr(ref, 'hosp.away'), {'d': dist}),
                      ].join(' · '),
                      style: FdType.body(ur,
                          size: 14,
                          w: FontWeight.w500,
                          color: FdColors.muted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (h.reviewCount > 0) ...[
                          const Icon(Icons.star,
                              color: FdColors.starGold, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            h.rating.toStringAsFixed(1),
                            style: FdType.body(ur,
                                size: 14,
                                w: FontWeight.w700,
                                color: FdColors.ink),
                          ),
                          Text(
                            ' (${fill(tr(ref, 'doc.reviewsCount'), {'n': '${h.reviewCount}'})})',
                            style: FdType.body(ur,
                                size: 14,
                                w: FontWeight.w500,
                                color: FdColors.muted),
                          ),
                          const SizedBox(width: 8),
                        ] else ...[
                          FdNewPill(
                              label: tr(ref, 'doc.newReviews'),
                              isUrdu: ur),
                          const SizedBox(width: 8),
                        ],
                        if (h.emergency247)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: FdColors.redSoft,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              tr(ref, 'hosp.emergency247'),
                              style: FdType.body(ur,
                                  size: 12,
                                  w: FontWeight.w700,
                                  color: _badgeInk),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _emergencyCard(ref, ur, emergencyNo),
                    const SizedBox(height: 12),
                    _InfoCard(
                      isUrdu: ur,
                      rows: [
                        if (h.address.trim().isNotEmpty)
                          FdInfoRow(
                              tr(ref, 'doc.address'), h.address),
                        if (h.phone.trim().isNotEmpty)
                          FdInfoRow(tr(ref, 'doc.phone'), h.phone),
                        if (h.visitingHours.trim().isNotEmpty)
                          FdInfoRow(tr(ref, 'hosp.visitingHours'),
                              h.visitingHours),
                        if (h.opdHours.trim().isNotEmpty)
                          FdInfoRow(tr(ref, 'hosp.opd'), h.opdHours),
                      ],
                    ),
                    if (h.departments.isNotEmpty) ...[
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(0, 22, 0, 10),
                        child: Text(
                          tr(ref, 'hosp.departments'),
                          style: FdType.body(ur,
                              size: 17,
                              w: FontWeight.w800,
                              color: FdColors.ink),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final dep in h.departments)
                            _deptChip(ur, dep,
                                highlight: dep.trim().toLowerCase() ==
                                    tr(ref, 'hosp.emergency')
                                        .toLowerCase()),
                        ],
                      ),
                    ],
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(0, 22, 0, 10),
                      child: Text(
                        tr(ref, 'hosp.location'),
                        style: FdType.body(ur,
                            size: 17,
                            w: FontWeight.w800,
                            color: FdColors.ink),
                      ),
                    ),
                    _Press(
                      onTap: () => openDirections(
                          context, h.lat, h.lng, h.name),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: FdColors.line),
                          color: Colors.white,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            const SizedBox(
                              height: 120,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _MapThumbPainter(),
                              ),
                            ),
                            Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tr(ref, 'lab.viewOnMap'),
                                    style: FdType.body(ur,
                                        size: 14,
                                        w: FontWeight.w700,
                                        color: FdColors.primary),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: FdColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder(
        future: _hospitalFuture,
        builder: (context, snap) {
          final h = snap.data;
          if (h == null) return const SizedBox.shrink();
          final emergencyNo = h.emergencyPhone.trim().isNotEmpty
              ? h.emergencyPhone.trim()
              : h.phone.trim();
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: FdColors.line)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
            child: Row(
              children: [
                Expanded(
                  flex: 14,
                  child: _BarButton(
                    label: tr(ref, 'hosp.callEmergency'),
                    icon: Icons.phone_outlined,
                    filled: true,
                    fillColor: FdColors.red,
                    fgColor: Colors.white,
                    isUrdu: ur,
                    onTap: () => callNumber(context, emergencyNo),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 10,
                  child: _BarButton(
                    label: tr(ref, 'hosp.directions'),
                    icon: Icons.navigation_outlined,
                    filled: false,
                    fillColor: Colors.white,
                    fgColor: FdColors.primary,
                    borderColor: FdColors.primary,
                    isUrdu: ur,
                    onTap: () => openDirections(
                        context, h.lat, h.lng, h.name),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    final rtl =
        Directionality.of(context) == TextDirection.rtl;
    return Container(
      height: 150,
      color: FdColors.hospitalHeader,
      child: Stack(
        children: [
          const Center(
            child: CustomPaint(
              size: Size(72, 72),
              painter: _PlusPainter(),
            ),
          ),
          Positioned(
            left: rtl ? null : 14,
            right: rtl ? 14 : null,
            top: 48,
            child: _Press(
              onTap: () => Navigator.of(context).pop(),
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
                child: Icon(
                  rtl ? Icons.chevron_right : Icons.chevron_left,
                  color: FdColors.ink,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Red emergency-number card.
  Widget _emergencyCard(WidgetRef ref, bool ur, String number) {
    return _Press(
      onTap: () => callNumber(context, number),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FdColors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.phone_outlined,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(ref, 'hosp.emergencyNumber'),
                    style: FdType.body(ur,
                        size: 12,
                        w: FontWeight.w600,
                        color:
                            Colors.white.withValues(alpha: 0.9)),
                  ),
                  Text(
                    number.isEmpty ? '–' : number,
                    style: FdType.body(ur,
                            size: 20, w: FontWeight.w800, color: Colors.white)
                        .copyWith(
                            letterSpacing: ur ? 0 : 0.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Department chip — "Emergency" highlighted red, rest white.
  Widget _deptChip(bool ur, String label, {bool highlight = false}) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight ? FdColors.redSoft : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: highlight ? _deptBorder : FdColors.line,
        ),
      ),
      child: Text(
        label,
        style: FdType.body(ur,
            size: 14,
            w: FontWeight.w600,
            color: highlight ? _badgeInk : FdColors.ink),
      ),
    );
  }
}

/// Sticky-bar button: 52px tall, 16px radius, 15/700 label, 20px icon.
class _BarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final Color fillColor;
  final Color fgColor;
  final Color? borderColor;
  final bool isUrdu;

  const _BarButton({
    required this.label,
    required this.icon,
    this.onTap,
    required this.filled,
    required this.fillColor,
    required this.fgColor,
    this.borderColor,
    this.isUrdu = false,
  });

  @override
  Widget build(BuildContext context) {
    return _Press(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(16),
          border: filled || borderColor == null
              ? null
              : Border.all(color: borderColor!, width: 1.5),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fgColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: FdType.body(isUrdu,
                    size: 15, w: FontWeight.w700, color: fgColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Info card matching the spec: 16px radius, 14px side padding, 92px labels
/// at 13/600 muted, values at 14/600 ink, hairline dividers.
class _InfoCard extends StatelessWidget {
  final List<FdInfoRow> rows;
  final bool isUrdu;

  const _InfoCard({required this.rows, this.isUrdu = false});

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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      rows[i].label,
                      style: FdType.body(isUrdu,
                          size: 13,
                          w: FontWeight.w600,
                          color: FdColors.muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      style: FdType.body(isUrdu,
                          size: 14,
                          w: FontWeight.w600,
                          color: FdColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            if (i < rows.length - 1)
              const Divider(color: _hairline, height: 1),
          ],
        ],
      ),
    );
  }
}

/// Plus outline from the design (72px, 1.6 stroke, 0.4 opacity).
class _PlusPainter extends CustomPainter {
  const _PlusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = FdColors.red.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(12 * s, 5 * s), Offset(12 * s, 19 * s), paint);
    canvas.drawLine(
        Offset(5 * s, 12 * s), Offset(19 * s, 12 * s), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Stylized map thumbnail for the Location card (120px tall).
class _MapThumbPainter extends CustomPainter {
  const _MapThumbPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sx = w / 350;
    final sy = h / 120;

    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h), Paint()..color = _mapBg);

    // Roads.
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 9 * sx
      ..style = PaintingStyle.stroke;
    for (final ry in [30.0, 86.0]) {
      canvas.drawLine(
          Offset(0, ry * sy), Offset(w, ry * sy), road);
    }
    for (final rx in [80.0, 200.0, 290.0]) {
      canvas.drawLine(
          Offset(rx * sx, 0), Offset(rx * sx, h), road);
    }

    // Blocks.
    final block = Paint()..color = _mapBlock;
    for (final r in [
      Rect.fromLTWH(100 * sx, 42 * sy, 80 * sx, 34 * sy),
      Rect.fromLTWH(214 * sx, 96 * sy, 60 * sx, 20 * sy),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(6 * sx)),
          block);
    }

    // Red pin with white plus at (200, 58) of the 350x120 art.
    final pin = Offset(200 * sx, 52 * sy);
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
