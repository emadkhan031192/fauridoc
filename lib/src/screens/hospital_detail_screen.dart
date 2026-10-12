import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hospital.dart';
import '../providers/providers.dart';
import '../utils/actions.dart';
import '../widgets/rating_stars.dart';
import '../widgets/theme.dart';

/// Full profile of one hospital: header with 24/7 emergency pill, contact,
/// emergency contact row, departments, visiting hours, call/map actions.
class HospitalDetailScreen extends ConsumerStatefulWidget {
  final String hospitalId;

  const HospitalDetailScreen({super.key, required this.hospitalId});

  @override
  ConsumerState<HospitalDetailScreen> createState() =>
      _HospitalDetailScreenState();
}

class _HospitalDetailScreenState extends ConsumerState<HospitalDetailScreen> {
  Hospital? _hospital;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final hospital =
          await ref.read(repositoryProvider).getHospital(widget.hospitalId);
      if (!mounted) return;
      setState(() {
        _hospital = hospital;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final hospital = _hospital;
    return Scaffold(
      appBar: AppBar(title: Text(hospital?.name ?? '')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? _errorBody()
              : hospital == null
                  ? Center(child: Text(tr(ref, 'noResults')))
                  : _detailBody(hospital),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(tr(ref, 'error')),
            const SizedBox(height: 12),
            FilledButton(onPressed: _retry, child: Text(tr(ref, 'retry'))),
          ],
        ),
      ),
    );
  }

  Widget _detailBody(Hospital hospital) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerCard(hospital),
          if (hospital.emergencyPhone.trim().isNotEmpty)
            _emergencyCard(hospital),
          if (hospital.departments.isNotEmpty) _departmentsCard(hospital),
          if (hospital.visitingHours.trim().isNotEmpty)
            _visitingHoursCard(hospital),
          _actionsCard(hospital),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  TextStyle _sectionTitle(BuildContext context) {
    return Theme.of(context)
        .textTheme
        .titleMedium!
        .copyWith(fontWeight: FontWeight.w800);
  }

  // ---------- header ----------

  Widget _headerCard(Hospital hospital) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntityAvatar(
                  photoUrl: hospital.photoUrl,
                  name: hospital.name,
                  radius: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospital.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (hospital.verified)
                          Pill(
                            label: tr(ref, 'verified'),
                            icon: Icons.verified,
                          ),
                        if (hospital.emergency247)
                          Pill(
                            label: tr(ref, 'emergency247'),
                            icon: Icons.emergency,
                            color: FauridocTheme.emergencyRed,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(hospital.city,
                            style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RatingStars(
                      rating: hospital.rating,
                      reviewCount: hospital.reviewCount,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hospital.address.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(tr(ref, 'address'), hospital.address, Icons.location_on),
          ],
          if (hospital.phone.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            _infoRow(tr(ref, 'phone'), hospital.phone, Icons.phone),
          ],
          if (hospital.hasParking) ...[
            const SizedBox(height: 8),
            Pill(
              label: tr(ref, 'parking'),
              icon: Icons.local_parking,
              color: Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: FauridocTheme.tealDark),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(color: Colors.grey[700])),
        ),
        Expanded(
          child:
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ---------- emergency contact ----------

  Widget _emergencyCard(Hospital hospital) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: FauridocTheme.emergencyRed.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: FauridocTheme.emergencyRed.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.emergency,
                color: FauridocTheme.emergencyRed, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(ref, 'emergencyContact'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: FauridocTheme.emergencyRed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hospital.emergencyPhone,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: FauridocTheme.emergencyRed,
              ),
              onPressed: () =>
                  callNumber(context, hospital.emergencyPhone),
              icon: const Icon(Icons.call),
              label: Text(tr(ref, 'call')),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- departments ----------

  Widget _departmentsCard(Hospital hospital) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'departments'), style: _sectionTitle(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in hospital.departments) Chip(label: Text(d)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- visiting hours ----------

  Widget _visitingHoursCard(Hospital hospital) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'visitingHours'), style: _sectionTitle(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule,
                  size: 18, color: FauridocTheme.tealDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hospital.visitingHours,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- actions ----------

  Widget _actionsCard(Hospital hospital) {
    return _card(
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => callNumber(context, hospital.phone),
            icon: const Icon(Icons.call),
            label: Text(tr(ref, 'call')),
          ),
          OutlinedButton.icon(
            onPressed: () => openDirections(
                context, hospital.lat, hospital.lng, hospital.name),
            icon: const Icon(Icons.map),
            label: Text(tr(ref, 'viewOnMap')),
          ),
        ],
      ),
    );
  }
}
