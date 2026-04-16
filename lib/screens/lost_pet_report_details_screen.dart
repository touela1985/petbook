import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/lost_pet_message_repository.dart';
import '../data/lost_pet_report_repository.dart';
import '../data/lost_sighting_repository.dart';
import '../models/lost_pet_report.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_image_widget.dart';
import 'lost_pet_messages_screen.dart';
import 'send_lost_pet_message_screen.dart';

class LostPetReportDetailsScreen extends StatefulWidget {
  final LostPetReport report;

  const LostPetReportDetailsScreen({
    super.key,
    required this.report,
  });

  @override
  State<LostPetReportDetailsScreen> createState() =>
      _LostPetReportDetailsScreenState();
}

class _LostPetReportDetailsScreenState
    extends State<LostPetReportDetailsScreen> {
  final LostPetMessageRepository _messageRepository =
      LostPetMessageRepository();
  final LostPetReportRepository _reportRepository = LostPetReportRepository();
  final LostSightingRepository _sightingRepository = LostSightingRepository();

  late LostPetReport _report;

  int _messageCount = 0;
  bool _isMarkingResolved = false;
  List<LostPetSighting> _sightings = [];

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _loadMessageStats();
    _loadSightings();
  }

  Future<void> _loadSightings() async {
    try {
      final remote =
          await _sightingRepository.getSightingsForReport(_report.id);
      // Συγχώνευση με embedded sightings (παλιά δεδομένα) — dedup by id.
      final Map<String, LostPetSighting> seen = {
        for (final s in _report.sightings) s.id: s,
        for (final s in remote) s.id: s,
      };
      final merged = seen.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _sightings = merged;
      });
    } catch (_) {
      // Fallback: χρήση embedded sightings αν το Firestore αποτύχει.
      if (!mounted) return;
      setState(() {
        _sightings = [..._report.sightings]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    }
  }

  Future<void> _loadMessageStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final messages =
        await _messageRepository.getMessagesForReport(_report.id, uid);
    if (!mounted) return;
    setState(() {
      _messageCount = messages.length;
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatDateTime(DateTime date) {
    final formattedDate = _formatDate(date);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$formattedDate • $hour:$minute';
  }

  String _formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  bool get _hasCoordinates =>
      _report.latitude != null && _report.longitude != null;

  bool get _hasPhoto => hasAnyImage(
        photoUrl: _report.photoUrl,
        photoPath: _report.photoPath,
      );

  bool get _hasPhone => _report.contactPhone.trim().isNotEmpty;

  String get _displayPetName => _report.petName.trim().isEmpty
      ? (_isEl ? 'Χαμένο ζώο' : 'Lost pet')
      : _report.petName.trim();

  String get _headerSubtitle {
    if (_report.type.trim().isNotEmpty) return _report.type.trim();
    return _isEl ? 'Αναφορά απώλειας' : 'Lost pet alert';
  }

  List<LostPetSighting> get _sortedSightings => _sightings;

  String get _messageSubtitle {
    if (_messageCount == 0) {
      return _isEl ? 'Δεν υπάρχουν μηνύματα' : 'No messages yet';
    }
    if (_isEl) {
      return _messageCount == 1 ? '1 μήνυμα' : '$_messageCount μηνύματα';
    }
    return '$_messageCount message${_messageCount == 1 ? '' : 's'}';
  }

  Widget _buildReportImage({
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
  }) {
    return PetImageWidget(
      photoUrl: _report.photoUrl,
      photoPath: _report.photoPath,
      height: height,
      width: width,
      fit: fit,
      placeholder: Container(
        height: height ?? 268,
        width: width ?? double.infinity,
        color: AppTheme.surface,
        child: const Center(
          child: Icon(
            Icons.pets,
            size: 58,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    return Container(
      height: 276,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.025),
            Colors.transparent,
          ],
        ),
      ),
      child: !_hasPhoto
          ? const Center(
              child: Icon(
                Icons.pets,
                size: 64,
                color: AppTheme.textSecondary,
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: const Color(0xFFF4F1EA),
                  child: SizedBox.expand(
                    child: _buildReportImage(
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _openFullImage(BuildContext context) {
    if (!_hasPhoto) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: _buildReportImage(
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMapScreen(BuildContext context) {
    if (!_hasCoordinates) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LostReportMapScreen(
          isEl: _isEl,
          petName: _displayPetName,
          latitude: _report.latitude!,
          longitude: _report.longitude!,
        ),
      ),
    );
  }

  void _openSightingMapScreen(LostPetSighting sighting) {
    if (sighting.latitude == null || sighting.longitude == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LostReportMapScreen(
          isEl: _isEl,
          petName: _isEl ? 'Θέαση' : 'Sighting',
          latitude: sighting.latitude!,
          longitude: sighting.longitude!,
        ),
      ),
    );
  }

  Future<void> _callOwner() async {
    final phone = _report.contactPhone.trim();
    if (phone.isEmpty) return;

    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Future<void> _sendMessage(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SendLostPetMessageScreen(report: _report),
      ),
    );

    if (result == true) {
      await _loadMessageStats();
    }
  }

  Future<void> _openMessages(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LostPetMessagesScreen(report: _report),
      ),
    );

    await _loadMessageStats();
  }

  Future<void> _shareReport() async {
    final contact = _hasPhone
        ? _report.contactPhone.trim()
        : (_isEl ? 'Δεν υπάρχει τηλέφωνο' : 'No phone provided');

    final text = _isEl
        ? '''
Ειδοποίηση απώλειας
Ζώο: $_displayPetName
Τοποθεσία: ${_report.lastSeenLocation}
Ημερομηνία: ${_formatDate(_report.lastSeenDate)}
Επικοινωνία: $contact
Κοινοποιήθηκε μέσω Petbook
'''
        : '''
Lost pet alert
Pet: $_displayPetName
Location: ${_report.lastSeenLocation}
Date: ${_formatDate(_report.lastSeenDate)}
Contact: $contact
Shared via Petbook
''';

    await Share.share(
      text,
      subject: _isEl ? 'Ειδοποίηση απώλειας – Petbook' : 'Lost pet alert – Petbook',
    );
  }

  Future<void> _deleteSighting(LostPetSighting sighting) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_isEl ? 'Διαγραφή θέασης' : 'Delete sighting'),
          content: Text(
            _isEl
                ? 'Θέλεις σίγουρα να διαγράψεις αυτή τη θέαση;'
                : 'Are you sure you want to delete this sighting?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_isEl ? 'Ακύρωση' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(_isEl ? 'Διαγραφή' : 'Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    // Διαγραφή από το νέο collection.
    try {
      await _sightingRepository.deleteSighting(sighting.id);
    } catch (_) {}

    // Διαγραφή και από embedded (για backward compat με παλιά δεδομένα).
    final updatedEmbedded =
        _report.sightings.where((s) => s.id != sighting.id).toList();
    if (updatedEmbedded.length != _report.sightings.length) {
      final updatedReport = LostPetReport(
        id: _report.id,
        petName: _report.petName,
        type: _report.type,
        lastSeenLocation: _report.lastSeenLocation,
        lastSeenDate: _report.lastSeenDate,
        notes: _report.notes,
        contactPhone: _report.contactPhone,
        isResolved: _report.isResolved,
        photoPath: _report.photoPath,
        photoUrl: _report.photoUrl,
        latitude: _report.latitude,
        longitude: _report.longitude,
        createdAt: _report.createdAt,
        sightings: updatedEmbedded,
      );
      await _reportRepository.updateReport(updatedReport);
      if (!mounted) return;
      _report = updatedReport;
    }

    if (!mounted) return;

    setState(() {
      _sightings = _sightings.where((s) => s.id != sighting.id).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEl ? 'Η θέαση διαγράφηκε.' : 'Sighting deleted.',
        ),
      ),
    );
  }

  Future<void> _markAsFound() async {
    if (_report.isResolved || _isMarkingResolved) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_isEl ? 'Σήμανση ως βρέθηκε' : 'Mark as found'),
          content: Text(
            _isEl
                ? 'Αυτό θα κλείσει την ειδοποίηση και θα τη βγάλει από τις ενεργές κοντινές ειδοποιήσεις.'
                : 'This will close the lost alert and remove it from active nearby alerts.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_isEl ? 'Ακύρωση' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_isEl ? 'Σήμανση ως βρέθηκε' : 'Mark as Found'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isMarkingResolved = true;
    });

    final updatedReport = LostPetReport(
      id: _report.id,
      petName: _report.petName,
      type: _report.type,
      lastSeenLocation: _report.lastSeenLocation,
      lastSeenDate: _report.lastSeenDate,
      notes: _report.notes,
      contactPhone: _report.contactPhone,
      isResolved: true,
      photoPath: _report.photoPath,
      photoUrl: _report.photoUrl,
      latitude: _report.latitude,
      longitude: _report.longitude,
      createdAt: _report.createdAt,
      sightings: _report.sightings,
    );

    await _reportRepository.updateReport(updatedReport);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isResolved = _report.isResolved;
    final isEl = _isEl;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && currentUser.uid == _report.userId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        elevation: 0,
        title: Text(isEl ? 'Χαμένο ζώο' : 'Lost Pet Alert'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _hasPhoto ? () => _openFullImage(context) : null,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                    child: _buildHeroImage(),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: isResolved
                        ? _ResolvedStatusBadge(isEl: isEl)
                        : _LostStatusBadge(isEl: isEl),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayPetName,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      height: 1.06,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _headerSubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary.withOpacity(0.82),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _MainCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          iconColor: AppTheme.lostFound,
                          child: Text(
                            _report.lastSeenLocation.trim().isEmpty
                                ? (isEl
                                    ? 'Δεν υπάρχει τοποθεσία'
                                    : 'No location added')
                                : _report.lastSeenLocation,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (_hasCoordinates) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openMapScreen(context),
                              icon: const Icon(Icons.map_outlined),
                              label: Text(
                                isEl ? 'Άνοιγμα χάρτη' : 'Open location on map',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryTeal,
                                backgroundColor:
                                    AppTheme.primaryTeal.withOpacity(0.05),
                                side: BorderSide(
                                  color: AppTheme.primaryTeal.withOpacity(0.18),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          iconColor: AppTheme.textSecondary,
                          child: Text(
                            _formatDate(_report.lastSeenDate),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.textSecondary.withOpacity(0.88),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_report.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _SectionTitle('Notes', 'Σημειώσεις'),
                    const SizedBox(height: 8),
                    _SecondaryCard(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _report.notes.trim(),
                        style: const TextStyle(
                          height: 1.45,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  if (_sortedSightings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.remove_red_eye_outlined,
                          size: 20,
                          color: AppTheme.primaryTeal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEl ? 'Θεάσεις' : 'Sightings',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppTheme.primaryTeal.withOpacity(0.18),
                            ),
                          ),
                          child: Text(
                            '${_sortedSightings.length}',
                            style: const TextStyle(
                              color: AppTheme.primaryTeal,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._sortedSightings.map((sighting) {
                      final hasSightingCoordinates =
                          sighting.latitude != null &&
                              sighting.longitude != null;

                      final locationLabel = hasSightingCoordinates
                          ? _formatCoordinates(
                              sighting.latitude!,
                              sighting.longitude!,
                            )
                          : sighting.location.trim().isNotEmpty
                              ? sighting.location.trim()
                              : null;

                      return _SightingEntryCard(
                        isEl: isEl,
                        sighting: sighting,
                        formattedDateTime: _formatDateTime(sighting.createdAt),
                        locationLabel: locationLabel,
                        onOpenMap: hasSightingCoordinates
                            ? () => _openSightingMapScreen(sighting)
                            : null,
                        onDelete: isOwner ? () => _deleteSighting(sighting) : null,
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
                  _MainCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mail_outline_rounded,
                          color: AppTheme.primaryTeal,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEl ? 'Μηνύματα' : 'Messages',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _messageSubtitle,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner)
                          TextButton(
                            onPressed: () => _openMessages(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(isEl ? 'Προβολή' : 'View'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isOwner && !isResolved) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isMarkingResolved ? null : _markAsFound,
                        icon: _isMarkingResolved
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          _isMarkingResolved
                              ? (isEl
                                  ? 'Κλείσιμο ειδοποίησης...'
                                  : 'Closing alert...')
                              : (isEl ? 'Σήμανση ως βρέθηκε' : 'Mark as Found'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shadowColor: Colors.black.withOpacity(0.24),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    isEl ? 'Επικοινωνία' : 'Contact owner',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_hasPhone) ...[
                    Text(
                      _report.contactPhone.trim(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      if (_hasPhone)
                        Expanded(
                          child: _DetailsActionButton(
                            label: isEl ? 'Κλήση' : 'Call',
                            icon: Icons.call_rounded,
                            onTap: _callOwner,
                            color: Colors.green,
                          ),
                        ),
                      if (_hasPhone) const SizedBox(width: 10),
                      if (!isOwner)
                        Expanded(
                          child: _DetailsActionButton(
                            label: isEl ? 'Μήνυμα' : 'Message',
                            icon: Icons.chat_bubble_outline_rounded,
                            onTap: () => _sendMessage(context),
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      if (!isOwner) const SizedBox(width: 10),
                      // Share: compact & right-aligned when it is the only
                      // visible action (owner with no phone); expanded otherwise.
                      if (isOwner && !_hasPhone)
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 140,
                            child: _DetailsActionButton(
                              label: isEl ? 'Κοινοπ.' : 'Share',
                              icon: Icons.share_outlined,
                              onTap: _shareReport,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: _DetailsActionButton(
                            label: isEl ? 'Κοινοπ.' : 'Share',
                            icon: Icons.share_outlined,
                            onTap: _shareReport,
                            color: AppTheme.textSecondary,
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
    );
  }
}

class _MainCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _MainCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SecondaryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SecondaryCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String en;
  final String el;

  const _SectionTitle(this.en, this.el);

  @override
  Widget build(BuildContext context) {
    final isEl = Localizations.localeOf(context).languageCode == 'el';
    return Text(
      isEl ? el : en,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 17,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _SightingEntryCard extends StatelessWidget {
  final bool isEl;
  final LostPetSighting sighting;
  final String formattedDateTime;
  final String? locationLabel;
  final VoidCallback? onOpenMap;
  final VoidCallback? onDelete;

  const _SightingEntryCard({
    required this.isEl,
    required this.sighting,
    required this.formattedDateTime,
    required this.locationLabel,
    required this.onOpenMap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasNote = sighting.notes.trim().isNotEmpty;
    final hasLocation =
        locationLabel != null && locationLabel!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border.withOpacity(0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 26,
                width: 26,
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 15,
                  color: AppTheme.primaryTeal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasLocation)
                      InkWell(
                        onTap: onOpenMap,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppTheme.primaryTeal,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  locationLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryTeal,
                                    fontSize: 13.8,
                                  ),
                                ),
                              ),
                              if (onOpenMap != null) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 17,
                                  color: AppTheme.primaryTeal,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (hasNote) ...[
                      const SizedBox(height: 8),
                      Text(
                        sighting.notes.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary.withOpacity(0.78),
                          height: 1.35,
                          fontSize: 13.2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: AppTheme.textSecondary.withOpacity(0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formattedDateTime,
                          style: TextStyle(
                            color: AppTheme.textSecondary.withOpacity(0.6),
                            fontSize: 11.8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minHeight: 32,
                    minWidth: 32,
                  ),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppTheme.textSecondary.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LostStatusBadge extends StatelessWidget {
  final bool isEl;

  const _LostStatusBadge({required this.isEl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.lostFound.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            isEl ? 'ΧΑΘΗΚΕ' : 'LOST ALERT',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedStatusBadge extends StatelessWidget {
  final bool isEl;

  const _ResolvedStatusBadge({required this.isEl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            isEl ? 'ΒΡΕΘΗΚΕ / ΚΛΕΙΣΤΟ' : 'FOUND / CLOSED',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _DetailsActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withOpacity(0.04),
          side: BorderSide(
            color: color.withOpacity(0.2),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LostReportMapScreen extends StatelessWidget {
  final bool isEl;
  final String petName;
  final double latitude;
  final double longitude;

  const _LostReportMapScreen({
    required this.isEl,
    required this.petName,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final target = LatLng(latitude, longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEl ? 'Τοποθεσία απώλειας' : 'Lost location'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: target,
          zoom: 16,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('lost_pet_location'),
            position: target,
            infoWindow: InfoWindow(title: petName),
          ),
        },
      ),
    );
  }
}
