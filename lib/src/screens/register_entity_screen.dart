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

/// Which entity type this registration form is for.
enum EntityKind { doctor, lab, hospital }

/// Register a new doctor/lab/hospital, or edit an existing one
/// (edit mode when [doctor]/[lab]/[hospital] is given).
class RegisterEntityScreen extends ConsumerWidget {
  final EntityKind kind;
  final Doctor? doctor;
  final Lab? lab;
  final Hospital? hospital;

  const RegisterEntityScreen({
    super.key,
    required this.kind,
    this.doctor,
    this.lab,
    this.hospital,
  });

  bool get _isEdit => doctor != null || lab != null || hospital != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget form;
    switch (kind) {
      case EntityKind.doctor:
        form = _DoctorForm(doctor: doctor);
      case EntityKind.lab:
        form = _LabForm(lab: lab);
      case EntityKind.hospital:
        form = _HospitalForm(hospital: hospital);
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, _isEdit ? 'edit' : 'registerTitle'))),
      body: form,
    );
  }
}

/// Shared weekly-hours editor: 7 rows, one switch + two HH:MM fields each.
class HoursEditor extends ConsumerStatefulWidget {
  final Map<String, DayHours> initial;
  final ValueChanged<Map<String, DayHours>> onChanged;

  const HoursEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  ConsumerState<HoursEditor> createState() => _HoursEditorState();
}

class _HoursEditorState extends ConsumerState<HoursEditor> {
  late final Map<String, DayHours> _hours;
  final Map<String, TextEditingController> _open = {};
  final Map<String, TextEditingController> _close = {};

  @override
  void initState() {
    super.initState();
    _hours = {
      for (final k in weekdayKeys) k: widget.initial[k] ?? DayHours.closedDay(),
    };
    for (final k in weekdayKeys) {
      _open[k] = TextEditingController(text: _hours[k]!.open);
      _close[k] = TextEditingController(text: _hours[k]!.close);
    }
  }

  @override
  void dispose() {
    for (final c in [..._open.values, ..._close.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() =>
      widget.onChanged({for (final k in weekdayKeys) k: _hours[k]!});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(ref, 'workingHours'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          tr(ref, 'hoursHint'),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 6),
        for (final k in weekdayKeys) _dayRow(k),
      ],
    );
  }

