import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../widgets/rating_stars.dart';
import '../widgets/theme.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';

/// Initial camera position per city.
const Map<String, LatLng> _cityCoords = {
  'Mardan': LatLng(34.20, 72.04),
  'Peshawar': LatLng(34.01, 71.58),
  'Abbottabad': LatLng(34.15, 73.21),
  'Swabi': LatLng(34.12, 72.47),
  'Nowshera': LatLng(34.01, 71.98),
};

LatLng _coordsFor(String city) =>
    _cityCoords[city] ?? const LatLng(34.20, 72.04);

/// Map tab: shows a friendly setup card until a Google Maps API key is
/// configured, otherwise the live map with entity markers.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!mapsConfigured) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map, size: 64, color: FauridocTheme.teal),
                    const SizedBox(height: 16),
                    Text(
                      tr(ref, 'mapsSetupTitle'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr(ref, 'mapsSetupBody'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return const _LiveMap();
  }
}

class _LiveMap extends ConsumerStatefulWidget {
  const _LiveMap();

  @override
  ConsumerState<_LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends ConsumerState<_LiveMap> {
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    // Animate the camera whenever the city scope changes (from this tab's
    // dropdown or anywhere else).
    ref.listen<String>(cityProvider, (previous, next) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(_coordsFor(next), 12),
      );
    });

    final city = ref.watch(cityProvider);
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'navMap'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: StreamBuilder<List<String>>(
              stream: repo.watchCities(),
              builder: (context, snap) {
                final cities = (snap.data ?? [city]).toSet().toList();
                final value =
                    cities.contains(city) ? city : cities.first;
                return DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: InputDecoration(
                    labelText: tr(ref, 'filterCity'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  items: [
                    for (final c in cities)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(cityProvider.notifier).setCity(v);
                    }
                  },
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Doctor>>(
              stream: repo.watchDoctors(city: city),
              builder: (context, dSnap) {
                return StreamBuilder<List<Lab>>(
                  stream: repo.watchLabs(city: city),
                  builder: (context, lSnap) {
                    return StreamBuilder<List<Hospital>>(
                      stream: repo.watchHospitals(city: city),
                      builder: (context, hSnap) {
                        final fallback = _coordsFor(city);
                        final markers = <Marker>{
                          for (final d in dSnap.data ?? <Doctor>[])
                            Marker(
                              markerId: MarkerId('doctor_${d.id}'),
                              position: LatLng(
                                d.lat ?? fallback.latitude,
                                d.lng ?? fallback.longitude,
                              ),
                              icon:
                                  BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueAzure),
                              onTap: () => _showDoctorSheet(d),
                            ),
                          for (final l in lSnap.data ?? <Lab>[])
                            Marker(
                              markerId: MarkerId('lab_${l.id}'),
                              position: LatLng(
                                l.lat ?? fallback.latitude,
                                l.lng ?? fallback.longitude,
                              ),
                              icon:
                                  BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueOrange),
                              onTap: () => _showLabSheet(l),
                            ),
                          for (final h in hSnap.data ?? <Hospital>[])
                            Marker(
                              markerId: MarkerId('hospital_${h.id}'),
                              position: LatLng(
                                h.lat ?? fallback.latitude,
                                h.lng ?? fallback.longitude,
                              ),
                              icon:
                                  BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueRed),
                              onTap: () => _showHospitalSheet(h),
                            ),
                        };
                        return GoogleMap(
                          onMapCreated: (c) => _controller = c,
                          initialCameraPosition: CameraPosition(
                            target: fallback,
                            zoom: 12,
                          ),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          markers: markers,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'locationNeeded'))),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
            LatLng(pos.latitude, pos.longitude), 14),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'error'))),
      );
    }
  }

  // ---------- marker bottom sheets ----------

  void _showDoctorSheet(Doctor d) {
    _showSheet(
      name: d.name,
      typeKey: 'tabDoctors',
      rating: d.rating,
      reviewCount: d.reviewCount,
      info: d.fee != null
          ? fill(tr(ref, 'rs'), {'p': '${d.fee}'})
          : null,
      hasParking: d.hasParking,
      onOpen: () => DoctorDetailScreen(doctorId: d.id),
    );
  }

  void _showLabSheet(Lab l) {
    _showSheet(
      name: l.name,
      typeKey: 'tabLabs',
      rating: l.rating,
      reviewCount: l.reviewCount,
      hasParking: l.hasParking,
      onOpen: () => LabDetailScreen(labId: l.id),
    );
  }

  void _showHospitalSheet(Hospital h) {
    _showSheet(
      name: h.name,
      typeKey: 'tabHospitals',
      rating: h.rating,
      reviewCount: h.reviewCount,
      hasParking: h.hasParking,
      onOpen: () => HospitalDetailScreen(hospitalId: h.id),
    );
  }

  void _showSheet({
    required String name,
    required String typeKey,
    required double rating,
    required int reviewCount,
    String? info,
    bool hasParking = false,
    required Widget Function() onOpen,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (_) => InkWell(
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => onOpen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Pill(label: tr(ref, typeKey)),
                ],
              ),
              const SizedBox(height: 6),
              RatingStars(rating: rating, reviewCount: reviewCount),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (info != null) ...[
                    Text(
                      info,
                      style: const TextStyle(
                        color: FauridocTheme.tealDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (hasParking)
                    Pill(
                      label: tr(ref, 'parking'),
                      icon: Icons.local_parking,
                      color: Colors.green,
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
