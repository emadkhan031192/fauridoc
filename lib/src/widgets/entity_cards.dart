import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../utils/geo.dart';
import 'rating_stars.dart';
import 'theme.dart';

/// Card for a doctor row.
class DoctorCard extends ConsumerWidget {
  final Doctor doctor;
  final VoidCallback? onTap;
  final bool showDistance;
  final double? distanceKm;

  const DoctorCard({
    super.key,
    required this.doctor,
    this.onTap,
    this.showDistance = false,
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntityAvatar(photoUrl: doctor.photoUrl, name: doctor.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doctor.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (doctor.verified)
                          Pill(
                            label: tr(ref, 'verified'),
                            icon: Icons.verified,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${specialtyLabel(locale, doctor.specialty)} · ${doctor.city}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingStars(
                          rating: doctor.rating,
                          reviewCount: doctor.reviewCount,
                        ),
                        if (showDistance && distanceKm != null) ...[
                          const Spacer(),
                          Text(
                            formatDistance(distanceKm!),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
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
}

/// Card for a lab row. When [testQuery] names a test the lab offers, its
/// price is shown; otherwise the number of listed tests.
class LabCard extends ConsumerWidget {
  final Lab lab;
  final String? testQuery;
  final VoidCallback? onTap;

  const LabCard({
    super.key,
    required this.lab,
    this.testQuery,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = (testQuery ?? '').trim();
    final price = q.isNotEmpty ? lab.priceFor(q) : null;
    final priceLine = price != null
        ? fill(tr(ref, 'rs'), {'p': price.toString()})
        : '${lab.tests.length} tests';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntityAvatar(photoUrl: lab.photoUrl, name: lab.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lab.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (lab.verified)
                          Pill(
                            label: tr(ref, 'verified'),
                            icon: Icons.verified,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lab.city,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingStars(
                          rating: lab.rating,
                          reviewCount: lab.reviewCount,
                        ),
                        const Spacer(),
                        Text(
                          priceLine,
                          style: TextStyle(
                            color: price != null
                                ? FauridocTheme.tealDark
                                : Colors.grey[600],
                            fontWeight: price != null
                                ? FontWeight.w700
                                : FontWeight.normal,
                            fontSize: 13,
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
      ),
    );
  }
}

/// Card for a hospital row.
class HospitalCard extends ConsumerWidget {
  final Hospital hospital;
  final double? distanceKm;
  final VoidCallback? onTap;

  const HospitalCard({
    super.key,
    required this.hospital,
    this.distanceKm,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntityAvatar(
                photoUrl: hospital.photoUrl,
                name: hospital.name,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hospital.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (hospital.emergency247)
                          Pill(
                            label: tr(ref, 'emergency247'),
                            color: FauridocTheme.emergencyRed,
                            icon: Icons.emergency,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hospital.city,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingStars(
                          rating: hospital.rating,
                          reviewCount: hospital.reviewCount,
                        ),
                        if (distanceKm != null) ...[
                          const Spacer(),
                          Text(
                            formatDistance(distanceKm!),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
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
}
