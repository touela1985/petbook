import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/found_pet_report.dart';

class FoundPetReportRepository {
  static const String _storageKey = 'found_pet_reports';
  static const String _collection = 'found_reports';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Local helpers ───────────────────────────────────────────────────────

  Future<Map<String, FoundPetReport>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? json = prefs.getString(_storageKey);
    if (json == null || json.isEmpty) return {};

    final List<dynamic> decoded = jsonDecode(json);
    final reports = decoded.map((e) => FoundPetReport.fromJson(e)).toList();
    return {for (final r in reports) r.id: r};
  }

  Future<void> _saveLocal(List<FoundPetReport> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(reports.map((r) => r.toJson()).toList()),
    );
  }

  // ─── Firestore helpers ───────────────────────────────────────────────────

  Future<Map<String, FoundPetReport>> _loadFirestore() async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('foundDate', descending: true)
        .get();
    return {
      for (final doc in snapshot.docs)
        doc.id: FoundPetReport.fromJson(doc.data())
    };
  }

  Future<void> _setFirestore(FoundPetReport report) async {
    await _firestore
        .collection(_collection)
        .doc(report.id)
        .set(report.toJson());
  }

  Future<void> _deleteFirestore(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // ─── Public API ──────────────────────────────────────────────────────────

  Future<List<FoundPetReport>> getReports() async {
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
    Map<String, FoundPetReport> firestoreMap = {};
    try {
      firestoreMap = await _loadFirestore();
    } catch (_) {
      // offline or error — silent fallback to local only
    }

    // 4. Merge: local first, Firestore overrides on duplicate id
    final merged = {...localMap, ...firestoreMap};
    return merged.values.toList()
      ..sort((a, b) => b.foundDate.compareTo(a.foundDate));
  }

  FoundPetReport _withUserId(FoundPetReport r, String uid) => FoundPetReport(
    id: r.id, type: r.type, locationFound: r.locationFound,
    foundDate: r.foundDate, notes: r.notes, contactPhone: r.contactPhone,
    isResolved: r.isResolved, photoPath: r.photoPath, photoUrl: r.photoUrl,
    latitude: r.latitude, longitude: r.longitude,
    userId: uid,
  );

  Future<FoundPetReport?> getReportById(String id) async {
    // 1. Firestore — single document fetch
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) return FoundPetReport.fromJson(doc.data()!);
    } catch (_) {}

    // 2. Local fallback
    final localMap = await _loadLocal();
    return localMap[id];
  }

  Future<void> saveReports(List<FoundPetReport> reports) async {
    await _saveLocal(reports);
  }

  Future<void> addReport(FoundPetReport report) async {
    // 1. Local
    final localMap = await _loadLocal();
    localMap[report.id] = report;
    await _saveLocal(localMap.values.toList());

    // 2. Firestore — silent fail
    try {
      await _setFirestore(report);
    } catch (_) {}
  }

  Future<void> updateReport(FoundPetReport updatedReport) async {
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
