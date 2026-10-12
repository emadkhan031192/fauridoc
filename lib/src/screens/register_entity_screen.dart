import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/strings.dart';
import '../models/day_hours.dart';
import '../models/doctor.dart';
import '../models/hospital.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../widgets/theme.dart';
import 'auth_screen.dart';

/// Add a listing (page-14): Doctor / Lab / Hospital tabs, photo boxes,
/// caps-labeled fields, sticky "Submit for approval" footer.
/// New registrations only; editing lives in ManageEntityScreen.
class RegisterEntityScreen extends ConsumerStatefulWidget {
  /// 0 = Doctor, 1 = Lab, 2 = Hospital.
  final int initialTab;

  const RegisterEntityScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<RegisterEntityScreen> createState() =>
      _RegisterEntityScreenState();
}

class _RegisterEntityScreenState
    extends ConsumerState<RegisterEntityScreen> {
  late int _tab;
  bool _busy = false;

  // photos
  String? _photoPath; // profile / main photo
  final List<String> _clinicPhotos = [];

  // doctor fields
  final _dName = TextEditingController();
  final _dQual = TextEditingController();
  final _dClinic = TextEditingController();
  final _dPhone = TextEditingController();
  final _dFee = TextEditingController();
  final _dTimings = TextEditingController();
  String? _dSpecialty;
  String? _dCity;

  // lab fields
  final _lName = TextEditingController();
  final _lAddr = TextEditingController();
  final _lPhone = TextEditingController();
  final _lHours = TextEditingController();
  String? _lCity;

  // hospital fields
  final _hName = TextEditingController();
  final _hAddr = TextEditingController();
  final _hPhone = TextEditingController();
  final _hEmergency = TextEditingController();
  String? _hCity;
  bool _hEmergency247 = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
  }

  @override
  void dispose() {
    _dName.dispose();
    _dQual.dispose();
    _dClinic.dispose();
    _dPhone.dispose();
    _dFee.dispose();
    _dTimings.dispose();
    _lName.dispose();
    _lAddr.dispose();
    _lPhone.dispose();
    _lHours.dispose();
    _hName.dispose();
    _hAddr.dispose();
    _hPhone.dispose();
    _hEmergency.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickPhoto({required bool main}) async {
    final x =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() {
      if (main) {
        _photoPath = x.path;
      } else if (_clinicPhotos.length < 3) {
        _clinicPhotos.add(x.path);
      }
    });
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider);
    if (user == null) {
      _snack(tr(ref, 'add.signInRequired'));
      return;
    }
    final repo = ref.read(repositoryProvider);
    setState(() => _busy = true);
    try {
      if (_tab == 0) {
        final name = _dName.text.trim();
        final city = _dCity ?? '';
        if (name.isEmpty || city.isEmpty) {
          _snack(tr(ref, 'add.fillRequired'));
          return;
        }
        final id = await repo.registerDoctor(Doctor(
          id: '',
          name: name,
          specialty: _dSpecialty ?? '',
          city: city,
          qualification: _dQual.text.trim(),
          clinicName: _dClinic.text.trim(),
          phone: _dPhone.text.trim(),
          fee: int.tryParse(_dFee.text.trim()),
          hours: defaultHours(),
          hoursText: _dTimings.text.trim(),
          photoUrl: _photoPath,
          clinicPhotos: List.of(_clinicPhotos),
          ownerUid: user.uid,
          createdAt: DateTime.now(),
        ));
        if (_photoPath != null) {
          final url = await repo.uploadPhoto('doctor', id, _photoPath!);
          final saved = await repo.getDoctor(id);
          if (saved != null) {
            await repo.updateDoctor(saved.copyWith(photoUrl: url));
          }
        }
      } else if (_tab == 1) {
        final name = _lName.text.trim();
        final city = _lCity ?? '';
        if (name.isEmpty || city.isEmpty) {
          _snack(tr(ref, 'add.fillRequired'));
          return;
        }
        final id = await repo.registerLab(Lab(
          id: '',
          name: name,
          city: city,
          address: _lAddr.text.trim(),
          phone: _lPhone.text.trim(),
          hours: defaultHours(),
          hoursText: _lHours.text.trim(),
          photoUrl: _photoPath,
          ownerUid: user.uid,
          createdAt: DateTime.now(),
        ));
        if (_photoPath != null) {
          final url = await repo.uploadPhoto('lab', id, _photoPath!);
          final saved = await repo.getLab(id);
          if (saved != null) {
            await repo.updateLab(saved.copyWith(photoUrl: url));
          }
        }
      } else {
        final name = _hName.text.trim();
        final city = _hCity ?? '';
        if (name.isEmpty || city.isEmpty) {
          _snack(tr(ref, 'add.fillRequired'));
          return;
        }
        final id = await repo.registerHospital(Hospital(
          id: '',
          name: name,
          city: city,
          address: _hAddr.text.trim(),
          phone: _hPhone.text.trim(),
          emergencyPhone: _hEmergency.text.trim(),
          emergency247: _hEmergency247,
          photoUrl: _photoPath,
          ownerUid: user.uid,
          createdAt: DateTime.now(),
        ));
        if (_photoPath != null) {
          final url =
              await repo.uploadPhoto('hospital', id, _photoPath!);
          final saved = await repo.getHospital(id);
          if (saved != null) {
            await repo.updateHospital(saved.copyWith(photoUrl: url));
          }
        }
      }
      if (!mounted) return;
      _snack(tr(ref, 'add.submitted'));
      Navigator.of(context).pop();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ur = fdIsUrdu(ref.watch(localeProvider));
    final user = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
          title:
              Text(tr(ref, 'add.title'), style: FdType.title(ur, size: 22))),
      body: user == null
          ? _SignInRequired(ur: ur)
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        FdDim.page, 8, FdDim.page, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TypeTabs(
                            ur: ur,
                            tab: _tab,
                            onTap: (i) => setState(() => _tab = i)),
                        const SizedBox(height: 22),
                        _Caps(tr(ref, 'add.photos'), ur),
                        const SizedBox(height: 10),
                        _PhotoRow(
                          ur: ur,
                          mainPath: _photoPath,
                          extra: _clinicPhotos,
                          onMain: () => _pickPhoto(main: true),
                          onExtra: () => _pickPhoto(main: false),
                        ),
                        const SizedBox(height: 22),
                        if (_tab == 0)
                          _DoctorFields(
                              ur: ur,
                              name: _dName,
                              qual: _dQual,
                              clinic: _dClinic,
                              phone: _dPhone,
                              fee: _dFee,
                              timings: _dTimings,
                              specialty: _dSpecialty,
                              city: _dCity,
                              onSpecialty: (v) =>
                                  setState(() => _dSpecialty = v),
                              onCity: (v) =>
                                  setState(() => _dCity = v)),
                        if (_tab == 1)
                          _LabFields(
                              ur: ur,
                              name: _lName,
                              addr: _lAddr,
                              phone: _lPhone,
                              hours: _lHours,
                              city: _lCity,
                              onCity: (v) =>
                                  setState(() => _lCity = v)),
                        if (_tab == 2)
                          _HospitalFields(
                            ur: ur,
                            name: _hName,
                            addr: _hAddr,
                            phone: _hPhone,
                            emergency: _hEmergency,
                            city: _hCity,
                            emergency247: _hEmergency247,
                            onCity: (v) =>
                                setState(() => _hCity = v),
                            onEmergency247: (v) =>
                                setState(() => _hEmergency247 = v),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: FdColors.line)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                      FdDim.page,
                      14,
                      FdDim.page,
                      14 + MediaQuery.of(context).padding.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.access_time,
                              color: FdColors.amberInk, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(tr(ref, 'add.note'),
                                style: FdType.body(ur,
                                    size: 13.5,
                                    color: FdColors.inkSoft)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FdButton(
                        label: tr(ref, 'add.submit'),
                        isUrdu: ur,
                        onTap: _busy ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Login gate for the registration form.
class _SignInRequired extends StatelessWidget {
  final bool ur;
  const _SignInRequired({required this.ur});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(ref, 'add.signInRequired'),
                  style: FdType.body(ur, size: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FdButton(
                label: tr(ref, 'prof.signIn'),
                isUrdu: ur,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AuthScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Caps extends StatelessWidget {
  final String label;
  final bool ur;
  const _Caps(this.label, this.ur);

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
        style: FdType.label(ur, size: 13, w: FontWeight.w700));
  }
}

/// Doctor | Lab | Hospital segmented tabs on a mint track.
class _TypeTabs extends StatelessWidget {
  final bool ur;
  final int tab;
  final ValueChanged<int> onTap;

  const _TypeTabs(
      {required this.ur, required this.tab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final labels = [
          tr(ref, 'add.doctor'),
          tr(ref, 'add.lab'),
          tr(ref, 'add.hospital'),
        ];
        return Container(
          decoration: BoxDecoration(
            color: FdColors.mint,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tab == i
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: tab == i
                            ? [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        labels[i],
                        style: FdType.body(
                          ur,
                          size: 16,
                          w: FontWeight.w700,
                          color: tab == i
                              ? FdColors.primary
                              : FdColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Photo boxes: teal-dashed main + 3 grey-dashed extras.
class _PhotoRow extends StatelessWidget {
  final bool ur;
  final String? mainPath;
  final List<String> extra;
  final VoidCallback onMain;
  final VoidCallback onExtra;

  const _PhotoRow({
    required this.ur,
    required this.mainPath,
    required this.extra,
    required this.onMain,
    required this.onExtra,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Row(
        children: [
          Expanded(
            child: _DashedBox(
              color: FdColors.primary,
              onTap: onMain,
              child: mainPath == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_outlined,
                            color: FdColors.primary, size: 30),
                        const SizedBox(height: 6),
                        Text(tr(ref, 'add.yourPhoto'),
                            style: FdType.body(ur,
                                size: 14,
                                w: FontWeight.w700,
                                color: FdColors.primary),
                            textAlign: TextAlign.center),
                      ],
                    )
                  : SizedBox.expand(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _PickedImage(path: mainPath!),
                      ),
                    ),
            ),
          ),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _DashedBox(
                color: FdColors.muted,
                onTap: onExtra,
                child: i < extra.length
                    ? SizedBox.expand(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _PickedImage(path: extra[i]),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add,
                              color: FdColors.muted, size: 30),
                          const SizedBox(height: 4),
                          Text(
                              fill(tr(ref, 'add.photo'),
                                  {'n': '${i + 1}'}),
                              style: FdType.body(ur,
                                  size: 14, color: FdColors.muted),
                              textAlign: TextAlign.center),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedBox extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback onTap;

  const _DashedBox(
      {required this.color, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.92,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedPainter(color),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _PickedImage extends StatelessWidget {
  final String path;
  const _PickedImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image_outlined, color: FdColors.muted),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  _DashedPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    const dash = 7.0;
    const gap = 5.0;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(18));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    final total = metrics.length;
    var dist = 0.0;
    final dashed = Path();
    while (dist < total) {
      dashed.addPath(
          metrics.extractPath(dist, (dist + dash).clamp(0, total)),
          Offset.zero);
      dist += dash + gap;
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) =>
      old.color != color;
}

/// Caps-labeled text field.
class _LabeledField extends StatelessWidget {
  final bool ur;
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final int maxLines;

  const _LabeledField({
    required this.ur,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caps(label, ur),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: FdType.body(ur, size: 16, color: FdColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                FdType.body(ur, size: 16, color: FdColors.muted),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 17),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(FdDim.fieldRadius),
              borderSide: const BorderSide(color: FdColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(FdDim.fieldRadius),
              borderSide: const BorderSide(color: FdColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(FdDim.fieldRadius),
              borderSide:
                  const BorderSide(color: FdColors.primary, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// Caps-labeled dropdown (cities / specialties).
class _LabeledDropdown extends StatelessWidget {
  final bool ur;
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _LabeledDropdown({
    required this.ur,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Caps(label, ur),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: [
            for (final it in items)
              DropdownMenuItem(value: it, child: Text(it))
          ],
          onChanged: onChanged,
          style: FdType.body(ur, size: 16, color: FdColors.ink),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: FdColors.ink, size: 26),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                FdType.body(ur, size: 16, color: FdColors.muted),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 17),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(FdDim.fieldRadius),
              borderSide: const BorderSide(color: FdColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(FdDim.fieldRadius),
              borderSide: const BorderSide(color: FdColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(FdDim.fieldRadius),
              borderSide:
                  const BorderSide(color: FdColors.primary, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _CityDropdown extends ConsumerWidget {
  final bool ur;
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _CityDropdown({
    required this.ur,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<String>>(
      stream: ref.read(repositoryProvider).watchCities(),
      builder: (context, snap) => _LabeledDropdown(
        ur: ur,
        label: label,
        hint: label,
        value: value,
        items: snap.data ?? const [],
        onChanged: onChanged,
      ),
    );
  }
}

class _SpecialtyDropdown extends ConsumerWidget {
  final bool ur;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _SpecialtyDropdown({
    required this.ur,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<String>>(
      stream: ref.read(repositoryProvider).watchSpecialties(),
      builder: (context, snap) => _LabeledDropdown(
        ur: ur,
        label: tr(ref, 'add.specialization'),
        hint: tr(ref, 'add.chooseSpecialty'),
        value: value,
        items: snap.data ?? const [],
        onChanged: onChanged,
      ),
    );
  }
}

class _DoctorFields extends StatelessWidget {
  final bool ur;
  final TextEditingController name;
  final TextEditingController qual;
  final TextEditingController clinic;
  final TextEditingController phone;
  final TextEditingController fee;
  final TextEditingController timings;
  final String? specialty;
  final String? city;
  final ValueChanged<String?> onSpecialty;
  final ValueChanged<String?> onCity;

  const _DoctorFields({
    required this.ur,
    required this.name,
    required this.qual,
    required this.clinic,
    required this.phone,
    required this.fee,
    required this.timings,
    required this.specialty,
    required this.city,
    required this.onSpecialty,
    required this.onCity,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.doctorName'),
              controller: name,
              hint: tr(ref, 'add.doctorNameHint')),
          _SpecialtyDropdown(
              ur: ur, value: specialty, onChanged: onSpecialty),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.qualification'),
              controller: qual,
              hint: tr(ref, 'add.qualificationHint')),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.clinicName'),
              controller: clinic,
              hint: tr(ref, 'add.clinicNameHint')),
          _CityDropdown(
              ur: ur,
              label: tr(ref, 'add.city'),
              value: city,
              onChanged: onCity),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.phone'),
              controller: phone,
              hint: tr(ref, 'add.phoneHint'),
              keyboardType: TextInputType.phone),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.fee'),
              controller: fee,
              hint: tr(ref, 'add.feeHint'),
              keyboardType: TextInputType.number),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.timings'),
              controller: timings,
              hint: tr(ref, 'add.timingsHint')),
        ],
      ),
    );
  }
}

class _LabFields extends StatelessWidget {
  final bool ur;
  final TextEditingController name;
  final TextEditingController addr;
  final TextEditingController phone;
  final TextEditingController hours;
  final String? city;
  final ValueChanged<String?> onCity;

  const _LabFields({
    required this.ur,
    required this.name,
    required this.addr,
    required this.phone,
    required this.hours,
    required this.city,
    required this.onCity,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.labName'),
              controller: name,
              hint: tr(ref, 'add.labName')),
          _CityDropdown(
              ur: ur,
              label: tr(ref, 'add.city'),
              value: city,
              onChanged: onCity),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.address'),
              controller: addr,
              hint: tr(ref, 'add.addressHint'),
              maxLines: 2),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.phone'),
              controller: phone,
              hint: tr(ref, 'add.phoneHint'),
              keyboardType: TextInputType.phone),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.hours'),
              controller: hours,
              hint: tr(ref, 'add.hoursHint')),
        ],
      ),
    );
  }
}

class _HospitalFields extends StatelessWidget {
  final bool ur;
  final TextEditingController name;
  final TextEditingController addr;
  final TextEditingController phone;
  final TextEditingController emergency;
  final String? city;
  final bool emergency247;
  final ValueChanged<String?> onCity;
  final ValueChanged<bool> onEmergency247;

  const _HospitalFields({
    required this.ur,
    required this.name,
    required this.addr,
    required this.phone,
    required this.emergency,
    required this.city,
    required this.emergency247,
    required this.onCity,
    required this.onEmergency247,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.hospitalName'),
              controller: name,
              hint: tr(ref, 'add.hospitalName')),
          _CityDropdown(
              ur: ur,
              label: tr(ref, 'add.city'),
              value: city,
              onChanged: onCity),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.address'),
              controller: addr,
              hint: tr(ref, 'add.addressHint'),
              maxLines: 2),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.phone'),
              controller: phone,
              hint: tr(ref, 'add.phoneHint'),
              keyboardType: TextInputType.phone),
          _LabeledField(
              ur: ur,
              label: tr(ref, 'add.emergencyNumber'),
              controller: emergency,
              hint: tr(ref, 'add.phoneHint'),
              keyboardType: TextInputType.phone),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(FdDim.fieldRadius),
              border: Border.all(color: FdColors.line),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(tr(ref, 'add.emergency247'),
                      style: FdType.body(ur,
                          size: 16,
                          w: FontWeight.w600,
                          color: FdColors.ink)),
                ),
                Switch(
                  value: emergency247,
                  activeThumbColor: FdColors.primary,
                  onChanged: onEmergency247,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
