import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/strings.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../providers/providers.dart';
import '../utils/actions.dart';
import '../utils/geo.dart';
import '../widgets/entity_cards.dart';
import '../widgets/theme.dart';
import 'doctor_detail_screen.dart';

/// Home tab: emergency shortcut, specialty chips, and the doctors list.
/// Browsing is open — no login wall.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Null = all specialties.
  String? _selectedSpecialty;

  Future<void> _onEmergencyTap() async {
    final locale = ref.read(localeProvider);
    final city = ref.read(cityProvider);
    final hospitals =
        await ref.read(repositoryProvider).watchHospitals(city: city).first;
    final emergency = hospitals.where((h) => h.emergency247).toList();
    if (!mounted) return;

    if (emergency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fill(translate(locale, 'noEmergencyHospital'), {'city': city}),
          ),
        ),
      );
      return;
    }

    Position? pos;
    try {
      await Geolocator.requestPermission();
      pos = await Geolocator.getCurrentPosition();
    } catch (_) {
      pos = null;
    }

    Hospital chosen = emergency.first;
    if (pos != null) {
      final withCoords = emergency
          .where((h) => h.lat != null && h.lng != null)
          .toList();
      if (withCoords.isNotEmpty) {
        final p = pos;
        withCoords.sort(
          (a, b) => haversineKm(p.latitude, p.longitude, a.lat!, a.lng!)
              .compareTo(haversineKm(p.latitude, p.longitude, b.lat!, b.lng!)),
        );
        chosen = withCoords.first;
      }
    }
    if (!mounted) return;

    final h = chosen;
    final contactLabel = translate(locale, 'emergencyContact');
    final callLabel = translate(locale, 'call');
    final directionsLabel = translate(locale, 'directions');

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                h.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('$contactLabel: ${h.emergencyPhone}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        callNumber(context, h.emergencyPhone);
                      },
                      icon: const Icon(Icons.call),
                      label: Text(callLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        openDirections(context, h.lat, h.lng, h.name);
                      },
                      icon: const Icon(Icons.directions),
                      label: Text(directionsLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final city = ref.watch(cityProvider);
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'appName')),
        actions: [
          StreamBuilder<List<String>>(
            stream: repo.watchCities(),
            builder: (context, snapshot) {
              final cities = snapshot.data ?? const <String>[];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: cities.contains(city) ? city : null,
                    hint: Text(
                      translate(locale, 'city'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    dropdownColor: FauridocTheme.tealDark,
                    style: const TextStyle(color: Colors.white),
                    icon: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                    ),
                    items: cities
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(cityProvider.notifier).setCity(v);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emergency shortcut.
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: _onEmergencyTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FauridocTheme.emergencyRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emergency,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(ref, 'nearestEmergency'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(ref, 'nearestEmergencySub'),
                            style: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Specialty filter chips.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              translate(locale, 'specialties'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: StreamBuilder<List<String>>(
              stream: repo.watchSpecialties(),
              builder: (context, snapshot) {
                final specs = snapshot.data ?? const <String>[];
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: specs.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final spec = i == 0 ? null : specs[i - 1];
                    final selected = _selectedSpecialty == spec;
                    return ChoiceChip(
                      label: Text(
                        spec == null
                            ? translate(locale, 'all')
                            : specialtyLabel(locale, spec),
                      ),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedSpecialty = spec),
                    );
                  },
                );
              },
            ),
          ),
          // Doctors list.
          Expanded(
            child: StreamBuilder<List<Doctor>>(
              stream: repo.watchDoctors(
                city: city,
                specialty: _selectedSpecialty,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                final doctors = snapshot.data ?? const <Doctor>[];
                if (doctors.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        fill(translate(locale, 'noDoctors'), {'city': city}),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: doctors.length,
                  itemBuilder: (context, i) {
                    final doctor = doctors[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DoctorCard(
                        doctor: doctor,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DoctorDetailScreen(
                              doctorId: doctor.id,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
