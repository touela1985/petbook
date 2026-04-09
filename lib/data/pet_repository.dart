import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet.dart';

class PetRepository {
  static const _storageKey = 'pets';
  static const _collection = 'pets';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Pet> _pets = [];

  List<Pet> getAll() => List.unmodifiable(_pets);

  // ─── Local helpers ───────────────────────────────────────────────────────

  Future<Map<String, Pet>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? petsJson = prefs.getStringList(_storageKey);
    if (petsJson == null) return {};

    final pets = petsJson
        .map((s) => Pet.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    return {for (final p in pets) p.id: p};
  }

  Future<void> _saveLocal(List<Pet> pets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      pets.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  // ─── Firestore helpers ───────────────────────────────────────────────────

  Future<Map<String, Pet>> _loadFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};
    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: uid)
        .get();
    return {
      for (final doc in snapshot.docs) doc.id: Pet.fromJson(doc.data())
    };
  }

  Future<void> _setFirestore(Pet pet) async {
    final data = pet.toJson();
    data.remove('photoBase64'); // avoid Firestore 1MB limit — photoUrl is used instead
    await _firestore.collection(_collection).doc(pet.id).set(data);
  }

  Future<void> _deleteFirestore(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // ─── Public API ──────────────────────────────────────────────────────────

  Future<void> loadPets() async {
    // 1. Local — always available, even offline
    final localMap = await _loadLocal();

    // 2. Auto-claim: assign uid to local records created before auth
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final unclaimed = localMap.entries
          .where((e) => e.value.userId == null)
          .toList();
      if (unclaimed.isNotEmpty) {
        for (final entry in unclaimed) {
          localMap[entry.key] = _withUserId(entry.value, uid);
        }
        await _saveLocal(localMap.values.toList());
        for (final entry in unclaimed) {
          try { await _setFirestore(localMap[entry.key]!); } catch (_) {}
        }
      }
    }

    // 3. Firestore — best-effort
    Map<String, Pet> firestoreMap = {};
    try {
      firestoreMap = await _loadFirestore();
    } catch (_) {
      // offline or error — silent fallback to local only
    }

    // 4. Merge: local first, Firestore overrides on duplicate id
    final merged = {...localMap, ...firestoreMap};
    _pets
      ..clear()
      ..addAll(merged.values);
  }

  Pet _withUserId(Pet p, String uid) => Pet(
    id: p.id, name: p.name, type: p.type, age: p.age, gender: p.gender,
    photoPath: p.photoPath, photoBase64: p.photoBase64, photoUrl: p.photoUrl,
    userId: uid,
  );

  Future<void> savePets() async {
    await _saveLocal(_pets);
  }

  Future<void> addPet({
    required String name,
    required String type,
    String? age,
    String? gender,
    String? photoPath,
    String? photoBase64,
    String? photoUrl,
    String? userId,
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
      userId: userId,
    );

    // 1. Local
    _pets.add(pet);
    await _saveLocal(_pets);

    // 2. Firestore — silent fail
    try {
      await _setFirestore(pet);
    } catch (_) {}
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
    String? userId,
  }) async {
    final index = _pets.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final updated = Pet(
      id: id,
      name: name,
      type: type,
      age: age,
      gender: gender,
      photoPath: photoPath,
      photoBase64: photoBase64,
      photoUrl: photoUrl,
      userId: userId,
    );

    // 1. Local
    _pets[index] = updated;
    await _saveLocal(_pets);

    // 2. Firestore — silent fail
    try {
      await _setFirestore(updated);
    } catch (_) {}
  }

  Future<void> deletePet(String id) async {
    // 1. Local
    _pets.removeWhere((p) => p.id == id);
    await _saveLocal(_pets);

    // 2. Firestore — silent fail
    try {
      await _deleteFirestore(id);
    } catch (_) {}
  }
}
