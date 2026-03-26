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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final Uuid _uuid = const Uuid();

  bool _isSaving = false;

  String get _petName {
    final name = widget.report.petName.trim();
    return name.isEmpty ? 'Lost pet' : name;
  }

  Future<void> _sendMessage() async {
    final senderName = _nameController.text.trim();
    final messageText = _messageController.text.trim();

    if (messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write a message first.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final message = LostPetMessage(
      id: _uuid.v4(),
      reportId: widget.report.id,
      senderName: senderName.isEmpty ? 'Anonymous' : senderName,
      message: messageText,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await _repo.addMessage(message);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message sent successfully.'),
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Send Message'),
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
                  'Send a message about $_petName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use this to share useful information with the pet owner.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your name (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    hintText: 'Example: I think I saw this pet near the marina.',
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
                    label: Text(_isSaving ? 'Sending...' : 'Send Message'),
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
