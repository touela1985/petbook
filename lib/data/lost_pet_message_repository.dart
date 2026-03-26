import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/lost_pet_message.dart';

class LostPetMessageRepository {
  static const String _storageKey = 'lost_pet_messages';

  Future<List<LostPetMessage>> getAllMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(jsonString);

    return decoded.map((item) => LostPetMessage.fromJson(item)).toList();
  }

  Future<void> saveAllMessages(List<LostPetMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();

    final String encoded = jsonEncode(
      messages.map((message) => message.toJson()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }

  Future<List<LostPetMessage>> getMessagesForReport(String reportId) async {
    final messages = await getAllMessages();

    final reportMessages =
        messages.where((message) => message.reportId == reportId).toList();

    reportMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return reportMessages;
  }

  Future<void> addMessage(LostPetMessage message) async {
    final messages = await getAllMessages();
    messages.add(message);
    await saveAllMessages(messages);
  }

  Future<void> deleteMessage(String messageId) async {
    final messages = await getAllMessages();
    messages.removeWhere((message) => message.id == messageId);
    await saveAllMessages(messages);
  }
}
