import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet_health_event.dart';

class PetHealthRepository {
  static const String _storageKey = 'pet_health_events';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Internal: loads ALL events unfiltered ───────────────────────────────

  Future<List<PetHealthEvent>> _loadAllRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((item) => PetHealthEvent.fromJson(item)).toList();
  }

  Future<void> _saveAllRaw(List<PetHealthEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  // ─── Public API ──────────────────────────────────────────────────────────

  /// Returns only the current user's events (strict filter — no auto-claim).
  /// Legacy events with null userId are left untouched and are not visible
  /// to any user until they are explicitly stamped via addEvent().
  Future<List<PetHealthEvent>> getAllEvents() async {
    final uid = _uid;
    if (uid == null) return [];
    final all = await _loadAllRaw();
    return all.where((e) => e.userId == uid).toList();
  }

  /// Replaces the current user's events with [events], leaving other
  /// users' events untouched in the shared local store.
  Future<void> saveAllEvents(List<PetHealthEvent> events) async {
    final uid = _uid;
    final raw = await _loadAllRaw();

    // Keep events that belong to OTHER users.
    final otherUsersEvents = uid != null
        ? raw.where((e) => e.userId != null && e.userId != uid).toList()
        : <PetHealthEvent>[];

    // Stamp the provided events with current uid if missing.
    final myEvents = uid != null
        ? events
            .map((e) => e.userId == null ? e.copyWith(userId: uid) : e)
            .toList()
        : events;

    await _saveAllRaw([...otherUsersEvents, ...myEvents]);
  }

  Future<List<PetHealthEvent>> getEventsForPet(String petId) async {
    final events = await getAllEvents();
    final petEvents = events.where((event) => event.petId == petId).toList();
    petEvents.sort((a, b) => b.date.compareTo(a.date));
    return petEvents;
  }

  Future<void> addEvent(PetHealthEvent event) async {
    final uid = _uid;
    // Auto-stamp userId on new events.
    final stamped =
        uid != null && event.userId == null ? event.copyWith(userId: uid) : event;
    final raw = await _loadAllRaw();
    raw.add(stamped);
    await _saveAllRaw(raw);
  }

  Future<void> updateEvent(PetHealthEvent updatedEvent) async {
    final raw = await _loadAllRaw();
    final index = raw.indexWhere((event) => event.id == updatedEvent.id);
    if (index == -1) return;
    raw[index] = updatedEvent;
    await _saveAllRaw(raw);
  }

  Future<void> deleteEvent(String id) async {
    final raw = await _loadAllRaw();
    raw.removeWhere((event) => event.id == id);
    await _saveAllRaw(raw);
  }
}
