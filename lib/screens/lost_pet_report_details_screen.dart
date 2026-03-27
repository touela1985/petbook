import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/lost_pet_message_repository.dart';
import '../data/lost_pet_report_repository.dart';
import '../models/lost_pet_report.dart';
import '../theme/app_theme.dart';
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

  late LostPetReport _report;

  int _messageCount = 0;
  bool _isMarkingResolved = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _loadMessageStats();
  }

  Future<void> _loadMessageStats() async {
    final messages = await _messageRepository.getMessagesForReport(_report.id);
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

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  bool get _hasCoordinates =>
      _report.latitude != null && _report.longitude != null;

  bool get _hasPhoto =>
      _report.photoPath != null && _report.photoPath!.trim().isNotEmpty;

  bool get _hasPhone => _report.contactPhone.trim().isNotEmpty;

  String get _displayPetName => _report.petName.trim().isEmpty
      ? (_isEl ? 'Χαμένο ζώο' : 'Lost pet')
      : _report.petName.trim();

  List<LostPetSighting> get _sortedSightings {
    final sightings = [..._report.sightings];
    sightings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sightings;
  }

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
    BoxFit fit = BoxFit.contain,
  }) {
    if (!_hasPhoto) {
      return Container(
        height: height ?? 220,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.pets,
          size: 44,
          color: AppTheme.textSecondary,
        ),
      );
    }

    final path = _report.photoPath!.trim();

    Widget fallback() {
      return Container(
        height: height ?? 220,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.broken_image_outlined,
          size: 44,
          color: AppTheme.textSecondary,
        ),
      );
    }

    if (kIsWeb) {
      return Image.network(
        path,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    return Image.file(
      File(path),
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback(),
    );
  }

  void _openFullImage(BuildContext context) {
    if (!_hasPhoto) return;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black,
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

    await Share.share(text);
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

    final updatedSightings =
        _report.sightings.where((item) => item.id != sighting.id).toList();

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
      latitude: _report.latitude,
      longitude: _report.longitude,
      createdAt: _report.createdAt,
      sightings: updatedSightings,
    );

    await _reportRepository.updateReport(updatedReport);

    if (!mounted) return;

    setState(() {
      _report = updatedReport;
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isEl ? 'Χαμένο ζώο' : 'Lost Pet Alert'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isResolved
                      ? _ResolvedStatusBadge(isEl: isEl)
                      : _LostStatusBadge(isEl: isEl),
                  const SizedBox(height: 14),
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _hasPhoto ? () => _openFullImage(context) : null,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              height: 260,
                              width: double.infinity,
                              color: const Color(0xFFF5F4EF),
                              child: _buildReportImage(
                                height: 260,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          if (_hasPhoto) ...[
                            const SizedBox(height: 8),
                            Text(
                              isEl
                                  ? 'Πάτησε τη φωτογραφία για μεγέθυνση'
                                  : 'Tap image to enlarge',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _displayPetName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (_report.type.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _report.type.trim(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppTheme.lostFound,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _report.lastSeenLocation.trim().isEmpty
                              ? (isEl
                                  ? 'Δεν υπάρχει τοποθεσία'
                                  : 'No location added')
                              : _report.lastSeenLocation,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_hasCoordinates) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${_report.latitude!.toStringAsFixed(5)}, ${_report.longitude!.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                          side: BorderSide(
                            color: AppTheme.primaryTeal.withOpacity(0.24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(_report.lastSeenDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (_report.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      isEl ? 'Σημειώσεις' : 'Notes',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        _report.notes.trim(),
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                  if (_sortedSightings.isNotEmpty) ...[
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 10),
                    ..._sortedSightings.map(
                      (sighting) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F8F5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.border,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
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
                                  height: 34,
                                  width: 34,
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryTeal.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.remove_red_eye_outlined,
                                    size: 18,
                                    color: AppTheme.primaryTeal,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      sighting.location.trim().isEmpty
                                          ? (isEl
                                              ? 'Δεν υπάρχει τοποθεσία'
                                              : 'No location')
                                          : sighting.location.trim(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        height: 1.3,
                                        color: AppTheme.textPrimary,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deleteSighting(sighting),
                                  tooltip: isEl ? 'Διαγραφή' : 'Delete',
                                  splashRadius: 20,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            if (sighting.notes.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppTheme.border.withOpacity(0.9),
                                  ),
                                ),
                                child: Text(
                                  sighting.notes.trim(),
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    height: 1.45,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 15,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDateTime(sighting.createdAt),
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
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
                        TextButton(
                          onPressed: () => _openMessages(context),
                          child: Text(isEl ? 'Προβολή' : 'View'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!isResolved) ...[
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
                              : (isEl
                                  ? 'Σήμανση ως βρέθηκε'
                                  : 'Mark as Found'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                  ] else ...[
                    Text(
                      isEl ? 'Δεν υπάρχει τηλέφωνο' : 'No phone provided',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
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
                      if (_hasPhone) const SizedBox(width: 8),
                      Expanded(
                        child: _DetailsActionButton(
                          label: isEl ? 'Μήνυμα' : 'Message',
                          icon: Icons.chat_bubble_outline_rounded,
                          onTap: () => _sendMessage(context),
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 8),
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

class _LostStatusBadge extends StatelessWidget {
  final bool isEl;

  const _LostStatusBadge({required this.isEl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.lostFound.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.lostFound.withOpacity(0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 15,
            color: AppTheme.lostFound,
          ),
          const SizedBox(width: 6),
          Text(
            isEl ? 'ΧΑΘΗΚΕ' : 'LOST ALERT',
            style: const TextStyle(
              color: AppTheme.lostFound,
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
        color: AppTheme.primaryTeal.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.primaryTeal.withOpacity(0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 15,
            color: AppTheme.primaryTeal,
          ),
          const SizedBox(width: 6),
          Text(
            isEl ? 'ΒΡΕΘΗΚΕ / ΚΛΕΙΣΤΟ' : 'FOUND / CLOSED',
            style: const TextStyle(
              color: AppTheme.primaryTeal,
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
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.04),
        side: BorderSide(
          color: color.withOpacity(0.22),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
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
