import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet.dart';

class PetRepository {
  static const _key = 'pets';
  final List<Pet> _pets = [];

  List<Pet> getAll() => List.unmodifiable(_pets);

  Future<void> loadPets() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? petsJson = prefs.getStringList(_key);
    if (petsJson == null) return;

    _pets
      ..clear()
      ..addAll(
        petsJson.map(
          (s) => Pet.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );
  }

  Future<void> savePets() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> petsJson =
        _pets.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_key, petsJson);
  }

  Future<void> addPet({
    required String name,
    required String type,
    String? age,
    String? gender,
    String? photoPath,
    String? photoBase64,
    String? photoUrl,
  }) async {
    final pet = Pet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: type,
      age: age,
      gender: gender,
      photoPath: photoPath,
      photoBase64: photoBase64,
      photoUrl: photoUrl,
    );
    _pets.add(pet);
    await savePets();
  }

  Future<void> updatePet({
    required String id,
    required String name,
    required String type,
    String? age,
    String? gender,
    String? photoPath,
    String? photoBase64,
    String? photoUrl,
  }) async {
    final index = _pets.indexWhere((p) => p.id == id);
    if (index == -1) return;

    _pets[index] = Pet(
      id: id,
      name: name,
      type: type,
      age: age,
      gender: gender,
      photoPath: photoPath,
      photoBase64: photoBase64,
      photoUrl: photoUrl,
    );

    await savePets();
  }

  Future<void> deletePet(String id) async {
    _pets.removeWhere((p) => p.id == id);
    await savePets();
  }
}
