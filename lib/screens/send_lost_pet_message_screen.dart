import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/lost_pet_message_repository.dart';
import '../models/lost_pet_message.dart';
import '../models/lost_pet_report.dart';
import '../theme/app_theme.dart';

class SendLostPetMessageScreen extends StatefulWidget {
  final LostPetReport report;

  const SendLostPetMessageScreen({
    super.key,
    required this.report,
  });

  @override
  State<SendLostPetMessageScreen> createState() =>
      _SendLostPetMessageScreenState();
}

class _SendLostPetMessageScreenState extends State<SendLostPetMessageScreen> {
  final LostPetMessageRepository _repo = LostPetMessageRepository();
  final TextEditingController _messageController = TextEditingController();
  final Uuid _uuid = const Uuid();

  bool _isSaving = false;

  String get _petName {
    final name = widget.report.petName.trim();
    return name.isEmpty ? 'Lost pet' : name;
  }

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  Future<void> _sendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    // Auth guard — do not allow anonymous sends.
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEl
                ? 'Πρέπει να είσαι συνδεδεμένος για να στείλεις μήνυμα.'
                : 'You must be logged in to send a message.',
          ),
        ),
      );
      return;
    }

    final messageText = _messageController.text.trim();

    if (messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEl ? 'Γράψε ένα μήνυμα πρώτα.' : 'Please write a message first.',
          ),
        ),
      );
      return;
    }

    // Safety: do not send if receiverUserId is null (report has no owner).
    final receiverUserId = widget.report.userId;
    if (receiverUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEl
                ? 'Δεν είναι δυνατή η αποστολή μηνύματος για αυτή την αναφορά.'
                : 'Cannot send a message for this report.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final message = LostPetMessage(
      id: _uuid.v4(),
      reportId: widget.report.id,
      senderName: currentUser.email ?? currentUser.uid,
      senderUserId: currentUser.uid,
      receiverUserId: receiverUserId,
      message: messageText,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await _repo.addMessage(message);
    // TODO Step 20: trigger push notification to receiverUserId via Cloud Function

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEl ? 'Το μήνυμα στάλθηκε.' : 'Message sent successfully.',
        ),
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEl ? 'Αποστολή μηνύματος' : 'Send Message'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEl
                      ? 'Μήνυμα για: $_petName'
                      : 'Send a message about $_petName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEl
                      ? 'Μοιράσου χρήσιμες πληροφορίες με τον ιδιοκτήτη.'
                      : 'Use this to share useful information with the pet owner.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _messageController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: _isEl ? 'Μήνυμα' : 'Message',
                    alignLabelWithHint: true,
                    hintText: _isEl
                        ? 'π.χ. Νομίζω ότι είδα αυτό το ζωάκι κοντά στη μαρίνα.'
                        : 'Example: I think I saw this pet near the marina.',
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _sendMessage,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isSaving
                          ? (_isEl ? 'Αποστολή...' : 'Sending...')
                          : (_isEl ? 'Αποστολή' : 'Send Message'),
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
}