  Widget _dayRow(String k) {
    final h = _hours[k]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(tr(ref, 'weekdays_short_$k')),
          ),
          Switch(
            value: !h.closed,
            onChanged: (v) {
              setState(() => _hours[k] = h.copyWith(closed: !v));
              _emit();
            },
          ),
          Expanded(
            child: TextField(
              controller: _open[k],
              enabled: !h.closed,
              decoration: const InputDecoration(
                hintText: 'HH:MM',
                isDense: true,
              ),
              onChanged: (v) {
                _hours[k] = _hours[k]!.copyWith(open: v);
                _emit();
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('–'),
          ),
          Expanded(
            child: TextField(
              controller: _close[k],
              enabled: !h.closed,
              decoration: const InputDecoration(
                hintText: 'HH:MM',
                isDense: true,
              ),
              onChanged: (v) {
                _hours[k] = _hours[k]!.copyWith(close: v);
                _emit();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doctor form
// ---------------------------------------------------------------------------

class _DoctorForm extends ConsumerStatefulWidget {
  final Doctor? doctor;

  const _DoctorForm({this.doctor});

  @override
  ConsumerState<_DoctorForm> createState() => _DoctorFormState();
}

class _DoctorFormState extends ConsumerState<_DoctorForm> {
  final _nameCtrl = TextEditingController();
  final _qualCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _langCtrl = TextEditingController();
  final _leaveCtrl = TextEditingController();
  String? _city;
  String? _specialty;
  bool _hasParking = false;
  late Map<String, DayHours> _hours;
  String? _photoPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    _nameCtrl.text = d?.name ?? '';
    _qualCtrl.text = d?.qualification ?? '';
    _clinicCtrl.text = d?.clinicName ?? '';
    _addrCtrl.text = d?.address ?? '';
    _phoneCtrl.text = d?.phone ?? '';
    _waCtrl.text = d?.whatsapp ?? '';
    _feeCtrl.text = d?.fee?.toString() ?? '';
    _langCtrl.text = d?.languages.join(', ') ?? '';
    _leaveCtrl.text = d?.leaveTill ?? '';
    _city = d?.city.isNotEmpty == true ? d!.city : null;
    _specialty = d?.specialty.isNotEmpty == true ? d!.specialty : null;
    _hasParking = d?.hasParking ?? false;
    _hours = d != null
        ? {for (final k in weekdayKeys) k: d.hours[k] ?? DayHours.closedDay()}
        : defaultHours();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qualCtrl.dispose();
    _clinicCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    _waCtrl.dispose();
    _feeCtrl.dispose();
    _langCtrl.dispose();
    _leaveCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _photoPath = x.path);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final city = _city ?? '';
    if (name.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'fillAllFields'))),
      );
      return;
    }
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'loginSubtitle'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final languages = _langCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final fee = int.tryParse(_feeCtrl.text.trim());
      final leave = _leaveCtrl.text.trim();
      final editing = widget.doctor;
      if (editing == null) {
        final id = await repo.registerDoctor(
          Doctor(
            id: '',
            name: name,
            specialty: _specialty ?? '',
            city: city,
            qualification: _qualCtrl.text.trim(),
            clinicName: _clinicCtrl.text.trim(),
            address: _addrCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            whatsapp: _waCtrl.text.trim(),
            hours: Map.of(_hours),
            languages: languages,
            leaveTill: leave.isEmpty ? null : leave,
            hasParking: _hasParking,
            fee: fee,
            ownerUid: user.uid,
          ),
        );
        if (_photoPath != null) {
          final url = await repo.uploadPhoto('doctor', id, _photoPath!);
          final saved = await repo.getDoctor(id);
          if (saved != null) {
            await repo.updateDoctor(saved.copyWith(photoUrl: url));
          }
        }
        if (user.isAdmin) await repo.approveDoctor(id, approve: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(ref, 'submittedPending'))),
        );
        Navigator.of(context).pop();
      } else {
        var updated = editing.copyWith(
          name: name,
          specialty: _specialty ?? '',
          city: city,
          qualification: _qualCtrl.text.trim(),
          clinicName: _clinicCtrl.text.trim(),
          address: _addrCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          whatsapp: _waCtrl.text.trim(),
          hours: Map.of(_hours),
          languages: languages,
          leaveTill: leave.isEmpty ? editing.leaveTill : leave,
          hasParking: _hasParking,
          fee: fee,
        );
        if (_photoPath != null) {
          final url = await repo.uploadPhoto('doctor', updated.id, _photoPath!);
          updated = updated.copyWith(photoUrl: url);
        }
        await repo.updateDoctor(updated);
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final locale = ref.watch(localeProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            AnyPhoto(
              photoUrl: _photoPath ?? widget.doctor?.photoUrl,
              width: 72,
              height: 72,
              fallback: Container(
                width: 72,
                height: 72,
                color: FauridocTheme.teal.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.person,
                  size: 36,
                  color: FauridocTheme.teal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(tr(ref, 'addPhoto')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'doctorName')),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<String>>(
          stream: repo.watchSpecialties(),
          builder: (context, snap) {
            final specialties = snap.data ?? const <String>[];
            return DropdownButtonFormField<String>(
              initialValue: specialties.contains(_specialty) ? _specialty : null,
              decoration: InputDecoration(labelText: tr(ref, 'specialty')),
              items: [
                for (final s in specialties)
                  DropdownMenuItem(
                    value: s,
                    child: Text(specialtyLabel(locale, s)),
                  ),
              ],
              onChanged: (v) => setState(() => _specialty = v),
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<String>>(
          stream: repo.watchCities(),
          builder: (context, snap) {
            final cities = snap.data ?? const <String>[];
            return DropdownButtonFormField<String>(
              initialValue: cities.contains(_city) ? _city : null,
              decoration: InputDecoration(labelText: tr(ref, 'city')),
              items: [
                for (final c in cities)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _city = v),
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _qualCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'qualification')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _clinicCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'clinicName')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addrCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'address')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'phone')),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _waCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'whatsapp')),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _feeCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'consultationFee')),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _langCtrl,
          decoration: InputDecoration(
            labelText: tr(ref, 'languages'),
            hintText: tr(ref, 'languagesHint'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _leaveCtrl,
          decoration: InputDecoration(
            labelText: tr(ref, 'leaveTillHint'),
          ),
        ),
        SwitchListTile(
          title: Text(tr(ref, 'hasParking')),
          value: _hasParking,
          onChanged: (v) => setState(() => _hasParking = v),
        ),
        const SizedBox(height: 8),
        HoursEditor(
          initial: _hours,
          onChanged: (h) => setState(() => _hours = h),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  tr(
                    ref,
                    widget.doctor == null ? 'submitForApproval' : 'save',
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Lab form
// ---------------------------------------------------------------------------

class _TestRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController();
  String? category;

  _TestRow({String? test, int? priceValue, this.category}) {
    name.text = test ?? '';
    if (priceValue != null) price.text = priceValue.toString();
  }

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _LabForm extends ConsumerStatefulWidget {
  final Lab? lab;

  const _LabForm({this.lab});

  @override
  ConsumerState<_LabForm> createState() => _LabFormState();
}

class _LabFormState extends ConsumerState<_LabForm> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _city;
  bool _hasParking = false;
  late Map<String, DayHours> _hours;
  final List<_TestRow> _rows = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final l = widget.lab;
    _nameCtrl.text = l?.name ?? '';
    _addrCtrl.text = l?.address ?? '';
    _phoneCtrl.text = l?.phone ?? '';
    _city = l?.city.isNotEmpty == true ? l!.city : null;
    _hasParking = l?.hasParking ?? false;
    _hours = l != null
        ? {for (final k in weekdayKeys) k: l.hours[k] ?? DayHours.closedDay()}
        : defaultHours();
    for (final t in l?.tests ?? const <LabTestPrice>[]) {
      _rows.add(
        _TestRow(test: t.test, priceValue: t.price, category: t.category),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final city = _city ?? '';
    if (name.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'fillAllFields'))),
      );
      return;
    }
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'loginSubtitle'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final tests = [
        for (final r in _rows)
          if (r.name.text.trim().isNotEmpty)
            LabTestPrice(
              test: r.name.text.trim(),
              category: r.category ?? '',
              price: int.tryParse(r.price.text.trim()) ?? 0,
            ),
      ];
      final editing = widget.lab;
      if (editing == null) {
        final id = await repo.registerLab(
          Lab(
            id: '',
            name: name,
            city: city,
            address: _addrCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            hours: Map.of(_hours),
            hasParking: _hasParking,
            tests: tests,
            ownerUid: user.uid,
          ),
        );
        if (user.isAdmin) await repo.approveLab(id, approve: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(ref, 'submittedPending'))),
        );
        Navigator.of(context).pop();
      } else {
        await repo.updateLab(
          editing.copyWith(
            name: name,
            city: city,
            address: _addrCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            hours: Map.of(_hours),
            hasParking: _hasParking,
            tests: tests,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'labName')),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<String>>(
          stream: repo.watchCities(),
          builder: (context, snap) {
            final cities = snap.data ?? const <String>[];
            return DropdownButtonFormField<String>(
              initialValue: cities.contains(_city) ? _city : null,
              decoration: InputDecoration(labelText: tr(ref, 'city')),
              items: [
                for (final c in cities)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _city = v),
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addrCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'address')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'phone')),
          keyboardType: TextInputType.phone,
        ),
        SwitchListTile(
          title: Text(tr(ref, 'hasParking')),
          value: _hasParking,
          onChanged: (v) => setState(() => _hasParking = v),
        ),
        const SizedBox(height: 8),
        HoursEditor(
          initial: _hours,
          onChanged: (h) => setState(() => _hours = h),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<String>>(
          stream: repo.watchTestCategories(),
          builder: (context, snap) {
            final categories = snap.data ?? const <String>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(ref, 'testsOffered'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < _rows.length; i++) _testRow(_rows[i], i, categories),
                TextButton.icon(
                  onPressed: () => setState(() => _rows.add(_TestRow())),
                  icon: const Icon(Icons.add),
                  label: Text(tr(ref, 'addTest')),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  tr(ref, widget.lab == null ? 'submitForApproval' : 'save'),
                ),
        ),
      ],
    );
  }

  Widget _testRow(_TestRow row, int index, List<String> categories) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: row.name,
              decoration: InputDecoration(
                labelText: tr(ref, 'testName'),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.price,
              decoration: InputDecoration(
                labelText: tr(ref, 'testPrice'),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: categories.contains(row.category) ? row.category : null,
              decoration: InputDecoration(
                labelText: tr(ref, 'testCategory'),
                isDense: true,
              ),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => row.category = v),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              color: FauridocTheme.emergencyRed,
            ),
            onPressed: () => setState(() {
              row.dispose();
              _rows.removeAt(index);
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hospital form
// ---------------------------------------------------------------------------

class _HospitalForm extends ConsumerStatefulWidget {
  final Hospital? hospital;

  const _HospitalForm({this.hospital});

  @override
  ConsumerState<_HospitalForm> createState() => _HospitalFormState();
}

class _HospitalFormState extends ConsumerState<_HospitalForm> {
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emgCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _visitingCtrl = TextEditingController();
  String? _city;
  bool _emergency247 = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final h = widget.hospital;
    _nameCtrl.text = h?.name ?? '';
    _addrCtrl.text = h?.address ?? '';
    _phoneCtrl.text = h?.phone ?? '';
    _emgCtrl.text = h?.emergencyPhone ?? '';
    _deptCtrl.text = h?.departments.join(', ') ?? '';
    _visitingCtrl.text = h?.visitingHours ?? '';
    _city = h?.city.isNotEmpty == true ? h!.city : null;
    _emergency247 = h?.emergency247 ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    _emgCtrl.dispose();
    _deptCtrl.dispose();
    _visitingCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final city = _city ?? '';
    if (name.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'fillAllFields'))),
      );
      return;
    }
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'loginSubtitle'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final departments = _deptCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final editing = widget.hospital;
      if (editing == null) {
        final id = await repo.registerHospital(
          Hospital(
            id: '',
            name: name,
            city: city,
            address: _addrCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            emergencyPhone: _emgCtrl.text.trim(),
            departments: departments,
            visitingHours: _visitingCtrl.text.trim(),
            emergency247: _emergency247,
            ownerUid: user.uid,
          ),
        );
        if (user.isAdmin) await repo.approveHospital(id, approve: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(ref, 'submittedPending'))),
        );
        Navigator.of(context).pop();
      } else {
        await repo.updateHospital(
          editing.copyWith(
            name: name,
            city: city,
            address: _addrCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            emergencyPhone: _emgCtrl.text.trim(),
            departments: departments,
            visitingHours: _visitingCtrl.text.trim(),
            emergency247: _emergency247,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'hospitalName')),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<String>>(
          stream: repo.watchCities(),
          builder: (context, snap) {
            final cities = snap.data ?? const <String>[];
            return DropdownButtonFormField<String>(
              initialValue: cities.contains(_city) ? _city : null,
              decoration: InputDecoration(labelText: tr(ref, 'city')),
              items: [
                for (final c in cities)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _city = v),
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addrCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'address')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'phone')),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emgCtrl,
          decoration: InputDecoration(labelText: tr(ref, 'emergencyPhone')),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _deptCtrl,
          decoration: InputDecoration(
            labelText: tr(ref, 'departments'),
            hintText: tr(ref, 'departmentsHint'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _visitingCtrl,
          decoration: InputDecoration(
            labelText: tr(ref, 'visitingHours'),
            hintText: tr(ref, 'visitingHoursHint'),
          ),
        ),
        SwitchListTile(
          title: Text(tr(ref, 'emergency247')),
          value: _emergency247,
          onChanged: (v) => setState(() => _emergency247 = v),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  tr(
                    ref,
                    widget.hospital == null ? 'submitForApproval' : 'save',
                  ),
                ),
        ),
      ],
    );
  }
}
