import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../design/tokens.dart';
import '../l10n/strings.dart';
import '../l10n/strings_b.dart';
import '../models/day_hours.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../providers/providers.dart';
import '../utils/actions.dart';
import '../utils/geo.dart';
import '../utils/open_status.dart';
import '../widgets/theme.dart';
import 'doctor_detail_screen.dart';
import 'emergency_screen.dart';
import 'search_screen.dart';

/// Home tab (design pages 03/04): city + language row, title, emergency
/// banner, search, specialty chips, top-rated lime card, doctor list.
/// Body-only — the bottom nav lives in HomeShell.
///
/// Pixel pass: all sizes / radii / colors below are taken literally from
/// design/fauridoc-screens.html (1 CSS px = 1 logical px). Private `_`-prefixed
/// widgets are used wherever the shared theme widgets don't match the spec.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

// ---------------------------------------------------------------------------
// Stream providers (file-private).
// ---------------------------------------------------------------------------

final _homeDoctorsProvider = StreamProvider.autoDispose
    .family<List<Doctor>, ({String city, String? specialty})>(
  (ref, args) => ref
      .watch(repositoryProvider)
      .watchDoctors(city: args.city, specialty: args.specialty),
);

final _homeHospitalsProvider =
    StreamProvider.autoDispose.family<List<Hospital>, String>(
  (ref, city) => ref.watch(repositoryProvider).watchHospitals(city: city),
);

final _homeCitiesProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref.watch(repositoryProvider).watchCities(),
);

