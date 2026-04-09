import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/adoption_pet.dart';

class AdoptionPetRepository {
  static const _storageKey = 'adoption_pets';
  static const _collection = 'adoption_pets';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Local helpers ───────────────────────────────────────────────────────

  Future<Map<String, AdoptionPet>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return {};

    final List decoded = json.decode(jsonString);
    final pets = decoded.map((e) => AdoptionPet.fromJson(e)).toList();
    return {for (final p in pets) p.id: p};
  }

  Future<void> _saveLocal(Map<String, AdoptionPet> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      json.encode(map.values.map((p) => p.toJson()).toList()),
    );
  }

  // ─── Firestore helpers ───────────────────────────────────────────────────

  Future<Map<String, AdoptionPet>> _loadFirestore() async {
    final snapshot = await _firestore.collection(_collection).get();
    return {
      for (final doc in snapshot.docs)
        doc.id: AdoptionPet.fromJson(doc.data())
    };
  }

  Future<void> _setFirestore(AdoptionPet pet) async {
    await _firestore.collection(_collection).doc(pet.id).set(pet.toJson());
  }

  Future<void> _deleteFirestore(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // ─── Public API ──────────────────────────────────────────────────────────

  Future<List<AdoptionPet>> getPets() async {
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
        await _saveLocal(localMap);
        for (final entry in unclaimed) {
          try { await _setFirestore(localMap[entry.key]!); } catch (_) {}
        }
      }
    }

    // 3. Firestore — best-effort
    Map<String, AdoptionPet> firestoreMap = {};
    try {
      firestoreMap = await _loadFirestore();
    } catch (_) {
      // offline or error — silent fallback to local only
    }

    // 4. Merge: local first, Firestore overrides on duplicate id
    final merged = {...localMap, ...firestoreMap};
    return merged.values.toList();
  }

  AdoptionPet _withUserId(AdoptionPet p, String uid) => AdoptionPet(
    id: p.id, name: p.name, type: p.type, age: p.age,
    location: p.location, description: p.description,
    contactPhone: p.contactPhone, photoPath: p.photoPath,
    photoUrl: p.photoUrl, adopted: p.adopted,
    userId: uid,
  );

  Future<void> addPet(AdoptionPet pet) async {
    // 1. Local
    final localMap = await _loadLocal();
    localMap[pet.id] = pet;
    await _saveLocal(localMap);

    // 2. Firestore — silent fail
    try {
      await _setFirestore(pet);
    } catch (_) {}
  }

  Future<void> updatePet(AdoptionPet updatedPet) async {
    // 1. Local
    final localMap = await _loadLocal();
    localMap[updatedPet.id] = updatedPet;
    await _saveLocal(localMap);

    // 2. Firestore — silent fail
    try {
      await _setFirestore(updatedPet);
    } catch (_) {}
  }

  Future<void> deletePet(String id) async {
    // 1. Local
    final localMap = await _loadLocal();
    localMap.remove(id);
    await _saveLocal(localMap);

    // 2. Firestore — silent fail
    try {
      await _deleteFirestore(id);
    } catch (_) {}
  }
}
