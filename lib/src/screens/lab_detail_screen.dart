import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/day_hours.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../providers/font_scale.dart';
import '../providers/user_location.dart';
import '../utils/actions.dart';
import '../utils/open_status.dart';
import '../widgets/theme.dart';

/// Spec-exact colors not present in the shared tokens.
const _openPillBg = Color(0xFFE4F3EF);
const _hairline = Color(0xFFEEF1F0);

/// Compact weekly summary, e.g. "Mon–Sat 8 AM–10 PM · Sun closed".
String _hoursSummary(Map<String, DayHours> hours) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final groups = <String>[];
  var i = 0;
  while (i < 7) {
    final h = hours[weekdayKeys[i]] ?? DayHours.closedDay();
    var j = i;
    while (j + 1 < 7) {
      final n = hours[weekdayKeys[j + 1]] ?? DayHours.closedDay();
      if (n.closed == h.closed && n.open == h.open && n.close == h.close) {
        j++;
      } else {
        break;
      }
    }
    final label = i == j ? names[i] : '${names[i]}–${names[j]}';
    groups.add(h.closed
        ? '$label: closed'
        : '$label ${formatTime12(h.open)}–${formatTime12(h.close)}');
    i = j + 1;
  }
  return groups.join(' · ');
}

/// Lab profile — design page-08: 150px lavender hero with flask outline,
/// name + verified tick, rating row with open pill, info card, searchable
/// tests & prices with category chips, "Show all N tests" expander, price
/// disclaimer, sticky Call / View on Map bar.
class LabDetailScreen extends ConsumerStatefulWidget {
  final String labId;

  const LabDetailScreen({super.key, required this.labId});

  @override
  ConsumerState<LabDetailScreen> createState() => _LabDetailScreenState();
}

class _LabDetailScreenState extends ConsumerState<LabDetailScreen> {
  String _query = '';
  String _category = 'All';
  bool _showAll = false;
  late Future<Lab?> _labFuture;

  /// Rows visible in the collapsed state (spec shows six).
  static const _collapsedCount = 6;

  @override
  void initState() {
    super.initState();
    _labFuture = ref.read(repositoryProvider).getLab(widget.labId);
  }

  void _retry() {
    setState(() {
      _labFuture = ref.read(repositoryProvider).getLab(widget.labId);
    });
  }

  void _resetExpansion() => _showAll = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(fontScaleProvider); // Re-render when the font-size sliders change.
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final pos = ref.watch(userLocationProvider).value;