final _homeSpecialtiesProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref.watch(repositoryProvider).watchSpecialties(),
);

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _specialty; // null = All
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
      // Location unavailable — distances are simply omitted.
    }
  }

  // -- helpers ---------------------------------------------------------------

  double? _distanceKm(double? lat, double? lng) {
    final p = _pos;
    if (p == null || lat == null || lng == null) return null;
    return haversineKm(p.latitude, p.longitude, lat, lng);
  }

  /// "20:00" -> "8 PM".
  String _fmtTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final suffix = h >= 12 ? 'PM' : 'AM';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return m == '00' ? '$h12 $suffix' : '$h12:$m $suffix';
  }

  String _dayName(String key, WidgetRef ref) {
    switch (key) {
      case 'mon':
        return trB(ref, 'home.dayMon');
      case 'tue':
        return trB(ref, 'home.dayTue');
      case 'wed':
        return trB(ref, 'home.dayWed');
      case 'thu':
        return trB(ref, 'home.dayThu');
      case 'fri':
        return trB(ref, 'home.dayFri');
      case 'sat':
        return trB(ref, 'home.daySat');
      default:
        return trB(ref, 'home.daySun');
    }
  }

  /// "Mon 5–8 PM" pills, up to 4 days.
  List<String> _dayPills(Doctor d, WidgetRef ref) {
    final out = <String>[];
    for (final k in weekdayKeys) {
      final h = d.hours[k];
      if (h == null || h.closed) continue;
      out.add('${_dayName(k, ref)} ${_fmtTime(h.open)}–${_fmtTime(h.close)}');
      if (out.length == 4) break;
    }
    return out;
  }

  String _openText(Doctor d, WidgetRef ref) {
    if (_onLeave(d)) {
      return fill(trB(ref, 'home.onLeaveTill'),
          {'date': d.leaveTill!.trim()});
    }
    final st = computeOpenStatus(d.hours, DateTime.now());
    if (st.isOpen && st.transitionAt != null) {
      return fill(
          trB(ref, 'home.openNowUntil'), {'time': _fmtTime(st.transitionAt!)});
    }
    if (!st.isOpen && st.transitionAt != null) {
      return fill(trB(ref, 'home.closedOpensAt'),
          {'time': _fmtTime(st.transitionAt!)});
    }
    return trB(ref, 'home.closed');
  }

  bool _isOpen(Doctor d) => computeOpenStatus(d.hours, DateTime.now()).isOpen;

  bool _onLeave(Doctor d) =>
      d.leaveTill != null && d.leaveTill!.trim().isNotEmpty;

  Color _statusColor(Doctor d) => _onLeave(d)
      ? FdSpec.leaveOrange
      : (_isOpen(d) ? FdSpec.openGreen : FdSpec.closedGrey);

  Doctor? _featured(List<Doctor> doctors) {
    if (doctors.isEmpty) return null;
    final rated = doctors
        .where((d) => d.verified && d.rating > 0 && d.reviewCount > 0)
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    if (rated.isNotEmpty) return rated.first;
    final verified = doctors.where((d) => d.verified).toList();
    return verified.isNotEmpty ? verified.first : doctors.first;
  }

  Hospital? _nearestEmergency(List<Hospital> hospitals) {
    if (hospitals.isEmpty) return null;
    return hospitals.firstWhere(
      (h) => h.emergency247,
      orElse: () => hospitals.first,
    );
  }

  Future<void> _showCitySheet() async {
    final cities =
        await ref.read(_homeCitiesProvider.future).catchError((_) => <String>[]);
    if (!mounted) return;
    final current = ref.read(cityProvider);
    final ur = fdIsUrdu(ref.read(localeProvider));
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: FdColors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                trB(ref, 'home.chooseCity'),
                style: FdType.title(ur, size: 20),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in cities)
                    ListTile(
                      title: Text(c,
                          style: FdType.body(ur,
                              size: 16,
                              w: FontWeight.w600,
                              color: FdColors.ink)),
                      trailing: c == current
                          ? const Icon(Icons.check, color: FdColors.primary)
                          : null,
                      onTap: () {
                        ref.read(cityProvider.notifier).setCity(c);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDoctor(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DoctorDetailScreen(doctorId: id)),
    );
  }

  void _openEmergency() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyScreen()),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  // -- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final city = ref.watch(cityProvider);

    final doctorsAsync =
        ref.watch(_homeDoctorsProvider((city: city, specialty: _specialty)));
    final hospitalsAsync = ref.watch(_homeHospitalsProvider(city));

    return Scaffold(
      backgroundColor: FdColors.bg,
      // Spec artboard is edge-to-edge: scroll padding already includes the
      // 52/48px status-bar area, so the top safe-area inset is disabled.
      body: SafeArea(
        top: false,
        bottom: false,
        child: doctorsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: FdColors.primary)),
          error: (_, _) => const SizedBox.shrink(),
          data: (doctors) => hospitalsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: FdColors.primary)),
            error: (_, _) => const SizedBox.shrink(),
            data: (hospitals) => _body(
              context,
              doctors,
              hospitals,
              city,
              locale,
              ur,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<Doctor> doctors,
    List<Hospital> hospitals,
    String city,
    String locale,
    bool ur,
  ) {
    final featured = _featured(doctors);
    final rest = featured == null
        ? doctors
        : doctors.where((d) => d.id != featured.id).toList();
    final emergency = _nearestEmergency(hospitals);

    // Spec scroll padding: 52 20 16 (EN) / 48 20 16 (UR).
    // The horizontal page padding lives on the individual children (not the
    // scroll view) so the specialty chips row can bleed edge-to-edge without
    // negative margins, which assert in debug builds.
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: ur ? 48 : 52, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _topRow(city, ur),
          ),
          SizedBox(height: ur ? 10 : 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              trB(ref, 'home.title'),
              style: TextStyle(
                fontFamily: FdType.family(ur),
                // EN: 28/800, lh 1.12, ls -0.02em. UR: 25/700, lh 1.75.
                fontSize: ur ? (28) * 0.9 : (28),
                fontWeight: ur ? FontWeight.w700 : FontWeight.w800,
                color: FdSpec.ink,
                height: ur ? 1.75 : 1.12,
                letterSpacing: ur ? 0 : -0.56,
              ),
            ),
          ),
          if (emergency != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _emergencyBanner(emergency, ur),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _searchBox(ur),
          ),
          // Full-bleed: no horizontal page padding here, so the chips row
          // scrolls edge-to-edge (it carries its own 20px scroll padding).
          _specialtyChips(locale, ur),
          if (featured != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _featuredCard(featured, locale, ur),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _sectionHeader(
              title: fill(trB(ref, 'home.moreDoctorsIn'), {'city': city}),
              action: trB(ref, 'home.topRated'),
              ur: ur,
            ),
          ),
          if (rest.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 24),
              child: Text(
                fill(trB(ref, 'home.noDoctors'), {'city': city}),
                style: FdType.body(ur, color: FdColors.muted),
              ),
            )
          else
            // Spec: list margin-top 12 (EN) / 4 (UR), gap 12.
            Padding(
              padding: EdgeInsets.fromLTRB(20, ur ? 4 : 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rest.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _doctorCard(rest[i], i, locale, ur),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // -- sections ---------------------------------------------------------------

  /// Spec: city pill h44, radius 22, 1px border, 14/700 text, 18px pin,
  /// 14px chevron; language toggle 44 circle (EN) / h44 pill (UR), 13/700.
  Widget _topRow(String city, bool ur) {
    return Row(
      children: [
        _FdPress(
          onTap: _showCitySheet,
          child: Container(
            height: 44,
            padding:
                EdgeInsets.fromLTRB(ur ? 14 : 10, 0, ur ? 10 : 14, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: FdSpec.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_outlined,
                    color: FdSpec.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  city,
                  style: TextStyle(
                    fontFamily: FdType.family(ur),
                    fontSize: ur ? (14) * 0.9 : (14),
                    fontWeight: ur ? FontWeight.w600 : FontWeight.w700,
                    color: FdSpec.ink,
                    height: ur ? 1.4 : null,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more, color: FdSpec.muted, size: 14),
              ],
            ),
          ),
        ),
        const Spacer(),
        _FdPress(
          onTap: () => ref.read(localeProvider.notifier).toggle(),
          child: ur
              // UR mode: "English" pill, 13/700 Albert Sans.
              ? Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: FdSpec.border),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'English',
                    style: TextStyle(
                      fontFamily: FdSpec.latinFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: FdSpec.ink,
                      height: 1,
                    ),
                  ),
                )
              // EN mode: 44x44 circle, "اردو" 13/700 (Latin family per spec).
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: FdSpec.border),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'اردو',
                    style: TextStyle(
                      fontFamily: FdSpec.latinFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: FdSpec.ink,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  /// Spec: red card, radius 16, padding 12 14 (EN) / 10 14 (UR); 40x40 icon
  /// tile radius 12, white 0.18; title 16/800; subtitle 12/500 white 0.92;
  /// 20px chevron (mirrored in RTL).
  Widget _emergencyBanner(Hospital h, bool ur) {
    final dist = _distanceKm(h.lat, h.lng);
    final sub = [
      h.name,
      if (dist != null) formatDistance(dist),
      if (h.emergency247) trB(ref, 'home.open247'),
    ].join(' · ');
    return _FdPress(
      onTap: _openEmergency,
      child: Container(
        margin: EdgeInsets.only(top: ur ? 10 : 18),
        padding:
            EdgeInsets.symmetric(horizontal: 14, vertical: ur ? 10 : 12),
        decoration: BoxDecoration(
          color: FdSpec.emergencyRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.add, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trB(ref, 'home.nearestEmergency'),
                    style: TextStyle(
                      fontFamily: FdType.family(ur),
                      fontSize: ur ? (16) * 0.9 : (16),
                      fontWeight:
                          ur ? FontWeight.w700 : FontWeight.w800,
                      color: Colors.white,
                      height: ur ? 1.8 : null,
                    ),
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: FdType.family(ur),
                      fontSize: ur ? (12) * 0.9 : (12),
                      fontWeight:
                          ur ? FontWeight.w400 : FontWeight.w500,
                      color: Colors.white
                          .withValues(alpha: ur ? 0.95 : 0.92),
                      height: ur ? 1.8 : null,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              ur ? Icons.chevron_left : Icons.chevron_right,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Spec: margin-top 12, height 48 (EN) / 50 (UR), radius 14, 1px border,
  /// 15/500 (EN) / 14/400 (UR) placeholder in muted, 20px search icon.
  Widget _searchBox(bool ur) {
    return _FdPress(
      onTap: _openSearch,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        height: ur ? 50 : 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FdSpec.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: FdSpec.muted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                trB(ref, 'home.searchHint'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: FdType.family(ur),
                  fontSize: ur ? (15) * 0.9 : (15),
                  fontWeight: ur ? FontWeight.w400 : FontWeight.w500,
                  color: FdSpec.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Spec: full-bleed row (margin-top 14 EN / 12 UR, inner scroll padding
  /// 0 20, gap 8); chips h40 (EN) / h42 (UR), padding 0 16, 14/600 (EN) /
  /// 13/500 (UR); selected = teal fill. Full-bleed works because the scroll
  /// view carries no horizontal page padding (each sibling pads itself).
  Widget _specialtyChips(String locale, bool ur) {
    final specsAsync = ref.watch(_homeSpecialtiesProvider);
    return Container(
      margin: EdgeInsets.only(top: ur ? 12 : 14),
      child: specsAsync.when(
        loading: () => const SizedBox(height: 40),
        error: (_, _) => const SizedBox.shrink(),
        data: (specs) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _chip(
                label: trB(ref, 'home.all'),
                selected: _specialty == null,
                ur: ur,
                onTap: () => setState(() => _specialty = null),
              ),
              for (final s in specs) ...[
                const SizedBox(width: 8),
                _chip(
                  label: specialtyLabel(locale, s),
                  selected: _specialty == s,
                  ur: ur,
                  onTap: () => setState(() => _specialty = s),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required bool ur,
    required VoidCallback onTap,
  }) {
    return _FdPress(
      onTap: onTap,
      child: Container(
        height: ur ? 42 : 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? FdSpec.primary : Colors.white,
          borderRadius: BorderRadius.circular(ur ? 21 : 20),
          border: Border.all(
              color: selected ? FdSpec.primary : FdSpec.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: FdType.family(ur),
            fontSize: ur ? (14) * 0.9 : (14),
            fontWeight: ur ? FontWeight.w500 : FontWeight.w600,
            color: selected ? Colors.white : FdSpec.ink,
            height: ur ? 1 : null,
          ),
        ),
      ),
    );
  }

  // -- doctor cards ------------------------------------------------------------

  /// Spec: margin-top 18 (EN) / 14 (UR), padding 16, radius 26, lime bg.
  Widget _featuredCard(Doctor d, String locale, bool ur) {
    final dist = _distanceKm(d.lat, d.lng);
    final pills = _dayPills(d, ref);
    final specialtyLine = [
      specialtyLabel(locale, d.specialty),
      if (dist != null) formatDistance(dist),
    ].join(' · ');
    final addressLine = [
      if (d.clinicName.isNotEmpty) d.clinicName,
      if (d.address.isNotEmpty) d.address,
      d.city,
    ].where((s) => s.isNotEmpty).join(', ');

    final nameStyle = TextStyle(
      fontFamily: FdType.family(ur),
      fontSize: ur ? (20) * 0.9 : (20),
      fontWeight: ur ? FontWeight.w700 : FontWeight.w800,
      color: FdSpec.ink,
      height: ur ? 1.8 : 1.15,
      letterSpacing: ur ? 0 : -0.3,
    );
    final statusStyle = TextStyle(
      fontFamily: FdType.family(ur),
      fontSize: ur ? (13) * 0.9 : (13),
      fontWeight: ur ? FontWeight.w600 : FontWeight.w700,
      color: FdSpec.ink,
      height: ur ? 1.8 : null,
    );

    Widget statusRow() => Row(
          children: [
            _statusDot(color: _statusColor(d)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(_openText(d, ref), style: statusStyle),
            ),
          ],
        );

    Widget addressRow() => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined,
                size: ur ? 14 : 13,
                color: ur ? FdSpec.limeInk : FdSpec.secondary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                addressLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: FdType.family(ur),
                  fontSize: ur ? (12.5) * 0.9 : (12.5),
                  fontWeight: FontWeight.w600,
                  color: ur ? FdSpec.limeInk : FdSpec.secondary,
                  height: ur ? 1.7 : 1.35,
                ),
              ),
            ),
          ],
        );

    return Container(
      margin: EdgeInsets.only(top: ur ? 14 : 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FdSpec.lime,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: star + "TOP RATED NEAR YOU" 12/800 ls 0.08em limeInk
          // (UR: 13/600, not uppercased) + rating pill.
          Row(
            children: [
              const Icon(Icons.star, color: FdSpec.limeInk, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ur
                      ? trB(ref, 'home.topRatedNearYou')
                      : trB(ref, 'home.topRatedNearYou').toUpperCase(),
                  style: TextStyle(
                    fontFamily: FdType.family(ur),
                    fontSize: ur ? (12) * 0.9 : (12),
                    fontWeight:
                        ur ? FontWeight.w600 : FontWeight.w800,
                    letterSpacing: ur ? 0 : 0.96,
                    color: FdSpec.limeInk,
                  ),
                ),
              ),
              if (d.reviewCount > 0)
                _featuredRatingPill(d.rating, d.reviewCount, ur)
              else
                FdNewPill(label: trB(ref, 'home.new'), isUrdu: ur),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: ur ? 8 : 12),
            child: Row(
              children: [
                _avatar(
                  d.name,
                  ur,
                  size: ur ? 64 : 68,
                  radius: 20,
                  fontSize: ur ? (24) * 0.9 : (24),
                  weight: ur ? FontWeight.w700 : FontWeight.w800,
                  color: FdSpec.darkGreen,
                  textHeight: ur ? 1 : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(d.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: nameStyle),
                          ),
                          if (d.verified) ...[
                            const SizedBox(width: 6),
                            const FdVerifiedBadge(size: 18),
                          ],
                        ],
                      ),
                      Text(
                        specialtyLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: FdType.family(ur),
                          fontSize: ur ? (14) * 0.9 : (14),
                          fontWeight:
                              ur ? FontWeight.w500 : FontWeight.w600,
                          color: FdSpec.limeInk,
                          height: ur ? 1.8 : null,
                        ),
                      ),
                      // UR spec order: status before address.
                      if (ur) statusRow() else addressRow(),
                      if (ur) addressRow() else statusRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 2x2 working-hour chips.
          if (pills.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: ur ? 10 : 14),
              child: Column(
                children: [
                  for (var r = 0; r < pills.length; r += 2)
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: r + 2 < pills.length ? 8 : 0),
                      child: Row(
                        children: [
                          Expanded(child: _hourCell(pills[r], ur)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: r + 1 < pills.length
                                ? _hourCell(pills[r + 1], ur)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          // Buttons: h50 radius 25, 15/700 (EN) / 14/600 (UR).
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: _pillButton(
                    label: trB(ref, 'home.viewProfile'),
                    onTap: () => _openDoctor(d.id),
                    bg: Colors.white,
                    fg: FdSpec.ink,
                    height: 50,
                    fontSize: ur ? (15) * 0.9 : (15),
                    weight:
                        ur ? FontWeight.w600 : FontWeight.w700,
                    textHeight: ur ? 1 : null,
                    ur: ur,
                  ),
                ),
                if (d.phone.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _pillButton(
                      label: trB(ref, 'home.call'),
                      icon: Icons.phone_outlined,
                      onTap: () => callNumber(context, d.phone),
                      bg: FdSpec.ink,
                      fg: Colors.white,
                      height: 50,
                      fontSize: ur ? (15) * 0.9 : (15),
                      weight:
                          ur ? FontWeight.w600 : FontWeight.w700,
                      textHeight: ur ? 1 : null,
                      ur: ur,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Spec: h40 (EN) / h42 (UR), radius 20/21, white 0.62 bg,
  /// 13/700 (EN) / 12.5/500 (UR).
  Widget _hourCell(String text, bool ur) {
    return Container(
      height: ur ? 42 : 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(ur ? 21 : 20),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: FdType.family(ur),
          fontSize: ur ? (13) * 0.9 : (13),
          fontWeight: ur ? FontWeight.w500 : FontWeight.w700,
          color: FdSpec.ink,
          height: ur ? 1 : null,
        ),
      ),
    );
  }

  /// Spec list card: padding 12, radius 22, pastel bg; 56x56 avatar r16;
  /// name 16/800 + 16px tick; specialty 13/600; rating pill; white stat
  /// strip (Fee/Distance/Reviews, 1px dividers); 13/700 status; 12.5/600
  /// address; h46 buttons 14/700.
  Widget _doctorCard(Doctor d, int index, String locale, bool ur) {
    final dist = _distanceKm(d.lat, d.lng);
    final addressLine = [
      if (d.clinicName.isNotEmpty) d.clinicName,
      if (d.address.isNotEmpty) d.address,
      d.city,
    ].where((s) => s.isNotEmpty).join(', ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FdColors.tintForIndex(index),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _avatar(
                d.name,
                ur,
                size: 56,
                radius: 16,
                fontSize: ur ? (19) * 0.9 : (19),
                weight: ur ? FontWeight.w700 : FontWeight.w800,
                color: FdSpec.ink,
                textHeight: ur ? 1 : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: FdType.family(ur),
                              fontSize: ur ? (16) * 0.9 : (16),
                              fontWeight: ur
                                  ? FontWeight.w700
                                  : FontWeight.w800,
                              color: FdSpec.ink,
                              height: ur ? 1.8 : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        if (d.verified) const FdVerifiedBadge(size: 16),
                      ],
                    ),
                    Text(
                      specialtyLabel(locale, d.specialty),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: FdType.family(ur),
                        fontSize: ur ? (13) * 0.9 : (13),
                        fontWeight:
                            ur ? FontWeight.w500 : FontWeight.w600,
                        color: FdSpec.secondary,
                        height: ur ? 1.8 : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (d.reviewCount > 0)
                _ratingPill(d.rating, ur)
              else
                FdNewPill(label: trB(ref, 'home.new'), isUrdu: ur),
            ],
          ),
          // Stat strip.
          Container(
            margin: EdgeInsets.only(top: ur ? 8 : 10),
            padding: EdgeInsets.symmetric(vertical: ur ? 6 : 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                if (d.fee != null)
                  _stat(trB(ref, 'home.fee'), 'Rs ${d.fee}', ur),
                if (d.fee != null && dist != null) _statDivider(),
                if (dist != null)
                  _stat(
                      trB(ref, 'home.distance'), formatDistance(dist), ur),
                if (dist != null) _statDivider(),
                _stat(
                  trB(ref, 'home.reviews'),
                  d.reviewCount > 0 ? '${d.reviewCount}' : '–',
                  ur,
                  latinDigits: true,
                ),
              ],
            ),
          ),
          // Status line.
          Padding(
            padding: EdgeInsets.only(top: ur ? 6 : 10),
            child: Row(
              children: [
                _statusDot(color: _statusColor(d)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _openText(d, ref),
                    style: TextStyle(
                      fontFamily: FdType.family(ur),
                      fontSize: ur ? (13) * 0.9 : (13),
                      fontWeight:
                          ur ? FontWeight.w600 : FontWeight.w700,
                      color: FdSpec.ink,
                      height: ur ? 1.9 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Address line.
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: FdSpec.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    addressLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: FdType.family(ur),
                      fontSize: ur ? (12.5) * 0.9 : (12.5),
                      fontWeight: FontWeight.w600,
                      color: FdSpec.secondary,
                      height: ur ? 1.7 : 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Buttons: h46 radius 23, 14/700 (EN) / 13/600 (UR).
          Padding(
            padding: EdgeInsets.only(top: ur ? 8 : 10),
            child: Row(
              children: [
                Expanded(
                  child: _pillButton(
                    label: trB(ref, 'home.viewProfile'),
                    // EN list cards have an eye icon; UR has none.
                    icon: ur ? null : Icons.visibility_outlined,
                    onTap: () => _openDoctor(d.id),
                    bg: Colors.white,
                    fg: FdSpec.ink,
                    height: 46,
                    fontSize: ur ? (14) * 0.9 : (14),
                    weight:
                        ur ? FontWeight.w600 : FontWeight.w700,
                    textHeight: ur ? 1 : null,
                    ur: ur,
                  ),
                ),
                if (d.phone.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _pillButton(
                      label: trB(ref, 'search.callNow'),
                      icon: Icons.phone_outlined,
                      iconSize: ur ? 17 : 18,
                      onTap: () => callNumber(context, d.phone),
                      bg: FdSpec.ink,
                      fg: Colors.white,
                      height: 46,
                      fontSize: ur ? (14) * 0.9 : (14),
                      weight:
                          ur ? FontWeight.w600 : FontWeight.w700,
                      textHeight: ur ? 1 : null,
                      ur: ur,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Spec: 18/800 ls -0.01em (EN) / 17/700 (UR) title; 13/600 (EN) /
  /// 12.5/500 (UR) primary action.
  Widget _sectionHeader({
    required String title,
    required String action,
    required bool ur,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: ur ? 12 : 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: FdType.family(ur),
                fontSize: ur ? (18) * 0.9 : (18),
                fontWeight:
                    ur ? FontWeight.w700 : FontWeight.w800,
                letterSpacing: ur ? 0 : -0.18,
                color: FdSpec.ink,
              ),
            ),
          ),
          _FdPress(
            onTap: _openSearch,
            child: Text(
              action,
              style: TextStyle(
                fontFamily: FdType.family(ur),
                fontSize: ur ? (13) * 0.9 : (13),
                fontWeight:
                    ur ? FontWeight.w500 : FontWeight.w600,
                color: FdSpec.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- spec-exact private widgets ---------------------------------------------

  /// White initials avatar tile.
  Widget _avatar(
    String name,
    bool ur, {
    required double size,
    required double radius,
    required double fontSize,
    required FontWeight weight,
    required Color color,
    double? textHeight,
  }) {
    final initials = name
        .replaceFirst(RegExp(r'^Dr\.\s*'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '•' : initials,
        style: TextStyle(
          fontFamily: FdType.family(ur),
          fontSize: ur ? fontSize * 0.9 : fontSize,
          fontWeight: weight,
          color: color,
          height: textHeight,
        ),
      ),
    );
  }

  /// List-card rating pill: white, radius 14, padding 5 10 (EN) / 3 10
  /// (UR), 13px gold star + 13/800 rating.
  Widget _ratingPill(double rating, bool ur) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 10, vertical: ur ? 3 : 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: FdSpec.star, size: 13),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontFamily: FdSpec.latinFont,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: FdSpec.ink,
              height: ur ? 1.5 : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Featured-card rating pill: white, radius 15, padding 5 12 (EN) /
  /// 2 12 (UR), "4.9 (186)" — numbers always in Albert Sans.
  Widget _featuredRatingPill(double rating, int count, bool ur) {
    TextStyle num(bool strong) => TextStyle(
          fontFamily: FdSpec.latinFont,
          fontSize: 13,
          fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          color: strong ? FdSpec.ink : FdSpec.muted,
          height: ur ? 1.8 : null,
        );
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 12, vertical: ur ? 2 : 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: rating.toStringAsFixed(1), style: num(true)),
          TextSpan(text: '  ($count)', style: num(false)),
        ]),
      ),
    );
  }

  /// 9px status dot with 2px white ring.
  Widget _statusDot({required Color color}) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.white, spreadRadius: 2),
        ],
      ),
    );
  }

  /// Full-width spec button: height 50/46, radius = height/2.
  Widget _pillButton({
    required String label,
    required VoidCallback? onTap,
    required Color bg,
    required Color fg,
    required double height,
    required double fontSize,
    required FontWeight weight,
    required bool ur,
    double? textHeight,
    IconData? icon,
    double iconSize = 18,
  }) {
    return _FdPress(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: iconSize),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: FdType.family(ur),
                  fontSize: ur ? fontSize * 0.9 : fontSize,
                  fontWeight: weight,
                  color: fg,
                  height: textHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, bool ur,
      {bool latinDigits = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: FdType.family(ur),
              fontSize: ur ? (11) * 0.9 : (11),
              fontWeight: ur ? FontWeight.w400 : FontWeight.w600,
              color: FdSpec.muted,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              // UR review counts stay in Albert Sans per spec.
              fontFamily:
                  latinDigits ? FdSpec.latinFont : FdType.family(ur),
              fontSize: ur ? (14) * 0.9 : (14),
              fontWeight: ur ? FontWeight.w700 : FontWeight.w800,
              color: FdSpec.ink,
              height: ur ? 1.7 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 34, color: FdSpec.border);
  }
}

/// Press feedback per the spec `.press` class: scale to 0.97 in 80 ms.
class _FdPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _FdPress({required this.child, this.onTap});

  @override
  State<_FdPress> createState() => _FdPressState();
}

class _FdPressState extends State<_FdPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? FdSpec.pressScale : 1,
        duration: FdSpec.pressDuration,
        child: widget.child,
      ),
    );
  }
}
