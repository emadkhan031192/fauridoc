import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/geo.dart';

/// Best-effort user location that never prompts: returns null when location
/// permission is not already granted (the Map tab's locate button is the
/// explicit opt-in that requests it).
final userLocationProvider = FutureProvider<Position?>((ref) async {
  try {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      timeLimit: const Duration(seconds: 8),
    );
  } catch (_) {
    return null;
  }
});

/// "1.5 km" between [pos] and the entity, or null when unknown.
String? distanceText(Position? pos, double? lat, double? lng) {
  if (pos == null || lat == null || lng == null) return null;
  return formatDistance(haversineKm(pos.latitude, pos.longitude, lat, lng));
}