    return Scaffold(
      backgroundColor: FdColors.bg,
      body: FutureBuilder<Lab?>(
        future: _labFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lab = snap.data;
          if (lab == null) {
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
          final status = computeOpenStatus(lab.hours, DateTime.now());
          final dist = distanceText(pos, lab.lat, lab.lng);
          final categories = <String>{
            for (final t in lab.tests)
              if (t.category.trim().isNotEmpty) t.category.trim()
          }.toList()
            ..sort();
          final tests = lab.tests.where((t) {
            final q = _query.trim().toLowerCase();
            final okQ = q.isEmpty ||
                t.test.toLowerCase().contains(q) ||
                t.category.toLowerCase().contains(q);
            final okC = _category == 'All' || t.category == _category;
            return okQ && okC;
          }).toList();
          final visible = _showAll || tests.length <= _collapsedCount
              ? tests
              : tests.sublist(0, _collapsedCount);
          return Column(
            children: [
              _header(context),
              Expanded(
                child: ListView(
                  // No horizontal page padding here: each child pads itself
                  // so the category chips row can bleed edge-to-edge without
                  // negative margins (which assert in debug builds).
                  padding:
                      const EdgeInsets.fromLTRB(0, 16, 0, 24),
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lab.name,
                              style: FdType.title(ur,
                                      size: 25, w: FontWeight.w800)
                                  .copyWith(
                                letterSpacing: ur ? 0 : -0.5,
                                height: ur ? null : 1.15,
                              ),
                            ),
                          ),
                          if (lab.verified) ...[
                            const SizedBox(width: 7),
                            const FdVerifiedBadge(size: 22),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        [
                          tr(ref, 'lab.clinicalLab'),
                          lab.city,
                          if (dist != null)
                            fill(tr(ref, 'lab.away'), {'d': dist}),
                        ].join(' · '),
                        style: FdType.body(ur,
                            size: 14,
                            w: FontWeight.w500,
                            color: FdColors.muted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.star,
                              color: FdColors.starGold, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            lab.rating.toStringAsFixed(1),
                            style: FdType.body(ur,
                                size: 14,
                                w: FontWeight.w700,
                                color: FdColors.ink),
                          ),
                          if (lab.reviewCount > 0)
                            Text(
                              ' (${fill(tr(ref, 'doc.reviewsCount'), {'n': '${lab.reviewCount}'})})',
                              style: FdType.body(ur,
                                  size: 14,
                                  w: FontWeight.w500,
                                  color: FdColors.muted),
                            )
                          else ...[
                            const SizedBox(width: 8),
                            FdNewPill(
                                label: tr(ref, 'doc.newReviews'),
                                isUrdu: ur),
                          ],
                          const SizedBox(width: 6),
                          _openPill(ref, ur, status),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: _InfoCard(
                        isUrdu: ur,
                        rows: [
                          if (lab.address.trim().isNotEmpty)
                            FdInfoRow(
                                tr(ref, 'doc.address'), lab.address),
                          if (lab.phone.trim().isNotEmpty)
                            FdInfoRow(tr(ref, 'doc.phone'), lab.phone),
                          FdInfoRow(tr(ref, 'doc.hours'),
                              _hoursSummary(lab.hours)),
                          FdInfoRow(
                            tr(ref, 'doc.parking'),
                            lab.hasParking
                                ? tr(ref, 'doc.available')
                                : tr(ref, 'doc.notAvailable'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 22, 20, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              tr(ref, 'lab.testsAndPrices'),
                              style: FdType.body(ur,
                                  size: 17,
                                  w: FontWeight.w800,
                                  color: FdColors.ink),
                            ),
                          ),
                          Text(
                            fill(tr(ref, 'lab.testsCount'),
                                {'n': '${lab.tests.length}'}),
                            style: FdType.body(ur,
                                size: 13,
                                w: FontWeight.w600,
                                color: FdColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: _SearchField(
                        hint: tr(ref, 'lab.searchTest'),
                        isUrdu: ur,
                        onChanged: (v) => setState(() {
                          _query = v;
                          _resetExpansion();
                        }),
                      ),
                    ),
                    if (categories.isNotEmpty)
                      // Full-bleed row: the ListView carries no horizontal
                      // page padding, so this already spans the viewport
                      // width (the inner list keeps its 20px scroll padding).
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          itemCount: categories.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final c =
                                i == 0 ? 'All' : categories[i - 1];
                            final selected = _category == c;
                            final label = c == 'All'
                                ? tr(ref, 'lab.all')
                                : c;
                            return _Press(
                              onTap: () => setState(() {
                                _category = c;
                                _resetExpansion();
                              }),
                              child: Container(
                                height: 34,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? FdColors.ink
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(17),
                                  border: selected
                                      ? null
                                      : Border.all(
                                          color: FdColors.line),
                                ),
                                child: Text(
                                  label,
                                  style: FdType.body(ur,
                                      size: 13,
                                      w: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : FdColors.ink),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (tests.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        child: Center(
                          child: Text(tr(ref, 'lab.noTests'),
                              style: FdType.body(ur,
                                  color: FdColors.muted)),
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: FdColors.line),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          child: Column(
                            children: [
                              for (var i = 0;
                                  i < visible.length;
                                  i++) ...[
                                _testRow(ur, visible[i]),
                                if (i < visible.length - 1)
                                  const Divider(
                                      color: _hairline, height: 1),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (tests.length > _collapsedCount)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          child: _Press(
                            onTap: () => setState(
                                () => _showAll = !_showAll),
                            child: Container(
                              height: 44,
                              margin: const EdgeInsets.only(top: 6),
                              alignment: Alignment.center,
                              // Spec copy: "Show all {n} tests".
                              child: Text(
                                fill(tr(ref, 'lab.showAllTests'),
                                    {'n': '${tests.length}'}),
                                style: FdType.body(ur,
                                    size: 14,
                                    w: FontWeight.w700,
                                    color: FdColors.primary),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: Text(
                          tr(ref, 'lab.priceDisclaimer'),
                          style: FdType.body(ur,
                              size: 12,
                              w: FontWeight.w500,
                              color: FdColors.muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<Lab?>(
        future: _labFuture,
        builder: (context, snap) {
          final lab = snap.data;
          if (lab == null) return const SizedBox.shrink();
          final hasCall = lab.phone.trim().isNotEmpty;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: FdColors.line)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
            child: Row(
              children: [
                if (hasCall) ...[
                  Expanded(
                    flex: 10,
                    child: _BarButton(
                      label: tr(ref, 'doc.call'),
                      icon: Icons.phone_outlined,
                      filled: true,
                      fillColor: FdColors.primary,
                      fgColor: Colors.white,
                      isUrdu: ur,
                      onTap: () => callNumber(context, lab.phone),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 13,
                  child: _BarButton(
                    label: tr(ref, 'lab.viewOnMap'),
                    icon: Icons.location_on_outlined,
                    filled: false,
                    fillColor: Colors.white,
                    fgColor: FdColors.primary,
                    borderColor: FdColors.primary,
                    isUrdu: ur,
                    onTap: () => openDirections(
                        context, lab.lat, lab.lng, lab.name),
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
      color: FdColors.labHeader,
      child: Stack(
        children: [
          const Center(
            child: CustomPaint(
              size: Size(72, 72),
              painter: _FlaskPainter(),
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

  /// Mint "Open until 10 PM" pill, or a soft closed variant.
  Widget _openPill(WidgetRef ref, bool ur, OpenStatus status) {
    final open = status.isOpen;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: open ? _openPillBg : FdColors.redSoft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        open
            ? fill(tr(ref, 'lab.openUntil'), {
                'time': status.transitionAt != null
                    ? formatTime12(status.transitionAt!)
                    : ''
              })
            : fill(tr(ref, 'lab.closedOpens'), {
                'time': status.transitionAt != null
                    ? formatTime12(status.transitionAt!)
                    : ''
              }),
        style: FdType.body(ur,
            size: 12,
            w: FontWeight.w700,
            color: open ? FdColors.primaryDark : FdColors.redInk),
      ),
    );
  }

  Widget _testRow(bool ur, LabTestPrice t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.test,
                      style: FdType.body(ur,
                          size: 15,
                          w: FontWeight.w700,
                          color: FdColors.ink)),
                  if (t.category.trim().isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(t.category,
                        style: FdType.body(ur,
                            size: 12,
                            w: FontWeight.w500,
                            color: FdColors.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              fill(tr(ref, 'rs'), {'p': '${t.price}'}),
              style: FdType.body(ur,
                  size: 16,
                  w: FontWeight.w800,
                  color: FdColors.primary),
            ),
          ],
        ),
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

/// Compact search field: 46px tall, 14px radius, 14/500 text.
class _SearchField extends StatelessWidget {
  final String hint;
  final bool isUrdu;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.hint,
    required this.onChanged,
    this.isUrdu = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        onChanged: onChanged,
        style: FdType.body(isUrdu,
            size: 14, w: FontWeight.w500, color: FdColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: FdType.body(isUrdu,
              size: 14, w: FontWeight.w500, color: FdColors.muted),
          prefixIcon: const Icon(Icons.search,
              color: FdColors.muted, size: 18),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FdColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FdColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: FdColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Flask outline from the design (72px, 1.3 stroke, 0.4 opacity).
class _FlaskPainter extends CustomPainter {
  const _FlaskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = FdColors.lavenderInk.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    // M9 3h6
    path
      ..moveTo(9 * s, 3 * s)
      ..lineTo(15 * s, 3 * s);
    // M10 3v6l-5 9a2 2 0 0 0 1.8 3h10.4a2 2 0 0 0 1.8-3l-5-9V3
    path
      ..moveTo(10 * s, 3 * s)
      ..lineTo(10 * s, 9 * s)
      ..lineTo(5 * s, 18 * s)
      ..quadraticBezierTo(5.2 * s, 20.6 * s, 6.8 * s, 21 * s)
      ..lineTo(17.2 * s, 21 * s)
      ..quadraticBezierTo(18.8 * s, 20.6 * s, 19 * s, 18 * s)
      ..lineTo(14 * s, 9 * s)
      ..lineTo(14 * s, 3 * s);
    // M8 15h8
    path
      ..moveTo(8 * s, 15 * s)
      ..lineTo(16 * s, 15 * s);
    canvas.drawPath(path, paint);
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
