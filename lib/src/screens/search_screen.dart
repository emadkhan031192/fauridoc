import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
        desiredAccuracy: LocationAccuracy.low,
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
    if (d == null) return false;
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  FdDim.page, 14, FdDim.page, 0),
              child: Text(trB(ref, 'search.title'),
                  style: FdType.display(ur, size: 34)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: FdDim.page),
              child: FdSearchField(
                hint: trB(ref, 'search.hint'),
                isUrdu: ur,
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: FdDim.page),
              child: _segmented(ur),
            ),
            const SizedBox(height: 14),
            _filterChips(city, locale, ur),
            const SizedBox(height: 6),
            Expanded(child: _results(city, locale, ur)),
          ],
        ),
      ),
    );
  }

  // -- segmented control -------------------------------------------------------

  Widget _segmented(bool ur) {
    final tabs = [
      trB(ref, 'search.doctors'),
      trB(ref, 'search.labTests'),
      trB(ref, 'search.hospitals'),
    ];
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: FdColors.mint,
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == i ? Colors.white : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(FdDim.pillRadius),
                    boxShadow: _tab == i
                        ? [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    tabs[i],
                    style: FdType.body(
                      ur,
                      size: 15,
                      w: FontWeight.w700,
                      color: _tab == i ? FdColors.primary : FdColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -- filter chips ------------------------------------------------------------

  Widget _filterChips(String city, String locale, bool ur) {
    final specsAsync = ref.watch(_searchSpecialtiesProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: FdDim.page),
      child: Row(
        children: [
          _dropdownChip(
            label: city,
            onTap: _showCitySheet,
            ur: ur,
          ),
          if (_tab == 0) ...[
            const SizedBox(width: 10),
            specsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (specs) => _dropdownChip(
                label: _specialty == null
                    ? trB(ref, 'search.allSpecialties')
                    : specialtyLabel(locale, _specialty!),
                onTap: () => _showSpecialtySheet(specs),
                ur: ur,
              ),
            ),
          ],
          const SizedBox(width: 10),
          _toggleChip(
            label: trB(ref, 'search.within5km'),
            icon: Icons.location_on_outlined,
            selected: _within5km,
            ur: ur,
            onTap: () async {
              if (!_within5km) await _ensurePosition();
              setState(() => _within5km = !_within5km);
            },
          ),
          const SizedBox(width: FdDim.page),
        ],
      ),
    );
  }

  Widget _dropdownChip({
    required String label,
    required VoidCallback onTap,
    required bool ur,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(FdDim.pillRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
        onTap: onTap,
        child: Container(
          height: FdDim.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FdDim.pillRadius),
            border: Border.all(color: FdColors.line, width: 1.4),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: FdType.body(ur,
                    size: 15, w: FontWeight.w600, color: FdColors.ink),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down,
                  color: FdColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required IconData icon,
    required bool selected,
    required bool ur,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? FdColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(FdDim.pillRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
        onTap: onTap,
        child: Container(
          height: FdDim.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FdDim.pillRadius),
            border: selected
                ? null
                : Border.all(color: FdColors.line, width: 1.4),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? Colors.white : FdColors.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: FdType.body(ur,
                    size: 15,
                    w: FontWeight.w600,
                    color: selected ? Colors.white : FdColors.ink),
              ),
            ],
          ),
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
        error: (_, __) => const SizedBox.shrink(),
        data: (list) {
          final doctors =
              list.where((d) => _passes5km(d.lat, d.lng)).toList();
          return _listShell(
            countText: fill(trB(ref, 'search.doctorsIn'),
                {'count': '${doctors.length}', 'city': city}),
            ur: ur,
            empty: doctors.isEmpty,
            children: [
              for (var i = 0; i < doctors.length; i++) ...[
                _doctorCard(doctors[i], i, locale, ur),
                const SizedBox(height: 14),
              ],
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
        error: (_, __) => const SizedBox.shrink(),
        data: (list) {
          final labs = list.where((l) => _passes5km(l.lat, l.lng)).toList();
          return _listShell(
            countText: fill(trB(ref, 'search.labsIn'),
                {'count': '${labs.length}', 'city': city}),
            ur: ur,
            empty: labs.isEmpty,
            children: [
              for (var i = 0; i < labs.length; i++) ...[
                _labCard(labs[i], i, ur),
                const SizedBox(height: 14),
              ],
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
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final hospitals =
            list.where((h) => _passes5km(h.lat, h.lng)).toList();
        return _listShell(
          countText: fill(trB(ref, 'search.hospitalsIn'),
              {'count': '${hospitals.length}', 'city': city}),
          ur: ur,
          empty: hospitals.isEmpty,
          children: [
            for (var i = 0; i < hospitals.length; i++) ...[
              _hospitalCard(hospitals[i], i, ur),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _listShell({
    required String countText,
    required bool ur,
    required bool empty,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          FdDim.page, 8, FdDim.page, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(countText,
              style: FdType.body(ur, size: 15, color: FdColors.inkSoft)),
          const SizedBox(height: 12),
          if (empty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                trB(ref, 'search.noResults'),
                style: FdType.body(ur, color: FdColors.muted),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  // -- cards ---------------------------------------------------------------------

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
                  icon: Icons.visibility_outlined,
                  isUrdu: ur,
                  onTap: () => _openDoctor(d.id),
                ),
              ),
              if (d.phone.trim().isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FdButton(
                    label: trB(ref, 'search.callNow'),
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

  Widget _labCard(Lab l, int index, bool ur) {
    final dist = _distanceKm(l.lat, l.lng);
    final minPrice = l.tests.isEmpty
        ? null
        : l.tests.map((t) => t.price).reduce((a, b) => a < b ? a : b);
    return Material(
      color: FdColors.tintForIndex(index),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _openLab(l.id),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: FdColors.lavender,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.science_outlined,
                    color: FdColors.lavenderInk, size: 36),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(l.name,
                              style: FdType.title(ur, size: 18)),
                        ),
                        if (l.verified) ...[
                          const SizedBox(width: 6),
                          const FdVerifiedBadge(size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        l.city,
                        if (dist != null) formatDistance(dist),
                      ].join(' · '),
                      style:
                          FdType.body(ur, size: 14, color: FdColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (l.reviewCount > 0)
                          FdRatingPill(rating: l.rating, isUrdu: ur)
                        else
                          FdNewPill(
                              label: trB(ref, 'home.new'), isUrdu: ur),
                        const Spacer(),
                        if (minPrice != null)
                          Text(
                            fill(trB(ref, 'search.testsFrom'), {
                              'count': '${l.tests.length}',
                              'price': '$minPrice'
                            }),
                            style: FdType.body(ur,
                                size: 14,
                                w: FontWeight.w700,
                                color: FdColors.primary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hospitalCard(Hospital h, int index, bool ur) {
    final dist = _distanceKm(h.lat, h.lng);
    return Material(
      color: FdColors.tintForIndex(index),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _openHospital(h.id),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: FdColors.redSoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.add,
                    color: FdColors.redInk, size: 38),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(h.name,
                              style: FdType.title(ur, size: 18)),
                        ),
                        if (h.verified) ...[
                          const SizedBox(width: 6),
                          const FdVerifiedBadge(size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        h.city,
                        if (dist != null) formatDistance(dist),
                      ].join(' · '),
                      style:
                          FdType.body(ur, size: 14, color: FdColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (h.reviewCount > 0)
                          FdRatingPill(rating: h.rating, isUrdu: ur)
                        else
                          FdNewPill(
                              label: trB(ref, 'home.new'), isUrdu: ur),
                        if (h.emergency247) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: FdColors.redSoft,
                              borderRadius:
                                  BorderRadius.circular(FdDim.pillRadius),
                            ),
                            child: Text(
                              trB(ref, 'search.emergency247'),
                              style: FdType.body(ur,
                                  size: 13,
                                  w: FontWeight.w700,
                                  color: FdColors.redInk),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (h.departments.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        h.departments.take(3).join(' · '),
                        style: FdType.body(ur,
                            size: 13, color: FdColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
