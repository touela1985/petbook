import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/lost_pet_message_repository.dart';
import '../models/lost_pet_message.dart';
import '../models/lost_pet_report.dart';
import '../theme/app_theme.dart';

class LostPetMessagesScreen extends StatefulWidget {
  final LostPetReport report;

  const LostPetMessagesScreen({
    super.key,
    required this.report,
  });

  @override
  State<LostPetMessagesScreen> createState() => _LostPetMessagesScreenState();
}

class _LostPetMessagesScreenState extends State<LostPetMessagesScreen> {
  final LostPetMessageRepository _repo = LostPetMessageRepository();

  List<LostPetMessage> _messages = [];
  bool _isLoading = true;

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  String get _petName {
    final name = widget.report.petName.trim();
    return name.isEmpty ? (_isEl ? 'Χαμένο ζώο' : 'Lost pet') : name;
  }

  String? get _petType {
    final t = widget.report.type.trim();
    return t.isEmpty ? null : t;
  }

  String? get _location {
    final l = widget.report.lastSeenLocation.trim();
    return l.isEmpty ? null : l;
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final messages = await _repo.getMessagesForReport(widget.report.id, uid);

    if (!mounted) return;

    setState(() {
      _messages = messages;
      _isLoading = false;
    });
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  bool _canDelete(LostPetMessage message) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    // Owner of the report OR sender of the message.
    final isReportOwner = widget.report.userId == currentUser.uid;
    final isMessageSender = message.senderUserId == currentUser.uid;
    return isReportOwner || isMessageSender;
  }

  Future<void> _deleteMessage(LostPetMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(_isEl ? 'Διαγραφή μηνύματος' : 'Delete message'),
          content: Text(
            _isEl
                ? 'Θέλεις σίγουρα να διαγράψεις αυτό το μήνυμα;'
                : 'Are you sure you want to delete this message?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_isEl ? 'Ακύρωση' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_isEl ? 'Διαγραφή' : 'Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _repo.deleteMessage(message.id);
      await _loadMessages();
    }
  }

  Widget _buildMessageCard(LostPetMessage message) {
    final sender = message.senderName.trim().isEmpty
        ? (_isEl ? 'Ανώνυμος' : 'Anonymous')
        : message.senderName.trim();

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sender,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(message.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message.message,
                    style: const TextStyle(
                      height: 1.4,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (_canDelete(message))
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.textSecondary,
                onPressed: () => _deleteMessage(message),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_petName),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMessages,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEl ? 'Αναφορά απώλειας' : 'Lost pet report',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _petName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (_petType != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _petType!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (_location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _location!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_messages.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      size: 36,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isEl ? 'Δεν υπάρχουν μηνύματα ακόμα.' : 'No messages yet.',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._messages.map(_buildMessageCard),
          ],
        ),
      ),
    );
  }
}
