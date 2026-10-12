import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/day_hours.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../providers/user_location.dart';
import '../utils/actions.dart';
import '../utils/open_status.dart';
import '../widgets/theme.dart';

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

/// Lab profile — design page-08: lavender header with flask outline, rating
/// row + open pill, info card, searchable tests & prices with category chips,
/// sticky Call / View on Map bar.
class LabDetailScreen extends ConsumerStatefulWidget {
  final String labId;

  const LabDetailScreen({super.key, required this.labId});

  @override
  ConsumerState<LabDetailScreen> createState() => _LabDetailScreenState();
}

class _LabDetailScreenState extends ConsumerState<LabDetailScreen> {
  String _query = '';
  String _category = 'All';
  late final Future<Lab?> _labFuture;

  @override
  void initState() {
    super.initState();
    _labFuture = ref.read(repositoryProvider).getLab(widget.labId);
  }

  @override
  Widget build(BuildContext context) {
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
            return Center(child: Text(tr(ref, 'error')));
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
          return Column(
            children: [
              _header(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      FdDim.page, 20, FdDim.page, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(lab.name,
                              style: FdType.title(ur, size: 26)),
                        ),
                        if (lab.verified) ...[
                          const SizedBox(width: 10),
                          const FdVerifiedBadge(size: 26),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        tr(ref, 'lab.clinicalLab'),
                        lab.city,
                        if (dist != null)
                          fill(tr(ref, 'lab.away'), {'d': dist}),
                      ].join(' · '),
                      style: FdType.body(ur,
                          size: 16, color: FdColors.muted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (lab.reviewCount > 0) ...[
                          const Icon(Icons.star,
                              color: FdColors.starGold, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            '${lab.rating.toStringAsFixed(1)}  (${fill(tr(ref, 'doc.reviewsCount'), {'n': '${lab.reviewCount}'})})',
                            style: FdType.body(ur,
                                size: 17,
                                w: FontWeight.w700,
                                color: FdColors.ink),
                          ),
                          const SizedBox(width: 14),
                        ] else ...[
                          FdNewPill(
                              label: tr(ref, 'doc.newReviews'),
                              isUrdu: ur),
                          const SizedBox(width: 14),
                        ],
                        _openPill(ref, ur, status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FdInfoCard(
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
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(ref, 'lab.testsAndPrices'),
                            style: FdType.title(ur, size: 21),
                          ),
                        ),
                        Text(
                          fill(tr(ref, 'lab.testsCount'),
                              {'n': '${lab.tests.length}'}),
                          style: FdType.body(ur,
                              size: 15,
                              w: FontWeight.w600,
                              color: FdColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FdSearchField(
                      hint: tr(ref, 'lab.searchTest'),
                      isUrdu: ur,
                      onChanged: (v) =>
                          setState(() => _query = v),
                    ),
                    const SizedBox(height: 12),
                    if (categories.isNotEmpty)
                      SizedBox(
                        height: FdDim.chipHeight,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final c =
                                i == 0 ? 'All' : categories[i - 1];
                            final selected = _category == c;
                            final label = c == 'All'
                                ? tr(ref, 'lab.all')
                                : c;
                            return _catChip(
                                label, selected, () => setState(() {
                                      _category = c;
                                    }));
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (tests.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(tr(ref, 'lab.noTests'),
                              style: FdType.body(ur,
                                  color: FdColors.muted)),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                              FdDim.cardRadius),
                          border: Border.all(color: FdColors.line),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        child: Column(
                          children: [
                            for (var i = 0; i < tests.length; i++) ...[
                              _testRow(ur, tests[i]),
                              if (i < tests.length - 1)
                                const Divider(
                                    color: FdColors.line, height: 1),
                            ],
                          ],
                        ),
                      ),
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
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    if (hasCall)
                      Expanded(
                        child: FdButton(
                          label: tr(ref, 'doc.call'),
                          icon: Icons.phone_outlined,
                          isUrdu: ur,
                          onTap: () => callNumber(context, lab.phone),
                        ),
                      ),
                    if (hasCall) const SizedBox(width: 12),
                    Expanded(
                      child: FdButton(
                        label: tr(ref, 'lab.viewOnMap'),
                        icon: Icons.location_on_outlined,
                        style: FdButtonStyle.outline,
                        isUrdu: ur,
                        onTap: () => openDirections(
                            context, lab.lat, lab.lng, lab.name),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      height: 240,
      color: FdColors.labHeader,
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.science_outlined,
              size: 110,
              color: FdColors.lavenderInk.withValues(alpha: 0.35),
            ),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_right
                            : Icons.chevron_left,
                        color: FdColors.ink,
                        size: 30,
                      ),
                    ),
                  ),
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
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: open ? FdColors.mint : FdColors.redSoft,
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
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
            size: 14,
            w: FontWeight.w700,
            color: open ? FdColors.primary : FdColors.redInk),
      ),
    );
  }

  /// Category chip: dark ink when selected (matches the design).
  Widget _catChip(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? FdColors.ink : Colors.white,
      borderRadius: BorderRadius.circular(FdDim.pillRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
        onTap: onTap,
        child: Container(
          height: FdDim.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FdDim.pillRadius),
            border: selected
                ? null
                : Border.all(color: FdColors.line, width: 1.4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: FdType.latin,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : FdColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _testRow(bool ur, LabTestPrice t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.test,
                    style: FdType.body(ur,
                        size: 17,
                        w: FontWeight.w700,
                        color: FdColors.ink)),
                if (t.category.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(t.category,
                      style: FdType.body(ur,
                          size: 14, color: FdColors.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            fill(tr(ref, 'rs'), {'p': '${t.price}'}),
            style: FdType.body(ur,
                size: 18, w: FontWeight.w700, color: FdColors.primary),
          ),
        ],
      ),
    );
  }
}
