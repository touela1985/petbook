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

  /// Uploads lost pet report image bytes to Firebase Storage at path lost_pets/{reportId}.jpg.
  /// Returns the download URL on success, or null on failure (caller uses fallback).
  static Future<String?> uploadLostPetImage(
    Uint8List bytes,
    String reportId,
  ) async {
    try {
      final ref = _storage.ref().child('lost_pets/$reportId.jpg');
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await snapshot.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Uploads found pet report image bytes to Firebase Storage at path found_pets/{reportId}.jpg.
  /// Returns the download URL on success, or null on failure (caller uses fallback).
  static Future<String?> uploadFoundPetImage(
    Uint8List bytes,
    String reportId,
  ) async {
    try {
      final ref = _storage.ref().child('found_pets/$reportId.jpg');
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await snapshot.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Uploads adoption pet image bytes to Firebase Storage at path adoptions/{adoptionId}.jpg.
  /// Returns the download URL on success, or null on failure (caller uses fallback).
  static Future<String?> uploadAdoptionPetImage(
    Uint8List bytes,
    String adoptionId,
  ) async {
    try {
      final ref = _storage.ref().child('adoptions/$adoptionId.jpg');
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await snapshot.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Uploads community item image bytes to Firebase Storage at path community/{itemId}.jpg.
  /// Returns the download URL on success, or null on failure (caller uses fallback).
  static Future<String?> uploadCommunityImage(
    Uint8List bytes,
    String itemId,
  ) async {
    try {
      final ref = _storage.ref().child('community/$itemId.jpg');
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await snapshot.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Uploads profile photo bytes to Firebase Storage at path profiles/{profileId}.jpg.
  /// Returns the download URL on success, or null on failure (caller uses fallback).
  static Future<String?> uploadProfileImage(
    Uint8List bytes,
    String profileId,
  ) async {
    try {
      final ref = _storage.ref().child('profiles/$profileId.jpg');
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
