import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/found_pet_message.dart';

class FoundPetMessageRepository {
  static const String _storageKey = 'found_pet_messages';

  Future<List<FoundPetMessage>> getAllMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => FoundPetMessage.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAllMessages(List<FoundPetMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      messages.map((message) => message.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
  }

  Future<List<FoundPetMessage>> getMessagesForReport(String reportId) async {
    final messages = await getAllMessages();

    final filtered = messages
        .where((message) => message.reportId == reportId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  Future<void> addMessage(FoundPetMessage message) async {
    final messages = await getAllMessages();
    messages.add(message);
    await _saveAllMessages(messages);
  }

  Future<void> deleteMessage(String messageId) async {
    final messages = await getAllMessages();
    messages.removeWhere((message) => message.id == messageId);
    await _saveAllMessages(messages);
  }

  Future<void> markAllMessagesAsReadForReport(String reportId) async {
    final messages = await getAllMessages();

    final updated = messages.map((message) {
      if (message.reportId == reportId && !message.isRead) {
        return message.copyWith(isRead: true);
      }
      return message;
    }).toList();

    await _saveAllMessages(updated);
  }
}
