import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/hospital.dart';
import '../providers/providers.dart';
import '../providers/user_location.dart';
import '../utils/actions.dart';
import '../widgets/theme.dart';

/// Hospital profile — design page-09: pink header with plus outline,
/// red emergency-number card, info card, departments chips, sticky
/// Call emergency / Directions bar.
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
                  padding: const EdgeInsets.fromLTRB(
                      FdDim.page, 20, FdDim.page, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(h.name,
                              style: FdType.title(ur, size: 26)),
                        ),
                        if (h.verified) ...[
                          const SizedBox(width: 10),
                          const FdVerifiedBadge(size: 26),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        tr(ref, 'hosp.hospital'),
                        h.city,
                        if (dist != null)
                          fill(tr(ref, 'hosp.away'), {'d': dist}),
                      ].join(' · '),
                      style: FdType.body(ur,
                          size: 16, color: FdColors.muted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (h.reviewCount > 0) ...[
                          const Icon(Icons.star,
                              color: FdColors.starGold, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            '${h.rating.toStringAsFixed(1)}  (${fill(tr(ref, 'doc.reviewsCount'), {'n': '${h.reviewCount}'})})',
                            style: FdType.body(ur,
                                size: 17,
                                w: FontWeight.w700,
                                color: FdColors.ink),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (h.emergency247)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: FdColors.redSoft,
                              borderRadius: BorderRadius.circular(
                                  FdDim.pillRadius),
                            ),
                            child: Text(
                              tr(ref, 'hosp.emergency247'),
                              style: FdType.body(ur,
                                  size: 14,
                                  w: FontWeight.w700,
                                  color: FdColors.redInk),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _emergencyCard(ref, ur, emergencyNo),
                    const SizedBox(height: 16),
                    FdInfoCard(
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
                      ],
                    ),
                    if (h.departments.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      FdSectionHeader(
                          title: tr(ref, 'hosp.departments'),
                          isUrdu: ur),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final dep in h.departments)
                            _deptChip(ur, dep,
                                highlight: dep.trim().toLowerCase() ==
                                    tr(ref, 'hosp.emergency')
                                        .toLowerCase()),
                        ],
                      ),
                    ],
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
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: FdButton(
                        label: tr(ref, 'hosp.callEmergency'),
                        icon: Icons.phone_outlined,
                        style: FdButtonStyle.danger,
                        isUrdu: ur,
                        onTap: () => callNumber(context, emergencyNo),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FdButton(
                        label: tr(ref, 'hosp.directions'),
                        icon: Icons.navigation_outlined,
                        style: FdButtonStyle.outline,
                        isUrdu: ur,
                        onTap: () => openDirections(
                            context, h.lat, h.lng, h.name),
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
      color: FdColors.hospitalHeader,
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.add,
              size: 110,
              color: FdColors.redInk.withValues(alpha: 0.35),
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

  /// Red emergency-number card.
  Widget _emergencyCard(WidgetRef ref, bool ur, String number) {
    return GestureDetector(
      onTap: () => callNumber(context, number),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: FdColors.red,
          borderRadius: BorderRadius.circular(FdDim.bannerRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.phone_outlined,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(ref, 'hosp.emergencyNumber'),
                    style: FdType.body(false,
                        size: 14,
                        w: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    number.isEmpty ? '–' : number,
                    style: FdType.title(false, size: 24)
                        .copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Department chip — "Emergency" highlighted in red, rest white.
  Widget _deptChip(bool ur, String label, {bool highlight = false}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: highlight ? FdColors.redSoft : Colors.white,
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
        border: Border.all(
          color: highlight ? FdColors.redSoft : FdColors.line,
          width: 1.4,
        ),
      ),
      child: Text(
        label,
        style: FdType.body(ur,
            size: 16,
            w: FontWeight.w600,
            color: highlight ? FdColors.redInk : FdColors.ink),
      ),
    );
  }
}
