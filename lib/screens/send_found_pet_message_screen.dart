import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/found_pet_message_repository.dart';
import '../models/found_pet_message.dart';
import '../models/found_pet_report.dart';
import '../theme/app_theme.dart';

class SendFoundPetMessageScreen extends StatefulWidget {
  final FoundPetReport report;

  const SendFoundPetMessageScreen({
    super.key,
    required this.report,
  });

  @override
  State<SendFoundPetMessageScreen> createState() =>
      _SendFoundPetMessageScreenState();
}

class _SendFoundPetMessageScreenState extends State<SendFoundPetMessageScreen> {
  final FoundPetMessageRepository _repo = FoundPetMessageRepository();
  final TextEditingController _messageController = TextEditingController();
  final Uuid _uuid = const Uuid();

  bool _isSaving = false;

  bool get _isEl => Localizations.localeOf(context).languageCode == 'el';

  String get _reportTitle {
    final type = widget.report.type.trim();
    return type.isEmpty ? (_isEl ? 'Βρέθηκε ζώο' : 'Found pet') : type;
  }

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
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

    setState(() => _isSaving = true);

    final message = FoundPetMessage(
      id: _uuid.v4(),
      reportId: widget.report.id,
      text: messageText,
      senderName: user.email ?? user.uid,
      timestamp: DateTime.now(),
      senderUserId: user.uid,
      receiverUserId: receiverUserId,
      reportOwnerUserId: receiverUserId,
      isRead: false,
    );

    final firestoreOk = await _repo.addMessage(message);

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (firestoreOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEl ? 'Το μήνυμα στάλθηκε.' : 'Message sent successfully.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEl
                ? 'Σφάλμα αποστολής. Έλεγξε τη σύνδεσή σου και δοκίμασε ξανά.'
                : 'Send failed. Check your connection and try again.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
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
                      ? 'Μήνυμα για: $_reportTitle'
                      : 'Send a message about $_reportTitle',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEl
                      ? 'Μοιράσου χρήσιμες πληροφορίες με τον ευρέτη.'
                      : 'Use this to share helpful information with the finder.',
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
                        ? 'π.χ. Νομίζω ότι αυτό το ζωάκι ανήκει σε κάποιον κοντά στη μαρίνα.'
                        : 'Example: I think this pet belongs to someone near the marina.',
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
