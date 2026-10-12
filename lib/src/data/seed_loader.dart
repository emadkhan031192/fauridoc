import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';

/// Structured seed data bundled with the app (assets/seed_data/*.json),
/// produced from the researched KP doctor/lab/hospital lists.
class SeedBundle {
  final List<Doctor> doctors;
  final List<Lab> labs;
  final List<Hospital> hospitals;
  final List<String> cities;
  final List<String> specialties;
  final Map<String, String> specialtyUr;
  final List<String> testCategories;

  const SeedBundle({
    required this.doctors,
    required this.labs,
    required this.hospitals,
    required this.cities,
    required this.specialties,
    required this.specialtyUr,
    required this.testCategories,
  });
}

Future<List<Map<String, dynamic>>> _loadJsonList(String asset) async {
  final raw = await rootBundle.loadString(asset);
  return (jsonDecode(raw) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

/// Loads the bundled research data. Never throws — returns empty lists on
/// failure so the app still starts.
Future<SeedBundle> loadSeedBundle() async {
  try {
    final doctors = [
      for (final m in await _loadJsonList('assets/seed_data/doctors.json'))
        Doctor.fromJson(m),
    ];
    final labs = [
      for (final m in await _loadJsonList('assets/seed_data/labs.json'))
        Lab.fromJson(m),
    ];
    final hospitals = [
      for (final m in await _loadJsonList('assets/seed_data/hospitals.json'))
        Hospital.fromJson(m),
    ];
    final configRaw =
        jsonDecode(await rootBundle.loadString('assets/seed_data/config.json'))
            as Map;
    final cities = ((configRaw['cities'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final specialties = ((configRaw['specialties'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final specialtyUr =
        ((configRaw['specialtyUr'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
    final cats = <String>{};
    for (final lab in labs) {
      for (final t in lab.tests) {
        if (t.category.trim().isNotEmpty) cats.add(t.category.trim());
      }
    }
    return SeedBundle(
      doctors: doctors,
      labs: labs,
      hospitals: hospitals,
      cities: cities.isEmpty ? const ['Mardan'] : cities,
      specialties: specialties,
      specialtyUr: specialtyUr,
      testCategories: cats.toList()..sort(),
    );
  } catch (_) {
    return const SeedBundle(
      doctors: [],
      labs: [],
      hospitals: [],
      cities: ['Mardan'],
      specialties: [],
      specialtyUr: {},
      testCategories: [],
    );
  }
}
