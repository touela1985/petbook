import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/found_pet_message_repository.dart';
import '../models/found_pet_message.dart';
import '../models/found_pet_report.dart';
import '../theme/app_theme.dart';

class FoundPetMessagesScreen extends StatefulWidget {
  final FoundPetReport report;

  const FoundPetMessagesScreen({
    super.key,
    required this.report,
  });

  @override
  State<FoundPetMessagesScreen> createState() =>
      _FoundPetMessagesScreenState();
}

class _FoundPetMessagesScreenState extends State<FoundPetMessagesScreen> {
  final FoundPetMessageRepository _repo = FoundPetMessageRepository();

  List<FoundPetMessage> _messages = [];
  bool _isLoading = true;

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  String get _reportTitle {
    final type = widget.report.type.trim();
    return type.isEmpty ? (_isEl ? 'Βρέθηκε ζώο' : 'Found pet') : type;
  }

  String? get _location {
    final l = widget.report.locationFound.trim();
    return l.isEmpty ? null : l;
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final messages = await _repo.getMessagesForReport(widget.report.id, uid);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $h:$min';
  }

  bool _canDelete(FoundPetMessage message) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null &&
        (uid == widget.report.userId || uid == message.senderUserId);
  }

  Future<void> _deleteMessage(FoundPetMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
      ),
    );
    if (confirm == true) {
      await _repo.deleteMessage(message.id);
      await _loadMessages();
    }
  }

  Widget _buildMessageCard(FoundPetMessage message) {
    final sender = message.senderName.trim().isEmpty
        ? (_isEl ? 'Ανώνυμος' : 'Anonymous')
        : message.senderName.trim();

    return Container(
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
                  _formatDateTime(message.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message.text,
                  style: const TextStyle(
                    height: 1.4,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (_canDelete(message))
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') await _deleteMessage(message);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(_isEl ? 'Διαγραφή' : 'Delete'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_reportTitle),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMessages,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Context card
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
                    _isEl ? 'Αναφορά εύρεσης' : 'Found pet report',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _reportTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
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
                child: Center(child: CircularProgressIndicator()),
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
                      _isEl
                          ? 'Δεν υπάρχουν μηνύματα ακόμα.'
                          : 'No messages yet.',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              // Message count is _messages.length — rendered as cards below.
              ..._messages.map(_buildMessageCard),
          ],
        ),
      ),
    );
  }
}
