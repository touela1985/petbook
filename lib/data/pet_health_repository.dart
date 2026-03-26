import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet_health_event.dart';

class PetHealthRepository {
  static const String _storageKey = 'pet_health_events';

  Future<List<PetHealthEvent>> getAllEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(jsonString);

    return decoded.map((item) => PetHealthEvent.fromJson(item)).toList();
  }

  Future<void> saveAllEvents(List<PetHealthEvent> events) async {
    final prefs = await SharedPreferences.getInstance();

    final String encoded = jsonEncode(
      events.map((event) => event.toJson()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }

  Future<List<PetHealthEvent>> getEventsForPet(String petId) async {
    final events = await getAllEvents();

    final petEvents = events.where((event) => event.petId == petId).toList();

    petEvents.sort((a, b) => b.date.compareTo(a.date));

    return petEvents;
  }

  Future<void> addEvent(PetHealthEvent event) async {
    final events = await getAllEvents();
    events.add(event);
    await saveAllEvents(events);
  }

  Future<void> updateEvent(PetHealthEvent updatedEvent) async {
    final events = await getAllEvents();

    final index = events.indexWhere((event) => event.id == updatedEvent.id);

    if (index == -1) return;

    events[index] = updatedEvent;
    await saveAllEvents(events);
  }

  Future<void> deleteEvent(String id) async {
    final events = await getAllEvents();

    events.removeWhere((event) => event.id == id);

    await saveAllEvents(events);
  }
}
