import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
        desiredAccuracy: LocationAccuracy.low,
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
      body: SafeArea(
        child: doctorsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: FdColors.primary)),
          error: (_, __) => const SizedBox.shrink(),
          data: (doctors) => hospitalsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: FdColors.primary)),
            error: (_, __) => const SizedBox.shrink(),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: FdDim.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _topRow(city, ur),
          const SizedBox(height: 18),
          Text(trB(ref, 'home.title'), style: FdType.display(ur, size: 34)),
          const SizedBox(height: 18),
          if (emergency != null) ...[
            _emergencyBanner(emergency, ur),
            const SizedBox(height: 16),
          ],
          FdSearchField(
            hint: trB(ref, 'home.searchHint'),
            readOnly: true,
            isUrdu: ur,
            onTap: _openSearch,
          ),
          const SizedBox(height: 16),
          _specialtyChips(locale, ur),
          const SizedBox(height: 20),
          if (featured != null) ...[
            _featuredCard(featured, locale, ur),
            const SizedBox(height: 24),
          ],
          FdSectionHeader(
            title: fill(trB(ref, 'home.moreDoctorsIn'), {'city': city}),
            actionLabel: trB(ref, 'home.topRated'),
            onAction: _openSearch,
            isUrdu: ur,
          ),
          const SizedBox(height: 14),
          if (rest.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                fill(trB(ref, 'home.noDoctors'), {'city': city}),
                style: FdType.body(ur, color: FdColors.muted),
              ),
            )
          else
            for (var i = 0; i < rest.length; i++) ...[
              _doctorCard(rest[i], i, locale, ur),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // -- sections ---------------------------------------------------------------

  Widget _topRow(String city, bool ur) {
    return Row(
      children: [
        // City pill.
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(FdDim.pillRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(FdDim.pillRadius),
            onTap: _showCitySheet,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FdDim.pillRadius),
                border: Border.all(color: FdColors.line, width: 1.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: FdColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    city,
                    style: FdType.body(ur,
                        size: 16, w: FontWeight.w700, color: FdColors.ink),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down,
                      color: FdColors.muted, size: 22),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        // Language toggle.
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => ref.read(localeProvider.notifier).toggle(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: FdColors.line, width: 1.4),
              ),
              alignment: Alignment.center,
              child: Text(
                ur ? 'EN' : 'اردو',
                style: ur
                    ? FdType.body(false,
                        size: 15, w: FontWeight.w700, color: FdColors.ink)
                    : const TextStyle(
                        fontFamily: FdType.urdu,
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: FdColors.ink,
                        height: 1.8,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emergencyBanner(Hospital h, bool ur) {
    final dist = _distanceKm(h.lat, h.lng);
    final sub = [
      h.name,
      if (dist != null) formatDistance(dist),
      if (h.emergency247) trB(ref, 'home.open247'),
    ].join(' · ');
    return Material(
      color: FdColors.red,
      borderRadius: BorderRadius.circular(FdDim.bannerRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(FdDim.bannerRadius),
        onTap: _openEmergency,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trB(ref, 'home.nearestEmergency'),
                      style: FdType.body(ur,
                          size: 18, w: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sub,
                      style: FdType.body(ur,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.88)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _specialtyChips(String locale, bool ur) {
    final specsAsync = ref.watch(_homeSpecialtiesProvider);
    return specsAsync.when(
      loading: () => const SizedBox(height: FdDim.chipHeight),
      error: (_, __) => const SizedBox.shrink(),
      data: (specs) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FdChip(
              label: trB(ref, 'home.all'),
              selected: _specialty == null,
              isUrdu: ur,
              onTap: () => setState(() => _specialty = null),
            ),
            for (final s in specs) ...[
              const SizedBox(width: 10),
              FdChip(
                label: specialtyLabel(locale, s),
                selected: _specialty == s,
                isUrdu: ur,
                onTap: () => setState(() => _specialty = s),
              ),
            ],
            const SizedBox(width: FdDim.page),
          ],
        ),
      ),
    );
  }

  // -- doctor cards ------------------------------------------------------------

  Widget _featuredCard(Doctor d, String locale, bool ur) {
    final dist = _distanceKm(d.lat, d.lng);
    final pills = _dayPills(d, ref);
    final open = _isOpen(d);
    return Container(
      decoration: BoxDecoration(
        color: FdColors.lime,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: FdColors.ink, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  trB(ref, 'home.topRatedNearYou').toUpperCase(),
                  style: FdType.label(ur,
                      size: 13, w: FontWeight.w800, color: FdColors.ink),
                ),
              ),
              if (d.reviewCount > 0)
                FdRatingPill(rating: d.rating, isUrdu: ur)
              else
                FdNewPill(label: trB(ref, 'home.new'), isUrdu: ur),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FdAvatarTile(name: d.name, size: 84, bg: Colors.white),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            d.name,
                            style: FdType.title(ur, size: 20),
                          ),
                        ),
                        if (d.verified) ...[
                          const SizedBox(width: 7),
                          const FdVerifiedBadge(size: 22),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        specialtyLabel(locale, d.specialty),
                        if (dist != null) formatDistance(dist),
                      ].join(' · '),
                      style: FdType.body(ur,
                          size: 15, w: FontWeight.w500, color: FdColors.inkSoft),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: FdColors.inkSoft),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (d.clinicName.isNotEmpty) d.clinicName,
                              if (d.address.isNotEmpty) d.address,
                              d.city,
                            ].where((s) => s.isNotEmpty).join(', '),
                            style: FdType.body(ur,
                                size: 14, color: FdColors.inkSoft),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: open ? FdColors.primary : FdColors.muted,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _openText(d, ref),
                            style: FdType.body(ur,
                                size: 15,
                                w: FontWeight.w700,
                                color: FdColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (var r = 0; r < pills.length; r += 2)
              Padding(
                padding: EdgeInsets.only(bottom: r + 2 < pills.length ? 10 : 0),
                child: Row(
                  children: [
                    Expanded(child: _timePill(pills[r], ur)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: r + 1 < pills.length
                          ? _timePill(pills[r + 1], ur)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FdButton(
                  label: trB(ref, 'home.viewProfile'),
                  style: FdButtonStyle.white,
                  isUrdu: ur,
                  onTap: () => _openDoctor(d.id),
                ),
              ),
              if (d.phone.trim().isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FdButton(
                    label: trB(ref, 'home.call'),
                    style: FdButtonStyle.dark,
                    icon: Icons.phone_outlined,
                    isUrdu: ur,
                    onTap: () => callNumber(context, d.phone),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _timePill(String text, bool ur) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: FdColors.limeLight,
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: FdType.body(ur, size: 15, w: FontWeight.w600, color: FdColors.ink),
      ),
    );
  }

  Widget _doctorCard(Doctor d, int index, String locale, bool ur) {
    final dist = _distanceKm(d.lat, d.lng);
    final open = _isOpen(d);
    return Container(
      decoration: BoxDecoration(
        color: FdColors.tintForIndex(index),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FdAvatarTile(name: d.name, size: 76, bg: Colors.white),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child:
                              Text(d.name, style: FdType.title(ur, size: 18)),
                        ),
                        if (d.verified) ...[
                          const SizedBox(width: 6),
                          const FdVerifiedBadge(size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialtyLabel(locale, d.specialty),
                      style:
                          FdType.body(ur, size: 15, color: FdColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (d.reviewCount > 0)
                FdRatingPill(rating: d.rating, isUrdu: ur)
              else
                FdNewPill(label: trB(ref, 'home.new'), isUrdu: ur),
            ],
          ),
          const SizedBox(height: 14),
          // Stats row: Fee | Distance | Reviews.
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(FdDim.bannerRadius),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                if (d.fee != null) _stat(trB(ref, 'home.fee'), 'Rs ${d.fee}', ur),
                if (d.fee != null && dist != null) _statDivider(),
                if (dist != null)
                  _stat(trB(ref, 'home.distance'), formatDistance(dist), ur),
                if (dist != null) _statDivider(),
                _stat(
                  trB(ref, 'home.reviews'),
                  d.reviewCount > 0 ? '${d.reviewCount}' : '–',
                  ur,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: open ? FdColors.primary : FdColors.muted,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _openText(d, ref),
                  style: FdType.body(ur,
                      size: 15, w: FontWeight.w700, color: FdColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: FdColors.inkSoft),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  [
                    if (d.clinicName.isNotEmpty) d.clinicName,
                    if (d.address.isNotEmpty) d.address,
                    d.city,
                  ].where((s) => s.isNotEmpty).join(', '),
                  style: FdType.body(ur, size: 14, color: FdColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FdButton(
                  label: trB(ref, 'home.viewProfile'),
                  style: FdButtonStyle.white,
                  isUrdu: ur,
                  onTap: () => _openDoctor(d.id),
                ),
              ),
              if (d.phone.trim().isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FdButton(
                    label: trB(ref, 'home.call'),
                    style: FdButtonStyle.dark,
                    icon: Icons.phone_outlined,
                    isUrdu: ur,
                    onTap: () => callNumber(context, d.phone),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, bool ur) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: FdType.body(ur, size: 13, color: FdColors.muted)),
          const SizedBox(height: 3),
          Text(
            value,
            style: FdType.body(ur,
                size: 17, w: FontWeight.w800, color: FdColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1.2, height: 34, color: FdColors.line);
  }
}
