import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../models/model_utils.dart';
import '../providers/providers.dart';
import '../providers/font_scale.dart';
import '../widgets/theme.dart';

/// Which entity form ManageEntityScreen shows. Explicit [kind] wins;
/// when null it is inferred from the non-null entity arg (edit mode).
enum EntityKind { doctor, lab, hospital }

/// Full CRUD editor for one doctor / lab / hospital (admin + doctor self-edit).
/// AppBar: "Edit {Doctor|Lab|Hospital}". Hours maps are intentionally
/// untouched here (see RegisterEntityScreen: defaultHours on creation).
class ManageEntityScreen extends ConsumerStatefulWidget {
  final EntityKind? kind;
  final Doctor? doctor;
  final Lab? lab;
  final Hospital? hospital;

  const ManageEntityScreen(
      {super.key, this.kind, this.doctor, this.lab, this.hospital});

  @override
  ConsumerState<ManageEntityScreen> createState() =>
      _ManageEntityScreenState();
}

class _ManageEntityScreenState
    extends ConsumerState<ManageEntityScreen> {
  bool _busy = false;

  /// Effective form kind: explicit kind first, else inferred from the
  /// non-null entity; defaults to doctor for add mode.
  EntityKind get _kind =>
      widget.kind ??
      (widget.doctor != null
          ? EntityKind.doctor
          : widget.lab != null
              ? EntityKind.lab
              : widget.hospital != null
                  ? EntityKind.hospital
                  : EntityKind.doctor);

  /// True when editing an existing entity (add mode when false).
  bool get _isEdit =>
      widget.doctor != null ||
      widget.lab != null ||
      widget.hospital != null;

  // shared
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  bool _hasParking = false;
  bool _verified = false;
  bool _approved = false;

  // doctor
  final _specialty = TextEditingController();
  final _qualification = TextEditingController();
  final _clinicName = TextEditingController();
  final _whatsapp = TextEditingController();
  final _fee = TextEditingController();
  final _hoursText = TextEditingController();
  String? _specialtyDrop;
  String? _cityDrop;

  // lab
  List<LabTestPrice> _tests = [];

  // hospital
  final _emergencyPhone = TextEditingController();
  final _visitingHours = TextEditingController();
  bool _emergency247 = false;
  List<String> _departments = [];

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    final l = widget.lab;
    final h = widget.hospital;
    if (d != null) {
      _name.text = d.name;
      _specialty.text = d.specialty;
      _specialtyDrop = d.specialty.isEmpty ? null : d.specialty;
      _city.text = d.city;
      _cityDrop = d.city.isEmpty ? null : d.city;
      _qualification.text = d.qualification;
      _clinicName.text = d.clinicName;
      _address.text = d.address;
      _phone.text = d.phone;
      _whatsapp.text = d.whatsapp;
      _fee.text = d.fee?.toString() ?? '';
      _hoursText.text = d.hoursText;
      _hasParking = d.hasParking;
      _verified = d.verified;
      _approved = d.approved;
    } else if (l != null) {
      _name.text = l.name;
      _city.text = l.city;
      _cityDrop = l.city.isEmpty ? null : l.city;
      _address.text = l.address;
      _phone.text = l.phone;
      _hoursText.text = l.hoursText;
      _hasParking = l.hasParking;
      _verified = l.verified;
      _approved = l.approved;
      _tests = List.of(l.tests);
    } else if (h != null) {
      _name.text = h.name;
      _city.text = h.city;
      _cityDrop = h.city.isEmpty ? null : h.city;
      _address.text = h.address;
      _phone.text = h.phone;
      _emergencyPhone.text = h.emergencyPhone;
      _visitingHours.text = h.visitingHours;
      _emergency247 = h.emergency247;
      _departments = List.of(h.departments);
      _hasParking = h.hasParking;
      _verified = h.verified;
      _approved = h.approved;
    } else {
      // Add mode: admin-created records go live immediately; the admin
      // can still toggle these off before saving.
      _verified = true;
      _approved = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _address.dispose();
    _phone.dispose();
    _specialty.dispose();
    _qualification.dispose();
    _clinicName.dispose();
    _whatsapp.dispose();
    _fee.dispose();
    _hoursText.dispose();
    _emergencyPhone.dispose();
    _visitingHours.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _kindTitle {
    if (_isEdit) {
      return switch (_kind) {
        EntityKind.doctor => tr(ref, 'admin.editDoctor'),
        EntityKind.lab => tr(ref, 'admin.editLab'),
        EntityKind.hospital => tr(ref, 'admin.editHospital'),
      };
    }
    // Add mode: reuse the '+ Add ...' labels, stripped of the leading plus.
    final label = switch (_kind) {
      EntityKind.doctor => tr(ref, 'admin.addDoctor'),
      EntityKind.lab => tr(ref, 'admin.addLab'),
      EntityKind.hospital => tr(ref, 'admin.addHospital'),
    };
    return label.replaceFirst(RegExp(r'^\s*[+＋]\s*'), '');
  }

  Future<void> _save() async {
    final repo = ref.read(repositoryProvider);
    setState(() => _busy = true);
    try {
      // Admin-created records are written directly as live listings
      // (approved/verified default true — the switches still let the
      // admin override); _register is user-facing only (forces pending).
      switch (_kind) {
        case EntityKind.doctor:
          final d = widget.doctor;
          final city = _cityDrop ?? _city.text.trim();
          final specialty = _specialtyDrop ?? _specialty.text.trim();
          if (d != null) {
            await repo.updateDoctor(d.copyWith(
              name: _name.text.trim(),
              specialty: specialty,
              city: city,
              qualification: _qualification.text.trim(),
              clinicName: _clinicName.text.trim(),
              address: _address.text.trim(),
              phone: _phone.text.trim(),
              whatsapp: _whatsapp.text.trim(),
              fee: int.tryParse(_fee.text.trim()),
              hoursText: _hoursText.text.trim(),
              hasParking: _hasParking,
              verified: _verified,
              approved: _approved,
            ));
          } else {
            await repo.updateDoctor(Doctor(
              id: newId('dr_'),
              name: _name.text.trim(),
              specialty: specialty,
              city: city,
              qualification: _qualification.text.trim(),
              clinicName: _clinicName.text.trim(),
              address: _address.text.trim(),
              phone: _phone.text.trim(),
              whatsapp: _whatsapp.text.trim(),
              fee: int.tryParse(_fee.text.trim()),
              hoursText: _hoursText.text.trim(),
              hasParking: _hasParking,
              verified: _verified,
              approved: _approved,
              createdAt: DateTime.now(),
            ));
          }
        case EntityKind.lab:
          final l = widget.lab;
          final city = _cityDrop ?? _city.text.trim();
          if (l != null) {
            await repo.updateLab(l.copyWith(
              name: _name.text.trim(),
              city: city,
              address: _address.text.trim(),
              phone: _phone.text.trim(),
              tests: List.of(_tests),
              hoursText: _hoursText.text.trim(),
              hasParking: _hasParking,
              verified: _verified,
              approved: _approved,
            ));
          } else {
            await repo.updateLab(Lab(
              id: newId('lab_'),
              name: _name.text.trim(),
              city: city,
              address: _address.text.trim(),
              phone: _phone.text.trim(),
              tests: List.of(_tests),
              hoursText: _hoursText.text.trim(),
              hasParking: _hasParking,
              verified: _verified,
              approved: _approved,
              createdAt: DateTime.now(),
            ));
          }
        case EntityKind.hospital:
          final h = widget.hospital;
          final city = _cityDrop ?? _city.text.trim();
          if (h != null) {
            await repo.updateHospital(h.copyWith(
              name: _name.text.trim(),
              city: city,
              address: _address.text.trim(),
              phone: _phone.text.trim(),
              emergencyPhone: _emergencyPhone.text.trim(),
              visitingHours: _visitingHours.text.trim(),
              emergency247: _emergency247,
              departments: List.of(_departments),
              hasParking: _hasParking,
              verified: _verified,
              approved: _approved,
            ));
          } else {
            await repo.updateHospital(Hospital(
              id: newId('hsp_'),
              name: _name.text.trim(),
              city: city,
              address: _address.text.trim(),
              phone: _phone.text.trim(),
              emergencyPhone: _emergencyPhone.text.trim(),
              visitingHours: _visitingHours.text.trim(),
              emergency247: _emergency247,
              departments: List.of(_departments),
              hasParking: _hasParking,
              verified: _verified,
              approved: _approved,
              createdAt: DateTime.now(),
            ));
          }
      }
      if (!mounted) return;
      _snack(tr(ref, 'admin.saved'));
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_name.text),
        content: Text(tr(ref, 'admin.confirmDelete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(ref, 'admin.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr(ref, 'admin.delete'),
                style: const TextStyle(color: FdColors.redInk)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(repositoryProvider);
    setState(() => _busy = true);
    try {
      if (widget.doctor != null) {
        await repo.deleteDoctor(widget.doctor!.id);
      } else if (widget.lab != null) {
        await repo.deleteLab(widget.lab!.id);
      } else if (widget.hospital != null) {
        await repo.deleteHospital(widget.hospital!.id);
      }
      if (!mounted) return;
      _snack(tr(ref, 'admin.deleted'));
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fontScaleProvider); // Re-render when the font-size sliders change.
    final ur = fdIsUrdu(ref.watch(localeProvider));
    return Scaffold(
      body: Column(
        children: [
          _Header(ur: ur, title: _kindTitle),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  FdDim.page, 4, FdDim.page, 24),
              children: [
                _Card(
                  ur: ur,
                  children: [
                    _Field(
                      ur: ur,
                      label: tr(ref, 'admin.name'),
                      controller: _name,
                      hint: tr(ref, 'admin.name')),
                    if (_kind == EntityKind.doctor) ...[
                      _SpecialtyDrop(
                        ur: ur,
                        value: _specialtyDrop,
                        fallback: _specialty.text,
                        onChanged: (v) => setState(() => _specialtyDrop = v),
                      ),
                      _Field(
                        ur: ur,
                        label: tr(ref, 'admin.qualification'),
                        controller: _qualification,
                        hint: tr(ref, 'admin.qualification')),
                      _Field(
                        ur: ur,
                        label: tr(ref, 'admin.clinicName'),
                        controller: _clinicName,
                        hint: tr(ref, 'admin.clinicName')),
                    ],
                    _CityDrop(
                      ur: ur,
                      value: _cityDrop,
                      fallback: _city.text,
                      onChanged: (v) => setState(() => _cityDrop = v),
                    ),
                    _Field(
                      ur: ur,
                      label: tr(ref, 'admin.address'),
                      controller: _address,
                      hint: tr(ref, 'admin.address'),
                      maxLines: 2),
                    _Field(
                      ur: ur,
                      label: tr(ref, 'admin.phone'),
                      controller: _phone,
                      hint: tr(ref, 'admin.phone'),
                      keyboardType: TextInputType.phone),
                    if (_kind == EntityKind.doctor) ...[
                      _Field(
                        ur: ur,
                        label: tr(ref, 'admin.whatsapp'),
                        controller: _whatsapp,
                        hint: tr(ref, 'admin.whatsapp'),
                        keyboardType: TextInputType.phone),
                      _Field(
                        ur: ur,
                        label: tr(ref, 'admin.fee'),
                        controller: _fee,
                        hint: tr(ref, 'admin.fee'),
                        keyboardType: TextInputType.number),
                      _Field(
                        ur: ur,
                        label: tr(ref, 'admin.hoursText'),
                        controller: _hoursText,
                        hint: tr(ref, 'admin.hoursText')),
                    ],
                    if (_kind == EntityKind.lab)
                    _Field(
                      ur: ur,
                      label: tr(ref, 'admin.hoursText'),
                      controller: _hoursText,
                      hint: tr(ref, 'admin.hoursText')),
                    if (_kind == EntityKind.hospital) ...[
                      _Field(
                        ur: ur,
                        label: tr(ref, 'admin.emergencyPhone'),
                        controller: _emergencyPhone,
                        hint: tr(ref, 'admin.emergencyPhone'),
                        keyboardType: TextInputType.phone),
                      _Field(
                        ur: ur,
                        label: tr(ref, 'admin.visitingHours'),
                        controller: _visitingHours,
                        hint: tr(ref, 'admin.visitingHours')),
                      _SwitchRow(
                        ur: ur,
                        label: tr(ref, 'admin.emergency247'),
                        value: _emergency247,
                        onChanged: (v) =>
                        setState(() => _emergency247 = v),
                      ),
                      _DepartmentsEditor(
                        ur: ur,
                        items: _departments,
                        onChanged: (v) =>
                        setState(() => _departments = v),
                      ),
                    ],
                  ],
                ),
                if (_kind == EntityKind.lab) ...[
                  const SizedBox(height: 16),
                  _TestsEditor(
                    ur: ur,
                    tests: _tests,
                    onChanged: (v) => setState(() => _tests = v),
                  ),
                ],
                const SizedBox(height: 16),
                _Card(
                  ur: ur,
                  children: [
                    _SwitchRow(
                      ur: ur,
                      label: tr(ref, 'admin.parking'),
                      value: _hasParking,
                      onChanged: (v) =>
                      setState(() => _hasParking = v),
                    ),
                    _SwitchRow(
                      ur: ur,
                      label: tr(ref, 'admin.verified'),
                      value: _verified,
                      onChanged: (v) =>
                      setState(() => _verified = v),
                    ),
                    _SwitchRow(
                      ur: ur,
                      label: tr(ref, 'admin.approved'),
                      value: _approved,
                      onChanged: (v) =>
                      setState(() => _approved = v),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FdButton(
                  label: tr(ref, 'admin.save'),
                  isUrdu: ur,
                  onTap: _busy ? null : _save,
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 12),
                  FdButton(
                    label: tr(ref, 'admin.deleteRecord'),
                    style: FdButtonStyle.danger,
                    icon: Icons.delete_outline,
                    isUrdu: ur,
                    onTap: _busy ? null : _delete,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Spec back bar: 44px back chevron + 20/800 title, 48px top padding.
class _Header extends StatelessWidget {
  final bool ur;
  final String title;

  const _Header({required this.ur, required this.title});

  @override
  Widget build(BuildContext context) {
    final rtl =
        Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 48, 10, 8),
      child: Row(
        children: [
          _PressScale(
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                rtl ? Icons.chevron_right : Icons.chevron_left,
                color: FdColors.ink,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: FdType.family(ur),
                fontSize: FdType.scaled(ur, 20),
                fontWeight: FontWeight.w800,
                letterSpacing: ur ? 0 : -0.2,
                color: FdColors.ink,
                height: FdType.height(ur, 1.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Press feedback: scale to 0.97 in 80 ms (spec `.press` class).
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressScale({required this.child, this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp:
          widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? FdSpec.pressScale : 1.0,
        duration: FdSpec.pressDuration,
        child: widget.child,
      ),
    );
  }
}

/// Spec switch: 52x32 track, 26px knob, teal when on.
class _FdSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FdSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          color: value ? FdColors.primary : _switchOff,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              top: 3,
              left: value ? 23 : 3,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _switchOff = Color(0xFFB7C4C0);

/// White rounded card grouping form fields.
class _Card extends StatelessWidget {
  final bool ur;
  final List<Widget> children;
  const _Card({required this.ur, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdSpec.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Cap extends StatelessWidget {
  final bool ur;
  final String label;
  const _Cap({required this.ur, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(label.toUpperCase(),
          style: TextStyle(
            fontFamily: FdType.family(ur),
            fontSize: FdType.scaled(ur, 12),
            fontWeight: FontWeight.w700,
            letterSpacing: ur ? 0 : 0.72,
            color: FdColors.muted,
            height: FdType.height(ur, 1.3),
          )),
    );
  }
}

class _Field extends StatelessWidget {
  final bool ur;
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final int maxLines;

  const _Field({
    required this.ur,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final multi = maxLines > 1;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: FdSpec.inputBorder),
    );
    final field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: FdType.body(ur,
          size: 15, w: FontWeight.w600, color: FdColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: FdType.body(ur,
            size: 15, w: FontWeight.w600, color: FdSpec.placeholder),
        filled: true,
        fillColor: Colors.white,
        contentPadding: multi
            ? const EdgeInsets.fromLTRB(14, 12, 14, 12)
            : const EdgeInsets.symmetric(horizontal: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide:
              const BorderSide(color: FdColors.primary, width: 1.6),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cap(ur: ur, label: label),
        const SizedBox(height: 6),
        multi ? field : SizedBox(height: 50, child: field),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final bool ur;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.ur,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: FdType.body(ur,
                      size: 15,
                      w: FontWeight.w600,
                      color: FdColors.ink)),
            ),
            _FdSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Specialty dropdown that also accepts the stored free-text value.
class _SpecialtyDrop extends ConsumerWidget {
  final bool ur;
  final String? value;
  final String fallback;
  final ValueChanged<String?> onChanged;

  const _SpecialtyDrop({
    required this.ur,
    required this.value,
    required this.fallback,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<String>>(
      stream: ref.read(repositoryProvider).watchSpecialties(),
      builder: (context, snap) {
        final items = snap.data ?? const <String>[];
        final effective =
            (value != null && items.contains(value)) ? value : null;
        final border = OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FdSpec.inputBorder),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cap(ur: ur, label: tr(ref, 'admin.specialization')),
            const SizedBox(height: 6),
            SizedBox(
              height: 50,
              child: DropdownButtonFormField<String>(
                initialValue: effective,
                hint: Text(
                    fallback.isEmpty
                        ? tr(ref, 'admin.specialization')
                        : fallback,
                    style: FdType.body(ur,
                        size: 15,
                        w: FontWeight.w600,
                        color: FdSpec.placeholder)),
                items: [
                  for (final it in items)
                    DropdownMenuItem(value: it, child: Text(it))
                ],
                onChanged: onChanged,
                style: FdType.body(ur,
                    size: 15,
                    w: FontWeight.w600,
                    color: FdColors.ink),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: FdColors.ink, size: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(
                        color: FdColors.primary, width: 1.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        );
      },
    );
  }
}

/// City dropdown with free-text fallback.
class _CityDrop extends ConsumerWidget {
  final bool ur;
  final String? value;
  final String fallback;
  final ValueChanged<String?> onChanged;

  const _CityDrop({
    required this.ur,
    required this.value,
    required this.fallback,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<String>>(
      stream: ref.read(repositoryProvider).watchCities(),
      builder: (context, snap) {
        final items = snap.data ?? const <String>[];
        final effective =
            (value != null && items.contains(value)) ? value : null;
        final border = OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FdSpec.inputBorder),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cap(ur: ur, label: tr(ref, 'admin.city')),
            const SizedBox(height: 6),
            SizedBox(
              height: 50,
              child: DropdownButtonFormField<String>(
                initialValue: effective,
                hint: Text(
                    fallback.isEmpty
                        ? tr(ref, 'admin.city')
                        : fallback,
                    style: FdType.body(ur,
                        size: 15,
                        w: FontWeight.w600,
                        color: FdSpec.placeholder)),
                items: [
                  for (final it in items)
                    DropdownMenuItem(value: it, child: Text(it))
                ],
                onChanged: onChanged,
                style: FdType.body(ur,
                    size: 15,
                    w: FontWeight.w600,
                    color: FdColors.ink),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: FdColors.ink, size: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(
                        color: FdColors.primary, width: 1.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        );
      },
    );
  }
}

/// Departments chips editor (hospital).
class _DepartmentsEditor extends ConsumerStatefulWidget {
  final bool ur;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;

  const _DepartmentsEditor({
    required this.ur,
    required this.items,
    required this.onChanged,
  });

  @override
  ConsumerState<_DepartmentsEditor> createState() =>
      _DepartmentsEditorState();
}

class _DepartmentsEditorState
    extends ConsumerState<_DepartmentsEditor> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cap(ur: widget.ur, label: tr(ref, 'admin.departments')),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              Container(
                decoration: BoxDecoration(
                  color: FdColors.mint,
                  borderRadius:
                      BorderRadius.circular(FdDim.pillRadius),
                ),
                padding: const EdgeInsets.only(
                    left: 14, right: 6, top: 8, bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.items[i],
                        style: FdType.body(widget.ur,
                            size: 14,
                            w: FontWeight.w600,
                            color: FdColors.ink)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        final next =
                            List<String>.of(widget.items)
                              ..removeAt(i);
                        widget.onChanged(next);
                      },
                      child: const Icon(Icons.close,
                          color: FdColors.muted, size: 18),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: TextField(
                  controller: _ctrl,
                  style: FdType.body(widget.ur,
                      size: 15, color: FdColors.ink),
                  decoration: InputDecoration(
                    hintText: tr(ref, 'admin.departmentsHint'),
                    hintStyle: FdType.body(widget.ur,
                        size: 15, color: FdColors.muted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: FdSpec.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: FdSpec.inputBorder),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              child: FdButton(
                label: tr(ref, 'admin.add'),
                isUrdu: widget.ur,
                onTap: () {
                  final v = _ctrl.text.trim();
                  if (v.isEmpty || widget.items.contains(v)) {
                    return;
                  }
                  widget.onChanged([...widget.items, v]);
                  _ctrl.clear();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Tests & prices editor (lab).
class _TestsEditor extends ConsumerStatefulWidget {
  final bool ur;
  final List<LabTestPrice> tests;
  final ValueChanged<List<LabTestPrice>> onChanged;

  const _TestsEditor({
    required this.ur,
    required this.tests,
    required this.onChanged,
  });

  @override
  ConsumerState<_TestsEditor> createState() => _TestsEditorState();
}

class _TestsEditorState extends ConsumerState<_TestsEditor> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  String? _category;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FdSpec.cardRadius),
        border: Border.all(color: FdColors.line),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(tr(ref, 'admin.tests'),
                style: FdType.title(widget.ur, size: 18)),
          ),
          for (var i = 0; i < widget.tests.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(widget.tests[i].test,
                            style: FdType.body(widget.ur,
                                size: 15,
                                w: FontWeight.w600,
                                color: FdColors.ink)),
                        Text(
                            '${widget.tests[i].category} · Rs ${widget.tests[i].price}',
                            style: FdType.body(widget.ur,
                                size: 13,
                                color: FdColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: FdColors.redInk, size: 22),
                    onPressed: () {
                      final next =
                          List<LabTestPrice>.of(widget.tests)
                            ..removeAt(i);
                      widget.onChanged(next);
                    },
                  ),
                ],
              ),
            ),
          const Divider(color: FdColors.line),
          _Cap(ur: widget.ur, label: tr(ref, 'admin.addTest')),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            style: FdType.body(widget.ur,
                size: 15, color: FdColors.ink),
            decoration: InputDecoration(
              hintText: tr(ref, 'admin.testName'),
              hintStyle: FdType.body(widget.ur,
                  size: 15, color: FdColors.muted),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: FdSpec.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: FdSpec.inputBorder),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: StreamBuilder<List<String>>(
                  stream: ref
                      .read(repositoryProvider)
                      .watchTestCategories(),
                  builder: (context, snap) {
                    final cats =
                        snap.data ?? const <String>[];
                    return DropdownButtonFormField<String>(
                      initialValue: _category,
                      hint: Text(tr(ref, 'admin.category'),
                          style: FdType.body(widget.ur,
                              size: 15,
                              color: FdColors.muted)),
                      items: [
                        for (final c in cats)
                          DropdownMenuItem(
                              value: c, child: Text(c))
                      ],
                      onChanged: (v) =>
                          setState(() => _category = v),
                      style: FdType.body(widget.ur,
                          size: 15, color: FdColors.ink),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: FdSpec.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: FdSpec.inputBorder),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  style: FdType.body(widget.ur,
                      size: 15, color: FdColors.ink),
                  decoration: InputDecoration(
                    hintText: tr(ref, 'admin.price'),
                    hintStyle: FdType.body(widget.ur,
                        size: 15, color: FdColors.muted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: FdSpec.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: FdSpec.inputBorder),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FdButton(
            label: tr(ref, 'admin.addTest'),
            isUrdu: widget.ur,
            onTap: () {
              final t = _name.text.trim();
              final p = int.tryParse(_price.text.trim()) ?? 0;
              if (t.isEmpty) return;
              widget.onChanged([
                ...widget.tests,
                LabTestPrice(
                    test: t, category: _category ?? '', price: p)
              ]);
              _name.clear();
              _price.clear();
              setState(() => _category = null);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
