import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lost_pet_report.dart';

class LostSightingRepository {
  static const String _collection = 'lost_sightings';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Αποθηκεύει θέαση στο ξεχωριστό collection `lost_sightings`.
  /// Ο submittedByUserId αποθηκεύεται μαζί για μελλοντικούς ελέγχους.
  Future<void> addSighting({
    required String reportId,
    required LostPetSighting sighting,
    required String submittedByUserId,
  }) async {
    final data = {
      ...sighting.toJson(),
      'reportId': reportId,
      'submittedByUserId': submittedByUserId,
    };
    await _firestore.collection(_collection).doc(sighting.id).set(data);
  }

  /// Επιστρέφει όλες τις θεάσεις για ένα report, ταξινομημένες νεότερη πρώτη.
  Future<List<LostPetSighting>> getSightingsForReport(String reportId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('reportId', isEqualTo: reportId)
        .get();

    final sightings = snapshot.docs
        .map((doc) => LostPetSighting.fromJson(doc.data()))
        .toList();
    sightings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sightings;
  }

  /// Διαγράφει θέαση από το collection.
  Future<void> deleteSighting(String sightingId) async {
    await _firestore.collection(_collection).doc(sightingId).delete();
  }
}
