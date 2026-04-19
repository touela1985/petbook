import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lost_pet_message.dart';

class LostPetMessageRepository {
  static const String _storageKey = 'lost_pet_messages';
  static const String _collection = 'lost_pet_messages';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Local helpers ────────────────────────────────────────────────────────

  Future<List<LostPetMessage>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((item) => LostPetMessage.fromJson(item)).toList();
  }

  Future<void> _saveLocal(List<LostPetMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(messages.map((m) => m.toJson()).toList()),
    );
  }

  // ─── Firestore helpers ────────────────────────────────────────────────────

  Future<void> _setFirestore(LostPetMessage message) async {
    await _firestore
        .collection(_collection)
        .doc(message.id)
        .set(message.toJson());
  }

  Future<List<LostPetMessage>> _loadFirestoreForReport(
      String reportId, String uid) async {
    // Two separate single-field queries to satisfy Firestore security rules.
    // Rules allow read only when senderUserId==uid OR receiverUserId==uid.
    final q1 = await _firestore
        .collection(_collection)
        .where('senderUserId', isEqualTo: uid)
        .get();

    final q2 = await _firestore
        .collection(_collection)
        .where('receiverUserId', isEqualTo: uid)
        .get();

    // Merge, filter by reportId in Dart, deduplicate by id.
    final Map<String, LostPetMessage> seen = {};
    for (final doc in [...q1.docs, ...q2.docs]) {
      final msg = LostPetMessage.fromJson(doc.data());
      if (msg.reportId != reportId) continue;
      seen[msg.id] = msg;
    }

    final messages = seen.values.toList();
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return messages;
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  Future<List<LostPetMessage>> getAllMessages() async {
    final local = await _loadLocal();
    return local;
  }

  Future<List<LostPetMessage>> getMessagesForReport(
      String reportId, String uid) async {
    // Try Firestore first; fall back to local on error.
    try {
      final firestoreMessages =
          await _loadFirestoreForReport(reportId, uid);
      if (firestoreMessages.isNotEmpty) return firestoreMessages;
    } catch (_) {}

    final local = await _loadLocal();
    final filtered =
        local.where((m) => m.reportId == reportId).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<bool> addMessage(LostPetMessage message) async {
    // 1. Firestore — primary
    bool firestoreOk = false;
    try {
      await _setFirestore(message);
      firestoreOk = true;
    } catch (_) {}

    // 2. Local — always, even when Firestore fails (offline safety)
    final messages = await _loadLocal();
    messages.add(message);
    await _saveLocal(messages);

    return firestoreOk;
  }

  Future<void> saveAllMessages(List<LostPetMessage> messages) async {
    await _saveLocal(messages);
  }

  Future<void> deleteMessage(String messageId) async {
    // 1. Local
    final messages = await _loadLocal();
    messages.removeWhere((m) => m.id == messageId);
    await _saveLocal(messages);

    // 2. Firestore — silent fail
    try {
      await _firestore.collection(_collection).doc(messageId).delete();
    } catch (_) {}
  }
}
