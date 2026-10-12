import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../models/day_hours.dart';
import '../models/lab.dart';
import '../providers/providers.dart';
import '../utils/actions.dart';
import '../utils/open_status.dart';
import '../widgets/rating_stars.dart';
import '../widgets/theme.dart';

/// Full profile of one lab: header, live open status, contact, searchable
/// test list with prices, working hours, call/map actions.
class LabDetailScreen extends ConsumerStatefulWidget {
  final String labId;

  const LabDetailScreen({super.key, required this.labId});

  @override
  ConsumerState<LabDetailScreen> createState() => _LabDetailScreenState();
}

class _LabDetailScreenState extends ConsumerState<LabDetailScreen> {
  Lab? _lab;
  bool _loading = true;
  bool _failed = false;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final lab = await ref.read(repositoryProvider).getLab(widget.labId);
      if (!mounted) return;
      setState(() {
        _lab = lab;
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
    final lab = _lab;
    return Scaffold(
      appBar: AppBar(title: Text(lab?.name ?? '')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? _errorBody()
              : lab == null
                  ? Center(child: Text(tr(ref, 'noResults')))
                  : _detailBody(lab),
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

  Widget _detailBody(Lab lab) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerCard(lab),
          _actionsCard(lab),
          _testsCard(lab),
          _hoursCard(lab),
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

  Widget _headerCard(Lab lab) {
    final status = computeOpenStatus(lab.hours, DateTime.now());
    final String statusText;
    if (status.transitionAt != null) {
      statusText = fill(
        tr(ref, status.isOpen ? 'statusOpen' : 'statusClosed'),
        {'time': formatTime12(status.transitionAt!)},
      );
    } else {
      statusText = tr(ref, status.isOpen ? 'open' : 'closed');
    }

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntityAvatar(
                  photoUrl: lab.photoUrl, name: lab.name, radius: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          lab.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (lab.verified)
                          Pill(
                            label: tr(ref, 'verified'),
                            icon: Icons.verified,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(lab.city,
                            style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RatingStars(
                      rating: lab.rating,
                      reviewCount: lab.reviewCount,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: status.isOpen ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: status.isOpen ? Colors.green[800] : Colors.red[800],
                  ),
                ),
              ),
            ],
          ),
          if (lab.address.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow(tr(ref, 'address'), lab.address, Icons.location_on),
          ],
          if (lab.phone.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            _infoRow(tr(ref, 'phone'), lab.phone, Icons.phone),
          ],
          if (lab.hasParking) ...[
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

  // ---------- actions ----------

  Widget _actionsCard(Lab lab) {
    return _card(
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => callNumber(context, lab.phone),
            icon: const Icon(Icons.call),
            label: Text(tr(ref, 'call')),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                openDirections(context, lab.lat, lab.lng, lab.name),
            icon: const Icon(Icons.map),
            label: Text(tr(ref, 'viewOnMap')),
          ),
        ],
      ),
    );
  }

  // ---------- tests ----------

  Widget _testsCard(Lab lab) {
    final filtered = lab.tests
        .where((t) => t.test.toLowerCase().contains(_query))
        .toList();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'testsOffered'), style: _sectionTitle(context)),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: tr(ref, 'searchHintLabs'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(tr(ref, 'noResults'),
                  style: TextStyle(color: Colors.grey[600])),
            )
          else
            for (final t in filtered)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.test,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(t.category,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(
                      fill(tr(ref, 'rs'), {'p': '${t.price}'}),
                      style: const TextStyle(
                        color: FauridocTheme.tealDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ---------- working hours ----------

  Widget _hoursCard(Lab lab) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'workingHours'), style: _sectionTitle(context)),
          const SizedBox(height: 8),
          for (final k in weekdayKeys) _hoursRow(k, lab.hours[k]),
        ],
      ),
    );
  }

  Widget _hoursRow(String key, DayHours? dh) {
    final closed = dh == null || dh.closed;
    final text = closed
        ? tr(ref, 'closed')
        : '${formatTime12(dh.open)} – ${formatTime12(dh.close)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(ref, 'weekdays_short_$key'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            text,
            style: TextStyle(
                color: closed ? Colors.grey[600] : FauridocTheme.ink),
          ),
        ],
      ),
    );
  }
}
