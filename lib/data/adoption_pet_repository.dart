import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/adoption_pet.dart';

class AdoptionPetRepository {
  static const _storageKey = 'adoption_pets';

  Future<List<AdoptionPet>> getPets() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null) {
      return [];
    }

    final List decoded = json.decode(jsonString);

    return decoded.map((e) => AdoptionPet.fromJson(e)).toList();
  }

  Future<void> addPet(AdoptionPet pet) async {
    final prefs = await SharedPreferences.getInstance();

    final pets = await getPets();

    pets.add(pet);

    final encoded = json.encode(
      pets.map((e) => e.toJson()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }

  Future<void> updatePet(AdoptionPet updatedPet) async {
    final prefs = await SharedPreferences.getInstance();

    final pets = await getPets();

    final index = pets.indexWhere((p) => p.id == updatedPet.id);

    if (index == -1) {
      return;
    }

    pets[index] = updatedPet;

    final encoded = json.encode(
      pets.map((e) => e.toJson()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }

  Future<void> deletePet(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final pets = await getPets();

    pets.removeWhere((p) => p.id == id);

    final encoded = json.encode(
      pets.map((e) => e.toJson()).toList(),
    );

    await prefs.setString(_storageKey, encoded);
  }
}
