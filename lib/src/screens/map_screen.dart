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
import '../providers/font_scale.dart';
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
    ref.watch(fontScaleProvider); // Re-render when the font-size sliders change.
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
                // StackFit.expand: the stack fills the whole tab area so the
                // Positioned.fill map layer covers it. (With the default
                // loose fit the stack would shrink to the small non-positioned
                // header children and the map would only paint a short strip
                // at the top, leaving the rest of the tab blank white.)
                return Stack(
                  fit: StackFit.expand,
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
                              selectedKind: _selKind,
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
    // Spec: city pill 48px, radius 24, 15/700 text, 20px teal pin icon,
    // 16px chevron; round search button 48px with 21px icon.
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: _FdPress(
                onTap: () => _pickCity(context, ref, city),
                child: Container(
                  height: 48,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color:
                            FdColors.ink.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: FdColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          city,
                          style: FdType.body(false,
                              size: 15,
                              w: FontWeight.w700,
                              color: FdColors.ink),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down,
                          color: FdColors.ink, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _FdPress(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SearchScreen()),
              ),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          FdColors.ink.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.search,
                    color: FdColors.ink, size: 21),
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
        padding: const EdgeInsets.only(top: 70),
        child: SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
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
  /// Spec: 38px tall, 13/700, 10px dot, no border.
  Widget _typeChip({
    required String label,
    required Color? dot,
    required bool selected,
    required bool dark,
    required VoidCallback onTap,
  }) {
    final bg = dark && selected ? FdColors.ink : Colors.white;
    final fg = dark && selected ? Colors.white : FdColors.ink;
    return _FdPress(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              color: FdColors.ink.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                // Spec: the selected "All" dot is ink on ink (invisible).
                color: dark
                    ? (selected ? FdColors.ink : FdColors.primary)
                    : dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: FdType.latin,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
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
    // Spec: 48px circle at right:16, top:536 on the 844 artboard
    // (bottom offset 260), 22px #2F6BFF crosshair icon.
    return Positioned(
      right: 16,
      bottom: 260,
      child: _FdPress(
        onTap: () => _goToMyLocation(context, ref),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: FdColors.ink.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.my_location,
              color: Color(0xFF2F6BFF), size: 22),
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
    late final double? rating;
    late final String statusText;
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
        // ignore: use_null_aware_elements
        if (dist != null) dist,
      ].join(' · ');
      rating = h.reviewCount > 0 ? h.rating : null;
      statusText =
          h.emergency247 ? tr(ref, 'map.emergencyOpen') : '';
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
        // ignore: use_null_aware_elements
        if (dist != null) dist,
      ].join(' · ');
      rating = l.reviewCount > 0 ? l.rating : null;
      statusText = l.reviewCount > 0 ? '' : tr(ref, 'map.new');
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
        // ignore: use_null_aware_elements
        if (dist != null) dist,
      ].join(' · ');
      rating = d.reviewCount > 0 ? d.rating : null;
      statusText = d.reviewCount > 0 ? '' : tr(ref, 'map.new');
      tileBg = FdColors.mint;
      tileFg = FdColors.primary;
      tileIcon = Icons.person_outline;
      opener = () => DoctorDetailScreen(doctorId: d.id);
    }

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: _FdPress(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => opener()),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: FdColors.ink.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(tileIcon, color: tileFg, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FdType.body(ur,
                          size: 16,
                          w: FontWeight.w800,
                          color: FdColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: FdType.body(ur,
                            size: 12.5,
                            w: FontWeight.w600,
                            color: FdColors.muted)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (rating != null) ...[
                          const Icon(Icons.star,
                              size: 13, color: FdColors.starGold),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontFamily: FdType.latin,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: FdColors.ink,
                            ),
                          ),
                        ],
                        if (statusText.isNotEmpty) ...[
                          if (rating != null)
                            const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: const TextStyle(
                              fontFamily: FdType.latin,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: FdColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: FdColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stylized map placeholder shown until a Google Maps API key is configured:
/// light blocks, white roads, a river, and tappable colored pins.
///
/// The art is painted at fixed 390x844 design coordinates: a [CustomPaint]
/// with an explicit size, wrapped in a [FittedBox] ([BoxFit.cover]) inside
/// [SizedBox.expand]. It fills any tab size with no fractional layout math
/// and no LayoutBuilder, so it can't collapse into broken white bars on odd
/// constraints.
class _MapPlaceholder extends StatelessWidget {
  final List<Doctor> doctors;
  final List<Lab> labs;
  final List<Hospital> hospitals;
  final ValueChanged<String> onPinTap;

  /// Kind of the currently selected pin (grows to 54px).
  final String? selectedKind;

  const _MapPlaceholder({
    required this.doctors,
    required this.labs,
    required this.hospitals,
    required this.onPinTap,
    this.selectedKind,
  });

  /// Fixed design artboard the placeholder is painted (and hit-tested) in.
  static const Size designSize = Size(390, 844);

  @override
  Widget build(BuildContext context) {
    final pins = _pinLayout();
    return GestureDetector(
      // Opaque: a childless CustomPaint never reports a hit on its own,
      // so without this pin taps would fall straight through.
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        // Map the tap from runtime pixels back into design coordinates so it
        // agrees with the fixed pin positions, then hit-test in design space
        // within ~28 design px of a pin center.
        final size = context.size;
        if (size == null || size.width <= 0 || size.height <= 0) return;
        final tap = Offset(
          d.localPosition.dx * designSize.width / size.width,
          d.localPosition.dy * designSize.height / size.height,
        );
        var best = -1;
        var bestDist = 28.0;
        for (var i = 0; i < pins.length; i++) {
          final dist = (pins[i].offset - tap).distance;
          if (dist < bestDist) {
            bestDist = dist;
            best = i;
          }
        }
        if (best >= 0) onPinTap(pins[best].kind);
      },
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: CustomPaint(
            size: designSize,
            painter: _PlaceholderPainter(pins, selectedKind),
          ),
        ),
      ),
    );
  }

  /// Representative pins at fixed design coordinates. The seed data carries
  /// no coordinates, so pins are illustrative: one per kind when the list is
  /// non-empty, a second when it holds more than one entry.
  List<_Pin> _pinLayout() {
    final pins = <_Pin>[];
    if (doctors.isNotEmpty) {
      pins.add(_Pin('doctor', const Offset(117, 253)));
      if (doctors.length > 1) {
        pins.add(_Pin('doctor', const Offset(257, 354)));
      }
    }
    if (labs.isNotEmpty) {
      pins.add(_Pin('lab', const Offset(281, 203)));
      if (labs.length > 1) {
        pins.add(_Pin('lab', const Offset(78, 464)));
      }
    }
    if (hospitals.isNotEmpty) {
      pins.add(_Pin('hospital', const Offset(203, 523)));
      if (hospitals.length > 1) {
        pins.add(_Pin('hospital', const Offset(304, 574)));
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
  final String? selectedKind;
  _PlaceholderPainter(this.pins, this.selectedKind);

  @override
  void paint(Canvas canvas, Size size) {
    // Guard: the placeholder is designed for the fixed 390x844 artboard.
    // Under degenerate layout (zero or infinite dimensions) paint nothing
    // instead of broken geometry.
    if (!size.isFinite || size.width <= 0 || size.height <= 0) return;
    // background #E7EDEA
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE7EDEA),
    );
    // blocks (#DDE8E4 rounded rects at fixed design coordinates)
    final block = Paint()..color = const Color(0xFFDDE8E4);
    for (final r in const [
      Rect.fromLTWH(24, 169, 94, 84),
      Rect.fromLTWH(156, 135, 78, 68),
      Rect.fromLTWH(273, 287, 86, 84),
      Rect.fromLTWH(39, 523, 94, 84),
      Rect.fromLTWH(234, 624, 109, 101),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(10)), block);
    }
    // roads: white vertical + horizontal lines
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    for (final x in [109.0, 215.0, 320.0]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), road);
    }
    for (final y in [270.0, 439.0, 591.0]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
    }
    // river: light-blue path near the bottom
    final river = Paint()
      ..color = const Color(0xFFCFE3F5)
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final riverPath = Path()
      ..moveTo(0, 658)
      ..quadraticBezierTo(137, 591, 234, 642)
      ..quadraticBezierTo(312, 683, 390, 624);
    canvas.drawPath(riverPath, river);
    // user location dot
    const userAt = Offset(183, 439);
    canvas.drawCircle(userAt, 34,
        Paint()..color = const Color(0xFF2B6CB0).withValues(alpha: 0.18));
    canvas.drawCircle(userAt, 11, Paint()..color = const Color(0xFF2B6CB0));
    canvas.drawCircle(
        userAt,
        11,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    // pins
    for (final p in pins) {
      _drawPin(canvas, p);
    }
  }

  void _drawPin(Canvas canvas, _Pin p) {
    final Color color;
    switch (p.kind) {
      case 'doctor':
        color = FdColors.primary; // #0B6B5C
        break;
      case 'lab':
        color = const Color(0xFF3552D6); // spec lab blue
        break;
      default:
        color = FdColors.red; // #C62828
    }
    // Spec: 44px pin, 3px white border, 0 2px 8px rgba(15,42,46,.3).
    // Selected: 54px with a 5px rgba(15,42,46,.18) halo.
    final selected = selectedKind != null && p.kind == selectedKind;
    final r = selected ? 27.0 : 22.0;
    final o = p.offset;
    if (selected) {
      canvas.drawCircle(
          o, r + 5, Paint()..color = const Color(0x2E0F2A2E));
      canvas.drawCircle(
          o + const Offset(0, 4),
          r,
          Paint()..color = FdColors.ink.withValues(alpha: 0.3));
    } else {
      canvas.drawCircle(
          o + const Offset(0, 2),
          r,
          Paint()..color = FdColors.ink.withValues(alpha: 0.3));
    }
    canvas.drawCircle(o, r, Paint()..color = Colors.white);
    canvas.drawCircle(o, r - 3, Paint()..color = color);
    // white glyph (~20px)
    final g = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (p.kind == 'doctor') {
      canvas.drawCircle(
          o + const Offset(0, -5.5), 5, Paint()..color = Colors.white);
      canvas.drawArc(
        Rect.fromCenter(
            center: o + const Offset(0, 9), width: 18, height: 13),
        3.6,
        2.1,
        false,
        g,
      );
    } else if (p.kind == 'lab') {
      final path = Path()
        ..moveTo(o.dx - 6, o.dy - 10)
        ..lineTo(o.dx - 6, o.dy - 2)
        ..lineTo(o.dx - 10, o.dy + 8)
        ..lineTo(o.dx + 10, o.dy + 8)
        ..lineTo(o.dx + 6, o.dy - 2)
        ..lineTo(o.dx + 6, o.dy - 10)
        ..close();
      canvas.drawPath(path, g);
    } else {
      canvas.drawLine(o + const Offset(-7, 0), o + const Offset(7, 0), g);
      canvas.drawLine(o + const Offset(0, -7), o + const Offset(0, 7), g);
    }
  }

  @override
  bool shouldRepaint(covariant _PlaceholderPainter old) {
    // Pins now sit at fixed design coordinates, so size no longer affects
    // them; repaint on kind, position, or selection changes.
    if (old.selectedKind != selectedKind) return true;
    if (old.pins.length != pins.length) return true;
    for (var i = 0; i < pins.length; i++) {
      if (old.pins[i].kind != pins[i].kind ||
          old.pins[i].offset != pins[i].offset) {
        return true;
      }
    }
    return false;
  }
}

/// Spec `.press`: scale to 0.97 in 80 ms on press.
class _FdPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _FdPress({required this.child, this.onTap});

  @override
  State<_FdPress> createState() => _FdPressState();
}

class _FdPressState extends State<_FdPress> {
  double _scale = 1;

  void _set(double s) {
    if (_scale != s) setState(() => _scale = s);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(0.97),
      onTapUp: (_) => _set(1),
      onTapCancel: () => _set(1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 80),
        child: widget.child,
      ),
    );
  }
}
