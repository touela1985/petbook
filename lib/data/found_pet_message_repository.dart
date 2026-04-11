import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/found_pet_message.dart';

class FoundPetMessageRepository {
  static const String _storageKey = 'found_pet_messages';
  static const String _collection = 'found_pet_messages';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Local helpers ────────────────────────────────────────────────────────

  Future<List<FoundPetMessage>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => FoundPetMessage.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveLocal(List<FoundPetMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(messages.map((m) => m.toMap()).toList()),
    );
  }

  // ─── Firestore helpers ────────────────────────────────────────────────────

  Future<void> _setFirestore(FoundPetMessage message) async {
    await _firestore
        .collection(_collection)
        .doc(message.id)
        .set(message.toMap());
  }

  Future<List<FoundPetMessage>> _loadFirestoreForReport(
      String reportId, String uid) async {
    debugPrint('[FoundMsg] ▶ Firestore read START — reportId: $reportId, uid: $uid');

    // Two separate single-field queries to satisfy Firestore security rules
    // without requiring composite indexes.
    // Rule: senderUserId==uid OR receiverUserId==uid OR reportOwnerUserId==uid
    // Each query guarantees its own condition → Firestore allows it.

    // Query 1: messages WHERE current user is the SENDER
    final q1 = await _firestore
        .collection(_collection)
        .where('senderUserId', isEqualTo: uid)
        .get();

    // Query 2: messages WHERE current user is the RECEIVER
    final q2 = await _firestore
        .collection(_collection)
        .where('receiverUserId', isEqualTo: uid)
        .get();

    // Merge, filter by reportId in Dart, deduplicate by id.
    final Map<String, FoundPetMessage> seen = {};
    for (final doc in [...q1.docs, ...q2.docs]) {
      final msg = FoundPetMessage.fromMap(doc.data());
      if (msg.reportId != reportId) continue;
      seen[msg.id] = msg;
      debugPrint(
        '[FoundMsg] ✅ read doc — id: ${msg.id} '
        'sender: ${msg.senderUserId} '
        'receiver: ${msg.receiverUserId} '
        'reportOwner: ${msg.reportOwnerUserId}',
      );
    }

    final messages = seen.values.toList();
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    debugPrint('[FoundMsg] ✅ Firestore read DONE — ${messages.length} messages for report $reportId');
    return messages;
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  Future<List<FoundPetMessage>> getMessagesForReport(
      String reportId, String uid) async {
    // Firestore is source of truth — try it first.
    try {
      final firestoreMessages = await _loadFirestoreForReport(reportId, uid);
      if (firestoreMessages.isNotEmpty) return firestoreMessages;
    } catch (e) {
      debugPrint('[FoundMsg] ❌ Firestore read FAILED: $e');
    }

    // Fallback to local only if Firestore fails or returns empty.
    debugPrint('[FoundMsg] ⚠ Falling back to local storage for report $reportId');
    final local = await _loadLocal();
    final filtered = local.where((m) => m.reportId == reportId).toList();
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  Future<bool> addMessage(FoundPetMessage message) async {
    // 1. Firestore — primary
    bool firestoreOk = false;
    debugPrint('[FoundMsg] ▶ Firestore write START — id: ${message.id}');
    debugPrint('[FoundMsg] payload: ${message.toMap()}');
    try {
      await _setFirestore(message);
      firestoreOk = true;
      debugPrint('[FoundMsg] ✅ Firestore write SUCCESS — id: ${message.id}');
    } catch (e, stack) {
      debugPrint('[FoundMsg] ❌ Firestore write FAILED — id: ${message.id}');
      debugPrint('[FoundMsg] error: $e');
      debugPrint('[FoundMsg] stack: $stack');
    }

    // 2. Local — always, even when Firestore fails (offline safety)
    final messages = await _loadLocal();
    messages.add(message);
    await _saveLocal(messages);

    return firestoreOk;
  }

  Future<void> deleteMessage(String messageId) async {
    // 1. Firestore
    try {
      await _firestore.collection(_collection).doc(messageId).delete();
    } catch (_) {}

    // 2. Local
    final messages = await _loadLocal();
    messages.removeWhere((m) => m.id == messageId);
    await _saveLocal(messages);
  }

  Future<void> markAllMessagesAsReadForReport(String reportId) async {
    final messages = await _loadLocal();
    final updated = messages.map((m) {
      if (m.reportId == reportId && !m.isRead) {
        return m.copyWith(isRead: true);
      }
      return m;
    }).toList();
    await _saveLocal(updated);
  }
}
