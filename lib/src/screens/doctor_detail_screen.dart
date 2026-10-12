import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../models/day_hours.dart';
import '../models/doctor.dart';
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

/// Compact weekly summary, e.g. "Mon–Sat 9 AM–9 PM · Sun closed".
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

/// Doctor profile — design page-07: peach header with initials watermark,
/// rating pill, live status card, fee/parking cards, clinic photos, info
/// card, sticky Call / WhatsApp / directions bar.
class DoctorDetailScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const DoctorDetailScreen({super.key, required this.doctorId});

  @override
  ConsumerState<DoctorDetailScreen> createState() =>
      _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen> {
  late final Future<Doctor?> _doctorFuture;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(repositoryProvider);
    _doctorFuture = repo.getDoctor(widget.doctorId);
    repo.recordProfileView(widget.doctorId);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);

    return Scaffold(
      backgroundColor: FdColors.bg,
      body: FutureBuilder(
        future: _doctorFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data;
          if (d == null) {
            return Center(child: Text(tr(ref, 'error')));
          }
          final status = computeOpenStatus(d.hours, DateTime.now());
          final onLeave =
              d.leaveTill != null && d.leaveTill!.trim().isNotEmpty;
          return Column(
            children: [
              _header(context, ref, d.name),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      FdDim.page, 20, FdDim.page, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(d.name,
                              style: FdType.title(ur, size: 26)),
                        ),
                        if (d.verified) ...[
                          const SizedBox(width: 10),
                          const FdVerifiedBadge(size: 26),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      specialtyLabel(locale, d.specialty),
                      style: FdType.body(ur,
                          size: 17,
                          w: FontWeight.w600,
                          color: FdColors.primary),
                    ),
                    if (d.qualification.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        d.qualification,
                        style: FdType.body(ur,
                            size: 15, color: FdColors.muted),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _reviewsPill(ref, ur, d.rating, d.reviewCount),
                    const SizedBox(height: 14),
                    _statusCard(ref, ur, status, onLeave, d.leaveTill),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _factCard(
                            ur,
                            tr(ref, 'doc.consultationFee'),
                            d.fee != null
                                ? fill(tr(ref, 'rs'), {'p': _fmtFee(d.fee!)})
                                : '–',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _factCard(
                            ur,
                            tr(ref, 'doc.parking'),
                            d.hasParking
                                ? tr(ref, 'doc.available')
                                : tr(ref, 'doc.notAvailable'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    FdSectionHeader(
                        title: tr(ref, 'doc.clinicPhotos'), isUrdu: ur),
                    const SizedBox(height: 12),
                    _photos(ref, ur, d.clinicPhotos),
                    const SizedBox(height: 22),
                    FdSectionHeader(
                        title: tr(ref, 'doc.clinic'), isUrdu: ur),
                    const SizedBox(height: 12),
                    FdInfoCard(
                      isUrdu: ur,
                      rows: [
                        if (d.clinicName.trim().isNotEmpty)
                          FdInfoRow(
                              tr(ref, 'doc.clinicName'), d.clinicName),
                        if (d.address.trim().isNotEmpty)
                          FdInfoRow(tr(ref, 'doc.address'), d.address),
                        FdInfoRow(
                            tr(ref, 'doc.hours'), _hoursSummary(d.hours)),
                      ],
                    ),
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

  // ---------- header ----------

  Widget _header(BuildContext context, WidgetRef ref, String name) {
    final saved = ref.watch(_savedDoctorsProvider).contains(widget.doctorId);
    return Container(
      height: 270,
      color: FdColors.doctorHeader,
      child: Stack(
        children: [
          Center(
            child: Text(
              _initials(name),
              style: const TextStyle(
                fontFamily: FdType.latin,
                fontSize: 110,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE3B57E),
                letterSpacing: 2,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    iconColor: saved ? FdColors.primary : FdColors.ink,
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
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = FdColors.ink,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: iconColor, size: 30),
        ),
      ),
    );
  }

  // ---------- body widgets ----------

  Widget _reviewsPill(
      WidgetRef ref, bool ur, double rating, int reviewCount) {
    if (reviewCount <= 0) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: _openReviews,
          child: FdNewPill(label: tr(ref, 'doc.newReviews'), isUrdu: ur),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _openReviews,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(FdDim.pillRadius),
            border: Border.all(color: FdColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: FdColors.starGold, size: 20),
              const SizedBox(width: 8),
              Text(
                rating.toStringAsFixed(1),
                style: FdType.body(ur,
                    size: 17, w: FontWeight.w700, color: FdColors.ink),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${fill(tr(ref, 'doc.reviewsCount'), {'n': '$reviewCount'})}',
                style: FdType.body(ur, size: 16, color: FdColors.muted),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  color: FdColors.muted, size: 22),
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
      dot = FdColors.amberStrong;
    } else if (status.isOpen) {
      line1 = tr(ref, 'doc.currentlyOpen');
      line2 = status.transitionAt != null
          ? fill(tr(ref, 'doc.openUntilToday'),
              {'time': formatTime12(status.transitionAt!)})
          : '';
      dot = const Color(0xFF22A06B);
    } else {
      line1 = tr(ref, 'doc.currentlyClosed');
      line2 = status.transitionAt != null
          ? fill(tr(ref, 'doc.opensAt'),
              {'time': formatTime12(status.transitionAt!)})
          : '';
      dot = FdColors.muted;
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FdColors.mint,
        borderRadius: BorderRadius.circular(FdDim.bannerRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line1,
                    style: FdType.body(ur,
                        size: 17, w: FontWeight.w700, color: FdColors.ink)),
                if (line2.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(line2,
                      style: FdType.body(ur,
                          size: 15, color: FdColors.inkSoft)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            tr(ref, 'doc.updatedByDoctor'),
            style: FdType.body(ur,
                size: 14, w: FontWeight.w600, color: FdColors.primary),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  Widget _factCard(bool ur, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.bannerRadius),
        border: Border.all(color: FdColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FdType.body(ur, size: 14, color: FdColors.muted)),
          const SizedBox(height: 4),
          Text(value,
              style: FdType.body(ur,
                  size: 20, w: FontWeight.w700, color: FdColors.ink)),
        ],
      ),
    );
  }

  Widget _photos(WidgetRef ref, bool ur, List<String> photos) {
    if (photos.isNotEmpty) {
      return SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _PhotoTile(path: photos[i]),
        ),
      );
    }
    final tiles = [
      (FdColors.mint, FdColors.primary, tr(ref, 'doc.reception')),
      (FdColors.lavender, FdColors.lavenderInk, tr(ref, 'doc.waitingArea')),
      (FdColors.redSoft, FdColors.redInk, tr(ref, 'doc.consultingRoom')),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.18,
              child: Container(
                decoration: BoxDecoration(
                  color: tiles[i].$1,
                  borderRadius: BorderRadius.circular(FdDim.bannerRadius),
                ),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.bottomLeft,
                child: Text(
                  tiles[i].$3,
                  style: FdType.body(ur,
                      size: 14, w: FontWeight.w700, color: tiles[i].$2),
                ),
              ),
            ),
          ),
          if (i < tiles.length - 1) const SizedBox(width: 12),
        ],
      ],
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
                  flex: 3,
                  child: FdButton(
                    label: tr(ref, 'doc.call'),
                    icon: Icons.phone_outlined,
                    isUrdu: ur,
                    onTap: () => callNumber(context, phone),
                  ),
                ),
              if (hasCall && hasWa) const SizedBox(width: 12),
              if (hasWa)
                Expanded(
                  flex: 4,
                  child: FdButton(
                    label: tr(ref, 'doc.whatsapp'),
                    icon: Icons.chat_bubble_outline,
                    style: FdButtonStyle.outline,
                    isUrdu: ur,
                    onTap: () => openWhatsapp(
                      context,
                      ref,
                      waNumber,
                      doctorId: widget.doctorId,
                    ),
                  ),
                ),
              if (hasCall || hasWa) const SizedBox(width: 12),
              if (showPinOnly)
                Expanded(
                  child: FdButton(
                    label: tr(ref, 'lab.viewOnMap'),
                    icon: Icons.location_on_outlined,
                    style: FdButtonStyle.outline,
                    isUrdu: ur,
                    onTap: () => openDirections(context, lat, lng, name),
                  ),
                )
              else
                SizedBox(
                  width: 62,
                  height: FdDim.buttonHeight,
                  child: Material(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(FdDim.bannerRadius),
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(FdDim.bannerRadius),
                      onTap: () =>
                          openDirections(context, lat, lng, name),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(FdDim.bannerRadius),
                          border:
                              Border.all(color: FdColors.line, width: 1.4),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.location_on_outlined,
                            color: FdColors.ink, size: 28),
                      ),
                    ),
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
    return AspectRatio(
      aspectRatio: 1.18,
      child: Container(
        decoration: BoxDecoration(
          color: FdColors.mint,
          borderRadius: BorderRadius.circular(FdDim.bannerRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: img,
      ),
    );
  }
}
