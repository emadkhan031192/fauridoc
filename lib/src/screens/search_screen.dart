import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../design/tokens.dart';
import '../l10n/strings.dart';
import '../l10n/strings_b.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../utils/actions.dart';
import '../utils/geo.dart';
import '../utils/open_status.dart';
import '../widgets/theme.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';

/// Search tab (design page 05): title, live search field, Doctors / Lab Tests
/// / Hospitals segmented control, filter chips, and result cards.
/// Body-only — the bottom nav lives in HomeShell.
///
/// Pixel pass: all sizes / radii / colors below are taken literally from
/// design/fauridoc-screens.html (1 CSS px = 1 logical px). Private `_`-prefixed
/// widgets are used wherever the shared theme widgets don't match the spec.
/// The HTML artboard only shows the Doctors tab; lab/hospital cards reuse the
/// same pastel-card language for consistency (no invented tags).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

// ---------------------------------------------------------------------------
// Stream providers (file-private).
// ---------------------------------------------------------------------------

final _searchDoctorsProvider = StreamProvider.autoDispose.family<
    List<Doctor>, ({String city, String? specialty, String query})>(
  (ref, args) => ref.watch(repositoryProvider).watchDoctors(
        city: args.city,
        specialty: args.specialty,
        query: args.query.isEmpty ? null : args.query,
      ),
);

final _searchLabsProvider = StreamProvider.autoDispose
    .family<List<Lab>, ({String city, String query})>(
  (ref, args) => ref.watch(repositoryProvider).watchLabs(
        city: args.city,
        query: args.query.isEmpty ? null : args.query,
      ),
);

final _searchHospitalsProvider = StreamProvider.autoDispose
    .family<List<Hospital>, ({String city, String query})>(
  (ref, args) => ref.watch(repositoryProvider).watchHospitals(
        city: args.city,
        query: args.query.isEmpty ? null : args.query,
      ),
);

final _searchCitiesProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref.watch(repositoryProvider).watchCities(),
);

final _searchSpecialtiesProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref.watch(repositoryProvider).watchSpecialties(),
);

class _SearchScreenState extends ConsumerState<SearchScreen> {
  int _tab = 0; // 0 doctors, 1 labs, 2 hospitals
  String _query = '';
  String? _specialty; // null = all
  bool _within5km = false;
  Position? _pos;

