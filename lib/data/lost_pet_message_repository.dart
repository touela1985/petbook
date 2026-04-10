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
      String reportId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('reportId', isEqualTo: reportId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => LostPetMessage.fromJson(doc.data()))
        .toList();
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  Future<List<LostPetMessage>> getAllMessages() async {
    final local = await _loadLocal();
    return local;
  }

  Future<List<LostPetMessage>> getMessagesForReport(String reportId) async {
    // Try Firestore first; fall back to local on error.
    try {
      final firestoreMessages = await _loadFirestoreForReport(reportId);
      if (firestoreMessages.isNotEmpty) return firestoreMessages;
    } catch (_) {}

    final local = await _loadLocal();
    final filtered =
        local.where((m) => m.reportId == reportId).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<void> addMessage(LostPetMessage message) async {
    // 1. Local — always
    final messages = await _loadLocal();
    messages.add(message);
    await _saveLocal(messages);

    // 2. Firestore — silent fail
    try {
      await _setFirestore(message);
    } catch (_) {}
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
