import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/found_pet_message_repository.dart';
import '../models/found_pet_report.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_image_widget.dart';
import 'found_pet_messages_screen.dart';
import 'send_found_pet_message_screen.dart';

class FoundPetReportDetailsScreen extends StatefulWidget {
  final FoundPetReport report;

  const FoundPetReportDetailsScreen({
    super.key,
    required this.report,
  });

  @override
  State<FoundPetReportDetailsScreen> createState() =>
      _FoundPetReportDetailsScreenState();
}

class _FoundPetReportDetailsScreenState
    extends State<FoundPetReportDetailsScreen> {
  final FoundPetMessageRepository _messageRepository =
      FoundPetMessageRepository();

  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMessageStats();
  }

  Future<void> _loadMessageStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final messages =
        await _messageRepository.getMessagesForReport(widget.report.id, uid);
    if (!mounted) return;
    setState(() {
      _messageCount = messages.length;
    });
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  bool get _hasPhoto => hasAnyImage(
        photoUrl: widget.report.photoUrl,
        photoPath: widget.report.photoPath,
      );

  bool get _hasPhone => widget.report.contactPhone.trim().isNotEmpty;

  String get _displayType =>
      widget.report.type.trim().isEmpty
          ? (_isEl ? 'Βρέθηκε ζώο' : 'Found pet')
          : widget.report.type.trim();

  String get _messageSubtitle {
    if (_messageCount == 0) {
      return _isEl ? 'Δεν υπάρχουν μηνύματα' : 'No messages yet';
    }
    if (_isEl) {
      return _messageCount == 1
          ? '1 μήνυμα'
          : '$_messageCount μηνύματα';
    }
    return '$_messageCount message${_messageCount == 1 ? '' : 's'}';
  }

  Widget _buildFallbackImage({
    double? height,
    double? width,
    IconData icon = Icons.pets,
  }) {
    return Container(
      height: height ?? 200,
      width: width ?? 200,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Icon(
        icon,
        size: 44,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildReportImage({
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
  }) {
    return PetImageWidget(
      photoUrl: widget.report.photoUrl,
      photoPath: widget.report.photoPath,
      height: height,
      width: width,
      fit: fit,
      placeholder: _buildFallbackImage(
        height: height,
        width: width,
        icon: Icons.pets,
      ),
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

  Future<void> _callFinder() async {
    final phone = widget.report.contactPhone.trim();
    if (phone.isEmpty) return;

    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Future<void> _sendMessage(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SendFoundPetMessageScreen(report: widget.report),
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
        builder: (_) => FoundPetMessagesScreen(report: widget.report),
      ),
    );
    await _loadMessageStats();
  }

  Future<void> _shareReport() async {
    final contact = _hasPhone
        ? widget.report.contactPhone.trim()
        : (_isEl ? 'Δεν υπάρχει τηλέφωνο' : 'No phone provided');

    final text = _isEl
        ? '''
Ειδοποίηση εύρεσης

Τύπος: $_displayType
Τοποθεσία: ${widget.report.locationFound}
Ημερομηνία: ${_formatDate(widget.report.foundDate)}
Επικοινωνία: $contact

Κοινοποιήθηκε μέσω Petbook
'''
        : '''
Found pet alert
Type: $_displayType
Location: ${widget.report.locationFound}
Date: ${_formatDate(widget.report.foundDate)}
Contact: $contact
Shared via Petbook
''';

    await Share.share(
      text,
      subject: _isEl ? 'Ευρεθέν ζώο – Petbook' : 'Found pet alert – Petbook',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEl = _isEl;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && currentUser.uid == widget.report.userId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isEl ? 'Βρέθηκε ζώο' : 'Found Pet Alert'),
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
                  _FoundStatusBadge(isEl: isEl),
                  const SizedBox(height: 14),
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _hasPhoto ? () => _openFullImage(context) : null,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              height: 220,
                              width: double.infinity,
                              child: _buildReportImage(
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
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
                                fontSize: 12,
                                color: AppTheme.textSecondary,
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
                    _displayType,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.report.locationFound.trim().isEmpty
                              ? (isEl ? 'Δεν υπάρχει τοποθεσία' : 'No location added')
                              : widget.report.locationFound,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        _formatDate(widget.report.foundDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (widget.report.notes.trim().isNotEmpty) ...[
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
                        widget.report.notes.trim(),
                        style: const TextStyle(height: 1.4),
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
                        if (isOwner)
                          TextButton(
                            onPressed: () => _openMessages(context),
                            child: Text(isEl ? 'Προβολή' : 'View'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isEl ? 'Επικοινωνία' : 'Contact finder',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_hasPhone) ...[
                    Text(
                      widget.report.contactPhone.trim(),
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
                            onTap: _callFinder,
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

class _FoundStatusBadge extends StatelessWidget {
  final bool isEl;

  const _FoundStatusBadge({required this.isEl});

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
            Icons.favorite_rounded,
            size: 15,
            color: AppTheme.primaryTeal,
          ),
          const SizedBox(width: 6),
          Text(
            isEl ? 'ΒΡΕΘΗΚΕ' : 'FOUND ALERT',
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
