import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final _storage = FirebaseStorage.instance;

  /// Uploads pet image bytes to Firebase Storage at path pets/{petId}.jpg.
  /// Returns the download URL on success, or null on failure (caller uses fallback).
  static Future<String?> uploadPetImage(
    Uint8List bytes,
    String petId,
  ) async {
    try {
      final ref = _storage.ref().child('pets/$petId.jpg');
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await snapshot.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }
}
