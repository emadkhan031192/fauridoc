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
import '../providers/user_location.dart';
import '../widgets/theme.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';
import 'search_screen.dart';

/// Initial camera position per city.
const Map<String, LatLng> _cityCoords = {
  'Mardan': LatLng(34.20, 72.04),
  'Peshawar': LatLng(34.01, 71.58),
  'Abbottabad': LatLng(34.15, 73.21),
  'Swabi': LatLng(34.12, 72.47),
  'Nowshera': LatLng(34.01, 71.98),
  'Charsadda': LatLng(34.15, 71.73),
  'Kohat': LatLng(33.58, 71.44),
  'Bannu': LatLng(32.99, 70.60),
  'Mingora': LatLng(34.77, 72.36),
  'Dera Ismail Khan': LatLng(31.83, 70.90),
};

LatLng _coordsFor(String city) =>
    _cityCoords[city] ?? const LatLng(34.20, 72.04);

enum _PinType { all, doctors, labs, hospitals }

/// Map tab (body-only; HomeShell owns the bottom nav). Design page-10:
/// floating city search bar, type filter chips, live GoogleMap when a key is
/// configured, otherwise a stylized placeholder, locate button, and a bottom
/// info card for the selected pin.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  _PinType _type = _PinType.all;
  GoogleMapController? _controller;

  // Selected entity for the bottom card.
  String? _selKind; // 'doctor' | 'lab' | 'hospital'
  String? _selId;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final ur = fdIsUrdu(locale);
    final city = ref.watch(cityProvider);

    ref.listen<String>(cityProvider, (prev, next) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(_coordsFor(next), 12),
      );
      setState(() {
        _selKind = null;
        _selId = null;
      });
    });

    return StreamBuilder<List<Doctor>>(
      stream: ref.watch(repositoryProvider).watchDoctors(city: city),
      builder: (context, dSnap) {
        return StreamBuilder<List<Lab>>(
          stream: ref.watch(repositoryProvider).watchLabs(city: city),
          builder: (context, lSnap) {
            return StreamBuilder<List<Hospital>>(
              stream: ref.watch(repositoryProvider).watchHospitals(city: city),
              builder: (context, hSnap) {
                final doctors = _filtered(
                    dSnap.data ?? <Doctor>[], _PinType.doctors);
                final labs =
                    _filtered(lSnap.data ?? <Lab>[], _PinType.labs);
                final hospitals = _filtered(
                    hSnap.data ?? <Hospital>[], _PinType.hospitals);
                _ensureSelection(doctors, labs, hospitals);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: mapsConfigured
                          ? _liveMap(
                              city, doctors, labs, hospitals)
                          : _MapPlaceholder(
                              doctors: doctors,
                              labs: labs,
                              hospitals: hospitals,
                              onPinTap: (kind) =>
                                  _selectFirstOf(kind, doctors, labs, hospitals),
                            ),
                    ),
                    _topBar(context, ref, ur, city),
                    _typeChips(ref, ur),
                    _locateButton(context, ref),
                    _bottomCard(context, ref, ur, doctors, labs, hospitals),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<T> _filtered<T>(List<T> items, _PinType kind) {
    if (_type == _PinType.all || _type == kind) return items;
    return [];
  }

  void _ensureSelection(
      List<Doctor> doctors, List<Lab> labs, List<Hospital> hospitals) {
    bool alive = false;
    if (_selKind == 'doctor' && _selId != null) {
      alive = doctors.any((d) => d.id == _selId);
    } else if (_selKind == 'lab' && _selId != null) {
      alive = labs.any((l) => l.id == _selId);
    } else if (_selKind == 'hospital' && _selId != null) {
      alive = hospitals.any((h) => h.id == _selId);
    }
    if (!alive) {
      // Design default: a hospital card.
      if (hospitals.isNotEmpty) {
        _selKind = 'hospital';
        _selId = hospitals.first.id;
      } else if (doctors.isNotEmpty) {
        _selKind = 'doctor';
        _selId = doctors.first.id;
      } else if (labs.isNotEmpty) {
        _selKind = 'lab';
        _selId = labs.first.id;
      } else {
        _selKind = null;
        _selId = null;
      }
    }
  }

  void _selectFirstOf(String kind, List<Doctor> doctors, List<Lab> labs,
      List<Hospital> hospitals) {
    setState(() {
      if (kind == 'doctor' && doctors.isNotEmpty) {
        _selKind = 'doctor';
        _selId = doctors.first.id;
      } else if (kind == 'lab' && labs.isNotEmpty) {
        _selKind = 'lab';
        _selId = labs.first.id;
      } else if (kind == 'hospital' && hospitals.isNotEmpty) {
        _selKind = 'hospital';
        _selId = hospitals.first.id;
      }
    });
  }

  // ---------- top bar ----------

  Widget _topBar(
      BuildContext context, WidgetRef ref, bool ur, String city) {
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickCity(context, ref, city),
                child: Container(
                  height: FdDim.searchHeight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(FdDim.pillRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: FdColors.primary, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          city,
                          style: FdType.body(false,
                              size: 17,
                              w: FontWeight.w700,
                              color: FdColors.ink),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down,
                          color: FdColors.ink, size: 26),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              shadowColor: Colors.black26,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const SearchScreen()),
                ),
                child: const SizedBox(
                  width: 60,
                  height: 60,
                  child: Icon(Icons.search,
                      color: FdColors.ink, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCity(
      BuildContext context, WidgetRef ref, String current) async {
    final repo = ref.read(repositoryProvider);
    final cities = await repo.watchCities().first;
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(tr(ref, 'map.changeCity'),
                  style: FdType.title(fdIsUrdu(ref.read(localeProvider)),
                      size: 19)),
            ),
            for (final c in cities.toSet())
              ListTile(
                leading: const Icon(Icons.location_on_outlined,
                    color: FdColors.primary),
                title: Text(c,
                    style: FdType.body(
                        fdIsUrdu(ref.read(localeProvider)),
                        size: 16,
                        w: FontWeight.w600,
                        color: FdColors.ink)),
                trailing: c == current
                    ? const Icon(Icons.check, color: FdColors.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(c),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(cityProvider.notifier).setCity(picked);
    }
  }

  // ---------- type chips ----------

  Widget _typeChips(WidgetRef ref, bool ur) {
    final chips = [
      (_PinType.all, tr(ref, 'map.all'), null),
      (_PinType.doctors, tr(ref, 'map.doctors'), FdColors.primary),
      (_PinType.labs, tr(ref, 'map.labs'), FdColors.lavenderInk),
      (_PinType.hospitals, tr(ref, 'map.hospitals'), FdColors.red),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 84),
        child: SizedBox(
          height: FdDim.chipHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final (kind, label, dot) = chips[i];
              final selected = _type == kind;
              return _typeChip(
                label: label,
                dot: dot,
                selected: selected,
                dark: kind == _PinType.all,
                onTap: () => setState(() {
                  _type = kind;
                  _selKind = null;
                  _selId = null;
                }),
              );
            },
          ),
        ),
      ),
    );
  }

  /// "All" is ink-filled when selected; type chips are white with a dot.
  Widget _typeChip({
    required String label,
    required Color? dot,
    required bool selected,
    required bool dark,
    required VoidCallback onTap,
  }) {
    final bg = dark
        ? (selected ? FdColors.ink : Colors.white)
        : Colors.white;
    final fg = dark && selected ? Colors.white : FdColors.ink;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(FdDim.pillRadius),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(FdDim.pillRadius),
        onTap: onTap,
        child: Container(
          height: FdDim.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FdDim.pillRadius),
            border: (!dark || !selected)
                ? Border.all(color: FdColors.line, width: 1.2)
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration:
                      BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: FdType.latin,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- live map ----------

  Widget _liveMap(String city, List<Doctor> doctors, List<Lab> labs,
      List<Hospital> hospitals) {
    final fallback = _coordsFor(city);
    final markers = <Marker>{
      for (final d in doctors)
        if (d.lat != null && d.lng != null)
          Marker(
            markerId: MarkerId('doctor_${d.id}'),
            position: LatLng(d.lat!, d.lng!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueCyan),
            onTap: () => setState(() {
              _selKind = 'doctor';
              _selId = d.id;
            }),
          ),
      for (final l in labs)
        if (l.lat != null && l.lng != null)
          Marker(
            markerId: MarkerId('lab_${l.id}'),
            position: LatLng(l.lat!, l.lng!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue),
            onTap: () => setState(() {
              _selKind = 'lab';
              _selId = l.id;
            }),
          ),
      for (final h in hospitals)
        if (h.lat != null && h.lng != null)
          Marker(
            markerId: MarkerId('hospital_${h.id}'),
            position: LatLng(h.lat!, h.lng!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
            onTap: () => setState(() {
              _selKind = 'hospital';
              _selId = h.id;
            }),
          ),
    };
    return GoogleMap(
      onMapCreated: (c) => _controller = c,
      initialCameraPosition:
          CameraPosition(target: fallback, zoom: 12),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: markers,
    );
  }

  // ---------- locate button ----------

  Widget _locateButton(BuildContext context, WidgetRef ref) {
    return Positioned(
      right: 16,
      bottom: 168,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _goToMyLocation(context, ref),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.my_location,
                color: Color(0xFF2B6CB0), size: 28),
          ),
        ),
      ),
    );
  }

  Future<void> _goToMyLocation(
      BuildContext context, WidgetRef ref) async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'locationNeeded'))),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)));
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
            LatLng(pos.latitude, pos.longitude), 14),
      );
      ref.invalidate(userLocationProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'error'))),
      );
    }
  }

  // ---------- bottom card ----------

  Widget _bottomCard(
    BuildContext context,
    WidgetRef ref,
    bool ur,
    List<Doctor> doctors,
    List<Lab> labs,
    List<Hospital> hospitals,
  ) {
    if (_selKind == null || _selId == null) {
      return const SizedBox.shrink();
    }
    final pos = ref.watch(userLocationProvider).value;
    late final String name;
    late final String sub;
    late final String ratingLine;
    late final Color tileBg;
    late final Color tileFg;
    late final IconData tileIcon;
    late final Widget Function() opener;

    if (_selKind == 'hospital') {
      final h = hospitals.firstWhere((e) => e.id == _selId,
          orElse: () => hospitals.first);
      name = h.name;
      final dist = distanceText(pos, h.lat, h.lng);
      sub = [
        tr(ref, 'hosp.hospital'),
        if (dist case final d?) d,
      ].join(' · ');
      final r =
          h.reviewCount > 0 ? '★ ${h.rating.toStringAsFixed(1)}  ' : '';
      ratingLine =
          '$r${h.emergency247 ? tr(ref, 'map.emergencyOpen') : ''}'.trim();
      tileBg = FdColors.redSoft;
      tileFg = FdColors.red;
      tileIcon = Icons.add;
      opener = () => HospitalDetailScreen(hospitalId: h.id);
    } else if (_selKind == 'lab') {
      final l =
          labs.firstWhere((e) => e.id == _selId, orElse: () => labs.first);
      name = l.name;
      final dist = distanceText(pos, l.lat, l.lng);
      sub = [
        tr(ref, 'map.labs'),
        if (dist case final d?) d,
      ].join(' · ');
      ratingLine = l.reviewCount > 0
          ? '★ ${l.rating.toStringAsFixed(1)}'
          : tr(ref, 'map.new');
      tileBg = FdColors.lavender;
      tileFg = FdColors.lavenderInk;
      tileIcon = Icons.science_outlined;
      opener = () => LabDetailScreen(labId: l.id);
    } else {
      final d = doctors.firstWhere((e) => e.id == _selId,
          orElse: () => doctors.first);
      name = d.name;
      final dist = distanceText(pos, d.lat, d.lng);
      sub = [
        specialtyLabel(ref.watch(localeProvider), d.specialty),
        if (dist case final d?) d,
      ].join(' · ');
      ratingLine = d.reviewCount > 0
          ? '★ ${d.rating.toStringAsFixed(1)}'
          : tr(ref, 'map.new');
      tileBg = FdColors.mint;
      tileFg = FdColors.primary;
      tileIcon = Icons.person_outline;
      opener = () => DoctorDetailScreen(doctorId: d.id);
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdDim.cardRadius),
        elevation: 4,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: BorderRadius.circular(FdDim.cardRadius),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => opener()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Icon(tileIcon, color: tileFg, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: FdType.body(ur,
                              size: 18,
                              w: FontWeight.w700,
                              color: FdColors.ink)),
                      const SizedBox(height: 2),
                      Text(sub,
                          style: FdType.body(ur,
                              size: 14, color: FdColors.muted)),
                      if (ratingLine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(ratingLine,
                            style: FdType.body(ur,
                                size: 15,
                                w: FontWeight.w600,
                                color: FdColors.primary)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: FdColors.muted, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stylized map placeholder shown until a Google Maps API key is configured:
/// light blocks, white roads, a river, and tappable colored pins.
class _MapPlaceholder extends StatelessWidget {
  final List<Doctor> doctors;
  final List<Lab> labs;
  final List<Hospital> hospitals;
  final ValueChanged<String> onPinTap;

  const _MapPlaceholder({
    required this.doctors,
    required this.labs,
    required this.hospitals,
    required this.onPinTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final pins = _pinLayout(size);
        return GestureDetector(
          onTapDown: (d) {
            var best = -1;
            var bestDist = 48.0;
            for (var i = 0; i < pins.length; i++) {
              final dist = (pins[i].offset - d.localPosition).distance;
              if (dist < bestDist) {
                bestDist = dist;
                best = i;
              }
            }
            if (best >= 0) onPinTap(pins[best].kind);
          },
          child: CustomPaint(
            size: size,
            painter: _PlaceholderPainter(pins),
          ),
        );
      },
    );
  }

  List<_Pin> _pinLayout(Size s) {
    final pins = <_Pin>[];
    if (doctors.isNotEmpty) {
      pins.add(_Pin('doctor', Offset(s.width * 0.30, s.height * 0.30)));
      if (doctors.length > 1) {
        pins.add(_Pin('doctor', Offset(s.width * 0.66, s.height * 0.42)));
      }
    }
    if (labs.isNotEmpty) {
      pins.add(_Pin('lab', Offset(s.width * 0.72, s.height * 0.24)));
      if (labs.length > 1) {
        pins.add(_Pin('lab', Offset(s.width * 0.20, s.height * 0.55)));
      }
    }
    if (hospitals.isNotEmpty) {
      pins.add(_Pin('hospital', Offset(s.width * 0.52, s.height * 0.62)));
      if (hospitals.length > 1) {
        pins.add(_Pin('hospital', Offset(s.width * 0.78, s.height * 0.68)));
      }
    }
    return pins;
  }
}

class _Pin {
  final String kind;
  final Offset offset;
  _Pin(this.kind, this.offset);
}

class _PlaceholderPainter extends CustomPainter {
  final List<_Pin> pins;
  _PlaceholderPainter(this.pins);

  @override
  void paint(Canvas canvas, Size size) {
    // background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFE9F0EE),
    );
    // blocks
    final block = Paint()..color = const Color(0xFFDDE8E4);
    for (final r in [
      Rect.fromLTWH(size.width * 0.06, size.height * 0.20, size.width * 0.24,
          size.height * 0.10),
      Rect.fromLTWH(size.width * 0.40, size.height * 0.16, size.width * 0.20,
          size.height * 0.08),
      Rect.fromLTWH(size.width * 0.70, size.height * 0.34, size.width * 0.22,
          size.height * 0.10),
      Rect.fromLTWH(size.width * 0.10, size.height * 0.62, size.width * 0.24,
          size.height * 0.10),
      Rect.fromLTWH(size.width * 0.60, size.height * 0.74, size.width * 0.28,
          size.height * 0.12),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(10)), block);
    }
    // roads
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    for (final fx in [0.28, 0.55, 0.82]) {
      canvas.drawLine(Offset(size.width * fx, 0),
          Offset(size.width * fx, size.height), road);
    }
    for (final fy in [0.32, 0.52, 0.70]) {
      canvas.drawLine(Offset(0, size.height * fy),
          Offset(size.width, size.height * fy), road);
    }
    // river
    final river = Paint()
      ..color = const Color(0xFFCFE3F5)
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final riverPath = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.70,
          size.width * 0.6, size.height * 0.76)
      ..quadraticBezierTo(
          size.width * 0.8, size.height * 0.81, size.width, size.height * 0.74);
    canvas.drawPath(riverPath, river);
    // user dot
    final userAt = Offset(size.width * 0.47, size.height * 0.52);
    canvas.drawCircle(
        userAt, 34, Paint()..color = const Color(0xFF2B6CB0).withValues(alpha: 0.18));
    canvas.drawCircle(
        userAt, 11, Paint()..color = const Color(0xFF2B6CB0));
    canvas.drawCircle(userAt, 11,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
    // pins
    for (final p in pins) {
      _drawPin(canvas, p);
    }
  }

  void _drawPin(Canvas canvas, _Pin p) {
    final Color color;
    switch (p.kind) {
      case 'doctor':
        color = FdColors.primary;
        break;
      case 'lab':
        color = FdColors.lavenderInk;
        break;
      default:
        color = FdColors.red;
    }
    // shadow + white ring + colored circle
    canvas.drawCircle(
        p.offset + const Offset(0, 3),
        27,
        Paint()..color = Colors.black.withValues(alpha: 0.15));
    canvas.drawCircle(p.offset, 27, Paint()..color = Colors.white);
    canvas.drawCircle(p.offset, 22, Paint()..color = color);
    // white glyph
    final g = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final o = p.offset;
    if (p.kind == 'doctor') {
      canvas.drawCircle(o + const Offset(0, -6), 5.5, Paint()..color = Colors.white);
      canvas.drawArc(
        Rect.fromCenter(center: o + const Offset(0, 10), width: 20, height: 14),
        3.6,
        2.1,
        false,
        g,
      );
    } else if (p.kind == 'lab') {
      final path = Path()
        ..moveTo(o.dx - 7, o.dy - 11)
        ..lineTo(o.dx - 7, o.dy - 2)
        ..lineTo(o.dx - 11, o.dy + 9)
        ..lineTo(o.dx + 11, o.dy + 9)
        ..lineTo(o.dx + 7, o.dy - 2)
        ..lineTo(o.dx + 7, o.dy - 11)
        ..close();
      canvas.drawPath(path, g);
    } else {
      canvas.drawLine(o + const Offset(-8, 0), o + const Offset(8, 0), g);
      canvas.drawLine(o + const Offset(0, -8), o + const Offset(0, 8), g);
    }
  }

  @override
  bool shouldRepaint(covariant _PlaceholderPainter old) =>
      old.pins.length != pins.length;
}
