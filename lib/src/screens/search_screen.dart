import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../utils/geo.dart';
import '../widgets/entity_cards.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';

/// Search tab: segmented Doctors / Labs / Hospitals, text query, city,
/// specialty (doctors), sort, lab test-category chips, and a 5 km filter.
/// Browsing is open — no login wall.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  int _tab = 0; // 0 = doctors, 1 = labs, 2 = hospitals
  final _queryController = TextEditingController();
  String _query = '';
  String? _cityFilter; // null = all cities
  String? _specialtyFilter; // doctors tab only, null = all
  EntitySort _sort = EntitySort.rating;
  String? _selectedCategory; // labs tab only, null = all
  bool _within5km = false;
  Position? _position;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// True when the entity passes the optional 5 km filter.
  bool _passesDistance(double? lat, double? lng) {
    final p = _position;
    if (!_within5km || p == null) return true;
    if (lat == null || lng == null) return false;
    return haversineKm(p.latitude, p.longitude, lat, lng) <= 5;
  }

  double? _distanceKm(double? lat, double? lng) {
    final p = _position;
    if (p == null || lat == null || lng == null) return null;
    return haversineKm(p.latitude, p.longitude, lat, lng);
  }

  Future<void> _onWithin5kmChanged(bool value) async {
    if (!value) {
      setState(() {
        _within5km = false;
        _position = null;
      });
      return;
    }
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translate(ref.read(localeProvider), 'locationNeeded'),
          ),
        ),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _within5km = true;
        _position = pos;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translate(ref.read(localeProvider), 'locationNeeded'),
          ),
        ),
      );
    }
  }

  int _compare(
    double ratingA,
    int reviewsA,
    DateTime createdA,
    double ratingB,
    int reviewsB,
    DateTime createdB,
  ) {
    switch (_sort) {
      case EntitySort.rating:
        return ratingB.compareTo(ratingA);
      case EntitySort.mostReviewed:
        return reviewsB.compareTo(reviewsA);
      case EntitySort.newest:
        return createdB.compareTo(createdA);
    }
  }

  String _searchHint(String locale) {
    switch (_tab) {
      case 1:
        return translate(locale, 'searchHintLabs');
      case 2:
        return translate(locale, 'searchHintHospitals');
      default:
        return translate(locale, 'searchHintDoctors');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final repo = ref.watch(repositoryProvider);
    final q = _query.trim();
    final queryParam = q.isEmpty ? null : q;

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'appName'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(translate(locale, 'tabDoctors')),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(translate(locale, 'tabLabs')),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(translate(locale, 'tabHospitals')),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _queryController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: _searchHint(locale),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          // Filter row.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                StreamBuilder<List<String>>(
                  stream: repo.watchCities(),
                  builder: (context, snapshot) {
                    final cities = snapshot.data ?? const <String>[];
                    return DropdownButton<String?>(
                      value: _cityFilter,
                      hint: Text(translate(locale, 'filterCity')),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(translate(locale, 'allCities')),
                        ),
                        ...cities.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c,
                            child: Text(c),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _cityFilter = v),
                    );
                  },
                ),
                if (_tab == 0) ...[
                  const SizedBox(width: 12),
                  StreamBuilder<List<String>>(
                    stream: repo.watchSpecialties(),
                    builder: (context, snapshot) {
                      final specs = snapshot.data ?? const <String>[];
                      return DropdownButton<String?>(
                        value: _specialtyFilter,
                        hint: Text(translate(locale, 'filterSpecialty')),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(translate(locale, 'all')),
                          ),
                          ...specs.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s,
                              child: Text(specialtyLabel(locale, s)),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _specialtyFilter = v),
                      );
                    },
                  ),
                ],
                const SizedBox(width: 12),
                DropdownButton<EntitySort>(
                  value: _sort,
                  items: [
                    DropdownMenuItem(
                      value: EntitySort.rating,
                      child: Text(translate(locale, 'sortRating')),
                    ),
                    DropdownMenuItem(
                      value: EntitySort.mostReviewed,
                      child: Text(translate(locale, 'sortReviewed')),
                    ),
                    DropdownMenuItem(
                      value: EntitySort.newest,
                      child: Text(translate(locale, 'sortNewest')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _sort = v);
                  },
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text(translate(locale, 'within5km')),
                  selected: _within5km,
                  onSelected: _onWithin5kmChanged,
                ),
              ],
            ),
          ),
          // Lab test-category chips.
          if (_tab == 1)
            SizedBox(
              height: 48,
              child: StreamBuilder<List<String>>(
                stream: repo.watchTestCategories(),
                builder: (context, snapshot) {
                  final cats = snapshot.data ?? const <String>[];
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: cats.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final cat = i == 0 ? null : cats[i - 1];
                      return ChoiceChip(
                        label: Text(
                          cat ?? translate(locale, 'all'),
                        ),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      );
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 4),
          // Results.
          Expanded(
            child: _tab == 0
                ? _buildDoctors(repo, queryParam, locale)
                : _tab == 1
                    ? _buildLabs(repo, queryParam, locale)
                    : _buildHospitals(repo, queryParam, locale),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctors(
    FauridocRepository repo,
    String? query,
    String locale,
  ) {
    return StreamBuilder<List<Doctor>>(
      stream: repo.watchDoctors(
        city: _cityFilter,
        specialty: _specialtyFilter,
        query: query,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final doctors = (snapshot.data ?? const <Doctor>[])
            .where((d) => _passesDistance(d.lat, d.lng))
            .toList()
          ..sort(
            (a, b) => _compare(
              a.rating,
              a.reviewCount,
              a.createdAt,
              b.rating,
              b.reviewCount,
              b.createdAt,
            ),
          );
        if (doctors.isEmpty) return _empty(locale);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          itemCount: doctors.length,
          itemBuilder: (context, i) {
            final doctor = doctors[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DoctorCard(
                doctor: doctor,
                showDistance: _within5km,
                distanceKm: _distanceKm(doctor.lat, doctor.lng),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        DoctorDetailScreen(doctorId: doctor.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabs(
    FauridocRepository repo,
    String? query,
    String locale,
  ) {
    return StreamBuilder<List<Lab>>(
      stream: repo.watchLabs(
        city: _cityFilter,
        query: query,
        testQuery: query,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final labs = (snapshot.data ?? const <Lab>[])
            .where((l) {
              if (_selectedCategory != null &&
                  !l.tests.any(
                      (t) => t.category == _selectedCategory)) {
                return false;
              }
              return _passesDistance(l.lat, l.lng);
            })
            .toList()
          ..sort(
            (a, b) => _compare(
              a.rating,
              a.reviewCount,
              a.createdAt,
              b.rating,
              b.reviewCount,
              b.createdAt,
            ),
          );
        if (labs.isEmpty) return _empty(locale);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          itemCount: labs.length,
          itemBuilder: (context, i) {
            final lab = labs[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LabCard(
                lab: lab,
                testQuery: _query,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LabDetailScreen(labId: lab.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHospitals(
    FauridocRepository repo,
    String? query,
    String locale,
  ) {
    return StreamBuilder<List<Hospital>>(
      stream: repo.watchHospitals(
        city: _cityFilter,
        query: query,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final hospitals = (snapshot.data ?? const <Hospital>[])
            .where((h) => _passesDistance(h.lat, h.lng))
            .toList()
          ..sort(
            (a, b) => _compare(
              a.rating,
              a.reviewCount,
              a.createdAt,
              b.rating,
              b.reviewCount,
              b.createdAt,
            ),
          );
        if (hospitals.isEmpty) return _empty(locale);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          itemCount: hospitals.length,
          itemBuilder: (context, i) {
            final hospital = hospitals[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HospitalCard(
                hospital: hospital,
                distanceKm:
                    _within5km ? _distanceKm(hospital.lat, hospital.lng) : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        HospitalDetailScreen(hospitalId: hospital.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _empty(String locale) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          translate(locale, 'noResults'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }
}
