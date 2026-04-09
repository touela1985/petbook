import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lost_pet_report.dart';

class LostPetReportRepository {
  static const String _storageKey = 'lost_pet_reports';
  static const String _collection = 'lost_reports';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Local helpers ───────────────────────────────────────────────────────

  Future<Map<String, LostPetReport>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? json = prefs.getString(_storageKey);
    if (json == null || json.isEmpty) return {};

    final List<dynamic> decoded = jsonDecode(json);
    final reports = decoded.map((e) => LostPetReport.fromJson(e)).toList();
    return {for (final r in reports) r.id: r};
  }

  Future<void> _saveLocal(List<LostPetReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(reports.map((r) => r.toJson()).toList()),
    );
  }

  // ─── Firestore helpers ───────────────────────────────────────────────────

  Future<Map<String, LostPetReport>> _loadFirestore() async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('lastSeenDate', descending: true)
        .get();
    return {
      for (final doc in snapshot.docs)
        doc.id: LostPetReport.fromJson(doc.data())
    };
  }

  Future<void> _setFirestore(LostPetReport report) async {
    await _firestore
        .collection(_collection)
        .doc(report.id)
        .set(report.toJson());
  }

  Future<void> _deleteFirestore(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // ─── Public API ──────────────────────────────────────────────────────────

  Future<List<LostPetReport>> getReports() async {
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
    Map<String, LostPetReport> firestoreMap = {};
    try {
      firestoreMap = await _loadFirestore();
    } catch (_) {
      // offline or error — silent fallback to local only
    }

    // 4. Merge: local first, Firestore overrides on duplicate id
    final merged = {...localMap, ...firestoreMap};
    return merged.values.toList()
      ..sort((a, b) => b.lastSeenDate.compareTo(a.lastSeenDate));
  }

  LostPetReport _withUserId(LostPetReport r, String uid) => LostPetReport(
    id: r.id, petName: r.petName, type: r.type,
    lastSeenLocation: r.lastSeenLocation, lastSeenDate: r.lastSeenDate,
    notes: r.notes, contactPhone: r.contactPhone, isResolved: r.isResolved,
    photoPath: r.photoPath, photoUrl: r.photoUrl,
    latitude: r.latitude, longitude: r.longitude,
    createdAt: r.createdAt, sightings: r.sightings,
    userId: uid,
  );

  Future<void> saveReports(List<LostPetReport> reports) async {
    await _saveLocal(reports);
  }

  Future<void> addReport(LostPetReport report) async {
    // 1. Local
    final localMap = await _loadLocal();
    localMap[report.id] = report;
    await _saveLocal(localMap.values.toList());

    // 2. Firestore — silent fail
    try {
      await _setFirestore(report);
    } catch (_) {}
  }

  Future<void> updateReport(LostPetReport updatedReport) async {
    // 1. Local
    final localMap = await _loadLocal();
    localMap[updatedReport.id] = updatedReport;
    await _saveLocal(localMap.values.toList());

    // 2. Firestore — silent fail
    try {
      await _setFirestore(updatedReport);
    } catch (_) {}
  }

  Future<void> deleteReport(String reportId) async {
    // 1. Local
    final localMap = await _loadLocal();
    localMap.remove(reportId);
    await _saveLocal(localMap.values.toList());

    // 2. Firestore — silent fail
    try {
      await _deleteFirestore(reportId);
    } catch (_) {}
  }
}
