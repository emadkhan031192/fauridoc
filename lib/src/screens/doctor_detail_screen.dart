import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/repository.dart';
import '../l10n/strings.dart';
import '../models/doctor.dart';
import '../models/review.dart';
import '../providers/providers.dart';
import '../utils/actions.dart';
import '../utils/open_status.dart';
import '../widgets/rating_stars.dart';
import '../widgets/theme.dart';

/// Full profile of one doctor: header, live open status, info rows, clinic
/// photos, call/WhatsApp/map actions, reviews (read + write + admin delete),
/// and owner/admin photo management.
class DoctorDetailScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const DoctorDetailScreen({super.key, required this.doctorId});

  @override
  ConsumerState<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen> {
  Doctor? _doctor;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    try {
      final doctor = await repo.getDoctor(widget.doctorId);
      if (!mounted) return;
      setState(() {
        _doctor = doctor;
        _loading = false;
      });
      if (doctor != null) {
        unawaited(repo.recordProfileView(widget.doctorId));
      }
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
    final doctor = _doctor;
    return Scaffold(
      appBar: AppBar(title: Text(doctor?.name ?? '')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? _errorBody()
              : doctor == null
                  ? Center(child: Text(tr(ref, 'noResults')))
                  : _detailBody(doctor),
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

  Widget _detailBody(Doctor doctor) {
    final user = ref.watch(authProvider);
    final repo = ref.watch(repositoryProvider);
    final isAdmin = (user?.isAdmin ?? false) ||
        (repo.isDemo && ref.watch(demoAdminPreviewProvider));
    final canManagePhotos =
        user != null && (doctor.ownerUid == user.uid || isAdmin);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerCard(doctor),
          _infoCard(doctor),
          _photosCard(doctor),
          _actionsCard(doctor, canManagePhotos),
          _reviewsCard(isAdmin),
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

  Widget _headerCard(Doctor doctor) {
    final locale = ref.watch(localeProvider);
    final status = computeOpenStatus(doctor.hours, DateTime.now());
    final String statusText;
    if (status.transitionAt != null) {
      statusText = fill(
        tr(ref, status.isOpen ? 'statusOpen' : 'statusClosed'),
        {'time': formatTime12(status.transitionAt!)},
      );
    } else {
      statusText = tr(ref, status.isOpen ? 'open' : 'closed');
    }
    final leaveTill = doctor.leaveTill?.trim() ?? '';

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EntityAvatar(
                  photoUrl: doctor.photoUrl, name: doctor.name, radius: 40),
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
                          doctor.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (doctor.verified)
                          Pill(
                            label: tr(ref, 'verified'),
                            icon: Icons.verified,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specialtyLabel(locale, doctor.specialty),
                      style: const TextStyle(
                        color: FauridocTheme.tealDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(doctor.city,
                            style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RatingStars(
                      rating: doctor.rating,
                      reviewCount: doctor.reviewCount,
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
          if (leaveTill.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: FauridocTheme.starAmber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_busy,
                      size: 16, color: Colors.brown[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fill(tr(ref, 'onLeaveTill'), {'date': leaveTill}),
                      style: TextStyle(
                        color: Colors.brown[800],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- info rows ----------

  Widget _infoCard(Doctor doctor) {
    final rows = <Widget>[];
    void add(String label, String value, IconData icon) {
      if (value.trim().isEmpty) return;
      rows.add(_infoRow(label, value, icon));
    }

    add(tr(ref, 'qualification'), doctor.qualification, Icons.school);
    add(tr(ref, 'clinic'), doctor.clinicName, Icons.local_hospital);
    add(tr(ref, 'address'), doctor.address, Icons.location_on);
    add(tr(ref, 'languages'), doctor.languages.join(', '), Icons.translate);
    if (doctor.fee != null) {
      rows.add(_infoRow(
        tr(ref, 'fee'),
        fill(tr(ref, 'rs'), {'p': '${doctor.fee}'}),
        Icons.payments,
      ));
    }
    if (doctor.hasParking) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Pill(
            label: tr(ref, 'parking'),
            icon: Icons.local_parking,
            color: Colors.green,
          ),
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return _card(Column(children: rows));
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: FauridocTheme.tealDark),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child:
                Text(label, style: TextStyle(color: Colors.grey[700])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ---------- photos ----------

  Widget _photosCard(Doctor doctor) {
    final photos = <String>[
      if ((doctor.photoUrl ?? '').isNotEmpty) doctor.photoUrl!,
      ...doctor.clinicPhotos,
    ];
    if (photos.isEmpty) return const SizedBox.shrink();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'clinicPhotos'), style: _sectionTitle(context)),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnyPhoto(
                  photoUrl: photos[i],
                  width: 150,
                  height: 110,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- actions ----------

  Widget _actionsCard(Doctor doctor, bool canManagePhotos) {
    return _card(
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => callNumber(context, doctor.phone),
            icon: const Icon(Icons.call),
            label: Text(tr(ref, 'call')),
          ),
          FilledButton.tonalIcon(
            onPressed: () => openWhatsapp(
              context,
              ref,
              doctor.whatsapp,
              doctorId: doctor.id,
            ),
            icon: const Icon(Icons.chat),
            label: Text(tr(ref, 'whatsapp')),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                openDirections(context, doctor.lat, doctor.lng, doctor.name),
            icon: const Icon(Icons.map),
            label: Text(tr(ref, 'viewOnMap')),
          ),
          if (canManagePhotos)
            OutlinedButton.icon(
              onPressed: _addPhoto,
              icon: const Icon(Icons.add_a_photo),
              label: Text(tr(ref, 'addPhoto')),
            ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    final doctor = _doctor;
    if (doctor == null) return;
    final xfile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xfile == null || !mounted) return;
    try {
      final repo = ref.read(repositoryProvider);
      final url = await repo.uploadPhoto('doctor', doctor.id, xfile.path);
      final Doctor updated;
      if ((doctor.photoUrl ?? '').isEmpty) {
        updated = doctor.copyWith(photoUrl: url);
      } else {
        updated = doctor.copyWith(
          clinicPhotos: [...doctor.clinicPhotos, url].take(3).toList(),
        );
      }
      await repo.updateDoctor(updated);
      if (!mounted) return;
      setState(() => _doctor = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'error'))),
      );
    }
  }

  // ---------- reviews ----------

  Widget _reviewsCard(bool isAdmin) {
    final repo = ref.watch(repositoryProvider);
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tr(ref, 'reviews'), style: _sectionTitle(context)),
              const Spacer(),
              TextButton.icon(
                onPressed: _writeReview,
                icon: const Icon(Icons.rate_review),
                label: Text(tr(ref, 'writeReview')),
              ),
            ],
          ),
          StreamBuilder<List<Review>>(
            stream: repo.watchReviews(widget.doctorId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(child: Text(tr(ref, 'loading'))),
                );
              }
              final reviews = snap.data ?? [];
              if (reviews.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(tr(ref, 'noResults'),
                      style: TextStyle(color: Colors.grey[600])),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (_, _) => const Divider(height: 20),
                itemBuilder: (_, i) =>
                    _reviewTile(reviews[i], isAdmin),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _reviewTile(Review review, bool isAdmin) {
    final date =
        '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(review.userName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              RatingStars(rating: review.rating.toDouble(), size: 12),
              if (review.text.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(review.text),
              ],
              const SizedBox(height: 4),
              Text(date,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: FauridocTheme.emergencyRed),
            tooltip: tr(ref, 'delete'),
            onPressed: () => _deleteReview(review.id),
          ),
      ],
    );
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(tr(ref, 'confirmDelete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(ref, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              tr(ref, 'delete'),
              style: const TextStyle(color: FauridocTheme.emergencyRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(repositoryProvider)
        .deleteReview(widget.doctorId, reviewId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(ref, 'deleted'))),
    );
  }

  Future<void> _writeReview() async {
    final user = ref.read(authProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'loginToReview'))),
      );
      return;
    }
    final result = await showDialog<_ReviewDraft>(
      context: context,
      builder: (_) => const _ReviewDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(repositoryProvider).addReview(Review(
            id: '',
            doctorId: widget.doctorId,
            userId: user.uid,
            userName: user.name,
            rating: result.rating,
            text: result.text,
          ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'reviewSubmitted'))),
      );
    } on DuplicateReviewException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(ref, 'alreadyReviewed'))),
      );
    }
  }
}

/// Rating + text collected from the review dialog.
class _ReviewDraft {
  final int rating;
  final String text;

  const _ReviewDraft(this.rating, this.text);
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog();

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  int _rating = 5;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(ref, 'writeReview')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarInput(
            initial: 5,
            onChanged: (v) => setState(() => _rating = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: tr(ref, 'yourReview'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr(ref, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .pop(_ReviewDraft(_rating, _controller.text.trim())),
          child: Text(tr(ref, 'submitReview')),
        ),
      ],
    );
  }
}