  Future<void> _ensurePosition() async {
    if (_pos != null) return;
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(trB(ref, 'search.locationNeeded'))),
          );
        }
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted) setState(() => _pos = p);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trB(ref, 'search.locationNeeded'))),
        );
      }
    }
  }

  double? _distanceKm(double? lat, double? lng) {
    final p = _pos;
    if (p == null || lat == null || lng == null) return null;
    return haversineKm(p.latitude, p.longitude, lat, lng);
  }

  bool _passes5km(double? lat, double? lng) {
    if (!_within5km) return true;
    final d = _distanceKm(lat, lng);
    // When the distance can't be measured (no coordinates or no position),
    // keep the entity visible — don't hide what we can't measure.
    if (d == null) return true;
    return d <= 5;
  }

  String _fmtTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final suffix = h >= 12 ? 'PM' : 'AM';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return m == '00' ? '$h12 $suffix' : '$h12:$m $suffix';
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

  Future<void> _showCitySheet() async {
    final cities = await ref
        .read(_searchCitiesProvider.future)
        .catchError((_) => <String>[]);
    if (!mounted) return;
    final current = ref.read(cityProvider);
    final ur = fdIsUrdu(ref.read(localeProvider));
    await showModalBottomSheet(
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
              child: Text(trB(ref, 'home.chooseCity'),
                  style: FdType.title(ur, size: 20)),
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

  Future<void> _showSpecialtySheet(List<String> specs) async {
    final locale = ref.read(localeProvider);
    final ur = fdIsUrdu(locale);
    await showModalBottomSheet(
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
              child: Text(trB(ref, 'search.allSpecialties'),
                  style: FdType.title(ur, size: 20)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: Text(trB(ref, 'home.all'),
                        style: FdType.body(ur,
                            size: 16,
                            w: FontWeight.w600,
                            color: FdColors.ink)),
                    trailing: _specialty == null
                        ? const Icon(Icons.check, color: FdColors.primary)
                        : null,
                    onTap: () {
                      setState(() => _specialty = null);
                      Navigator.of(ctx).pop();
                    },
                  ),
                  for (final s in specs)
                    ListTile(
                      title: Text(specialtyLabel(locale, s),
                          style: FdType.body(ur,
                              size: 16,
                              w: FontWeight.w600,
                              color: FdColors.ink)),
                      trailing: _specialty == s
                          ? const Icon(Icons.check, color: FdColors.primary)
                          : null,
                      onTap: () {
                        setState(() => _specialty = s);
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

  void _openLab(String id) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => LabDetailScreen(labId: id)));
  }

  void _openHospital(String id) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HospitalDetailScreen(hospitalId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final city = ref.watch(cityProvider);

    return Scaffold(
      backgroundColor: FdColors.bg,
      // Spec artboard is edge-to-edge: header padding already includes the
      // 52/48px status-bar area, so the top safe-area inset is disabled.
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed header: padding 52 20 0 (EN) / 48 20 0 (UR).
            Padding(
              padding: EdgeInsets.fromLTRB(20, ur ? 48 : 52, 20, 0),
              child: Text(
                trB(ref, 'search.title'),
                style: TextStyle(
                  fontFamily: FdType.family(ur),
                  // EN: 28/800 ls -0.02em. UR mirrors HomeUrdu scale.
                  fontSize: ur ? (28) * 0.9 : (28),
                  fontWeight:
                      ur ? FontWeight.w700 : FontWeight.w800,
                  color: FdSpec.ink,
                  height: ur ? 1.75 : null,
                  letterSpacing: ur ? 0 : -0.56,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _searchBox(ur),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _segmented(ur),
            ),
            _filterChips(city, locale, ur),
            Expanded(child: _results(city, locale, ur)),
          ],
        ),
      ),
    );
  }

  // -- search box --------------------------------------------------------------

  /// Spec: height 50, radius 14, 1px border, 20px icon, input 15/500 ink,
  /// hint inherits muted.
  Widget _searchBox(bool ur) {
    return Container(
      height: 50,
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
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              style: TextStyle(
                fontFamily: FdType.family(ur),
                fontSize: ur ? (15) * 0.9 : (15),
                fontWeight: FontWeight.w500,
                color: FdSpec.ink,
              ),
              decoration: InputDecoration(
                hintText: trB(ref, 'search.hint'),
                hintStyle: TextStyle(
                  fontFamily: FdType.family(ur),
                  fontSize: ur ? (15) * 0.9 : (15),
                  fontWeight: FontWeight.w500,
                  color: FdSpec.muted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- segmented control -------------------------------------------------------

  /// Spec: margin-top 12, padding 4, radius 14, bg #E8EEEC, gap 4;
  /// segments h40 radius 11, 14px — selected: white bg, primary, 800,
  /// 0 1px 3px shadow; unselected: transparent, muted, 600.
  Widget _segmented(bool ur) {
    final tabs = [
      trB(ref, 'search.doctors'),
      trB(ref, 'search.labTests'),
      trB(ref, 'search.hospitals'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEEC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _FdPress(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        _tab == i ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: _tab == i
                        ? const [
                            BoxShadow(
                              // rgba(15, 42, 46, 0.14) 0 1px 3px.
                              color: Color(0x240F2A2E),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    tabs[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: FdType.family(ur),
                      fontSize: ur ? (14) * 0.9 : (14),
                      fontWeight: _tab == i
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: _tab == i ? FdSpec.primary : FdSpec.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -- filter chips ------------------------------------------------------------

  /// Spec: full-bleed row (margin-top 12, inner scroll padding 0 20,
  /// gap 8); chips h38, padding 0 12, radius 19, 1px border, 13/600 ink,
  /// gap 6. Full-bleed works because the parent Column carries no
  /// horizontal page padding (each sibling pads itself).
  Widget _filterChips(String city, String locale, bool ur) {
    final specsAsync = ref.watch(_searchSpecialtiesProvider);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _filterChip(
              label: city,
              chevron: true,
              ur: ur,
              onTap: _showCitySheet,
            ),
            if (_tab == 0) ...[
              const SizedBox(width: 8),
              specsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (specs) => _filterChip(
                  label: _specialty == null
                      ? trB(ref, 'search.allSpecialties')
                      : specialtyLabel(locale, _specialty!),
                  chevron: true,
                  ur: ur,
                  onTap: () => _showSpecialtySheet(specs),
                ),
              ),
            ],
            const SizedBox(width: 8),
            _filterChip(
              label: trB(ref, 'search.within5km'),
              icon: Icons.location_on_outlined,
              selected: _within5km,
              ur: ur,
              // Only turn the filter on when a position was actually
              // obtained; otherwise _ensurePosition already showed the
              // locationNeeded snackbar and the filter stays off.
              onTap: () async {
                if (_within5km) {
                  setState(() => _within5km = false);
                } else {
                  await _ensurePosition();
                  if (mounted && _pos != null) {
                    setState(() => _within5km = true);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool ur,
    required VoidCallback onTap,
    IconData? icon,
    bool chevron = false,
    bool selected = false,
  }) {
    final fg = selected ? Colors.white : FdSpec.ink;
    return _FdPress(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? FdSpec.primary : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
              color: selected ? FdSpec.primary : FdSpec.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: FdType.family(ur),
                fontSize: ur ? (13) * 0.9 : (13),
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            if (chevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.expand_more, size: 13, color: fg),
            ],
          ],
        ),
      ),
    );
  }

  // -- results ------------------------------------------------------------------

  Widget _results(String city, String locale, bool ur) {
    if (_tab == 0) {
      final async = ref.watch(_searchDoctorsProvider(
          (city: city, specialty: _specialty, query: _query)));
      return async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: FdColors.primary)),
        error: (_, _) => const SizedBox.shrink(),
        data: (list) {
          final doctors =
              list.where((d) => _passes5km(d.lat, d.lng)).toList();
          return _listShell(
            countText: fill(trB(ref, 'search.doctorsIn'),
                {'count': '${doctors.length}', 'city': city}),
            ur: ur,
            empty: doctors.isEmpty,
            children: [
              for (var i = 0; i < doctors.length; i++)
                _doctorCard(doctors[i], i, locale, ur),
            ],
          );
        },
      );
    }
    if (_tab == 1) {
      final async =
          ref.watch(_searchLabsProvider((city: city, query: _query)));
      return async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: FdColors.primary)),
        error: (_, _) => const SizedBox.shrink(),
        data: (list) {
          final labs = list.where((l) => _passes5km(l.lat, l.lng)).toList();
          return _listShell(
            countText: fill(trB(ref, 'search.labsIn'),
                {'count': '${labs.length}', 'city': city}),
            ur: ur,
            empty: labs.isEmpty,
            children: [
              for (var i = 0; i < labs.length; i++)
                _labCard(labs[i], i, ur),
            ],
          );
        },
      );
    }
    final async =
        ref.watch(_searchHospitalsProvider((city: city, query: _query)));
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: FdColors.primary)),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        final hospitals =
            list.where((h) => _passes5km(h.lat, h.lng)).toList();
        return _listShell(
          countText: fill(trB(ref, 'search.hospitalsIn'),
              {'count': '${hospitals.length}', 'city': city}),
          ur: ur,
          empty: hospitals.isEmpty,
          children: [
            for (var i = 0; i < hospitals.length; i++)
              _hospitalCard(hospitals[i], i, ur),
          ],
        );
      },
    );
  }

  /// Spec: scroll padding 14 20 16; count 13/600 muted; cards gap 10,
  /// margin-top 10.
  Widget _listShell({
    required String countText,
    required bool ur,
    required bool empty,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            countText,
            style: TextStyle(
              fontFamily: FdType.family(ur),
              fontSize: ur ? (13) * 0.9 : (13),
              fontWeight: FontWeight.w600,
              color: FdSpec.muted,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: empty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      trB(ref, 'search.noResults'),
                      style: FdType.body(ur, color: FdColors.muted),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        children[i],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // -- cards ---------------------------------------------------------------------

  /// Same pastel-card language as the Home list cards (spec page 05):
  /// padding 12, radius 22; 56x56 avatar r16; name 16/800 + 16px tick;
  /// specialty 13/600; rating pill; white stat strip; 13/700 status;
  /// 12.5/600 address; h46 buttons 14/700.
  Widget _doctorCard(Doctor d, int index, String locale, bool ur) {
    final dist = _distanceKm(d.lat, d.lng);
    final open = _isOpen(d);
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
                d.displayName(ur),
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
                            d.displayName(ur),
                            maxLines: 2,
                            softWrap: true,
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
          Padding(
            padding: EdgeInsets.only(top: ur ? 6 : 10),
            child: Row(
              children: [
                _statusDot(
                    color: open ? FdSpec.openGreen : FdSpec.closedGrey),
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
          Padding(
            padding: EdgeInsets.only(top: ur ? 8 : 10),
            child: Row(
              children: [
                Expanded(
                  child: _pillButton(
                    label: trB(ref, 'home.viewProfile'),
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

  /// Lab card in the same pastel-card language (spec artboard shows only
  /// doctors; data/logic unchanged).
  Widget _labCard(Lab l, int index, bool ur) {
    final dist = _distanceKm(l.lat, l.lng);
    final minPrice = l.tests.isEmpty
        ? null
        : l.tests.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    return _FdPress(
      onTap: () => _openLab(l.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FdColors.tintForIndex(index),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FdColors.lavender,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.science_outlined,
                  color: FdColors.lavenderInk, size: 28),
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
                          l.displayName(ur),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: FdType.family(ur),
                            fontSize: ur ? (16) * 0.9 : (16),
                            fontWeight:
                                ur ? FontWeight.w700 : FontWeight.w800,
                            color: FdSpec.ink,
                            height: ur ? 1.8 : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      if (l.verified) const FdVerifiedBadge(size: 16),
                    ],
                  ),
                  Text(
                    [
                      l.city,
                      if (dist != null) formatDistance(dist),
                    ].join(' · '),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (l.reviewCount > 0)
                        _ratingPill(l.rating, ur)
                      else
                        FdNewPill(
                            label: trB(ref, 'home.new'), isUrdu: ur),
                      const Spacer(),
                      if (minPrice != null)
                        Flexible(
                          child: Text(
                            fill(trB(ref, 'search.testsFrom'), {
                              'count': '${l.tests.length}',
                              'price': '$minPrice'
                            }),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: FdType.family(ur),
                              fontSize: ur ? (13) * 0.9 : (13),
                              fontWeight: FontWeight.w700,
                              color: FdSpec.primary,
                              height: ur ? 1.8 : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hospital card in the same pastel-card language (data/logic unchanged).
  Widget _hospitalCard(Hospital h, int index, bool ur) {
    final dist = _distanceKm(h.lat, h.lng);
    return _FdPress(
      onTap: () => _openHospital(h.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FdColors.tintForIndex(index),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FdColors.redSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add,
                  color: FdColors.redInk, size: 28),
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
                          h.displayName(ur),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: FdType.family(ur),
                            fontSize: ur ? (16) * 0.9 : (16),
                            fontWeight:
                                ur ? FontWeight.w700 : FontWeight.w800,
                            color: FdSpec.ink,
                            height: ur ? 1.8 : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      if (h.verified) const FdVerifiedBadge(size: 16),
                      if (h.type == 'private') ...[
                        const SizedBox(width: 6),
                        _typePill(
                          trB(ref, 'search.private'),
                          FdColors.lavenderInk,
                          FdColors.lavender,
                          ur,
                        ),
                      ] else if (h.type == 'government') ...[
                        const SizedBox(width: 6),
                        _typePill(
                          trB(ref, 'search.govt'),
                          FdColors.primary,
                          FdColors.mint,
                          ur,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    [
                      h.city,
                      if (dist != null) formatDistance(dist),
                    ].join(' · '),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (h.reviewCount > 0)
                        _ratingPill(h.rating, ur)
                      else
                        FdNewPill(
                            label: trB(ref, 'home.new'), isUrdu: ur),
                      if (h.emergency247) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: FdColors.redSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              trB(ref, 'search.emergency247'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: FdType.family(ur),
                                fontSize: ur ? (12.5) * 0.9 : (12.5),
                                fontWeight: FontWeight.w700,
                                color: FdColors.redInk,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (h.departments.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      h.departments.take(3).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: FdType.family(ur),
                        fontSize: ur ? (12.5) * 0.9 : (12.5),
                        fontWeight: FontWeight.w600,
                        color: FdSpec.muted,
                        height: ur ? 1.7 : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
          fontSize: ur ? (fontSize) * 0.9 : (fontSize),
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

  /// Hospital type pill: 10/700, pill radius, colored per type
  /// (private = lavender ink on lavender; government = primary on mint).
  Widget _typePill(String label, Color fg, Color bg, bool ur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: FdType.family(ur),
          fontSize: ur ? (10) * 0.9 : (10),
          fontWeight: FontWeight.w700,
          color: fg,
          height: ur ? 1.5 : null,
        ),
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
                  fontSize: ur ? (fontSize) * 0.9 : (fontSize),
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
