import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileData {
  final String name;
  final String location;
  final String phone;
  final String email;
  final String preferredContact;
  final String? photoBase64;
  final String? photoUrl;

  const ProfileData({
    required this.name,
    required this.location,
    required this.phone,
    required this.email,
    required this.preferredContact,
    this.photoBase64,
    this.photoUrl,
  });
}

class ProfileService {
  static const _collection = 'users';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // User-scoped key helper — prevents cross-account profile leakage.
  String _key(String base, String uid) => '${base}_$uid';

  // ─── Load ────────────────────────────────────────────────────────────────

  Future<ProfileData> load() async {
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();

    // 1. Local — scoped per user; empty if first login or after logout cleanup.
    final localName = uid != null ? (prefs.getString(_key('profile_name', uid)) ?? '') : '';
    final localLocation = uid != null ? (prefs.getString(_key('profile_location', uid)) ?? '') : '';
    final localPhone = uid != null ? (prefs.getString(_key('profile_phone', uid)) ?? '') : '';
    final localEmail = uid != null ? (prefs.getString(_key('profile_email', uid)) ?? '') : '';
    final localContact = uid != null ? (prefs.getString(_key('profile_preferred_contact', uid)) ?? 'all') : 'all';
    final localPhotoBase64 = uid != null ? prefs.getString(_key('profile_photo', uid)) : null;
    final localPhotoUrl = uid != null ? prefs.getString(_key('profile_photo_url', uid)) : null;

    // 2. Firestore — best-effort
    String? remoteName;
    String? remoteLocation;
    String? remotePhone;
    String? remoteEmail;
    String? remoteContact;
    String? remotePhotoUrl;

    try {
      if (uid != null) {
        final doc = await _firestore.collection(_collection).doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          remoteName = data['name'] as String?;
          remoteLocation = data['location'] as String?;
          remotePhone = data['phone'] as String?;
          remoteEmail = data['email'] as String?;
          remoteContact = data['preferredContact'] as String?;
          remotePhotoUrl = data['photoUrl'] as String?;
        }
      }
    } catch (_) {
      // offline or error — silent fallback to local
    }

    // 3. Merge: Firestore wins when field is non-empty, else local
    return ProfileData(
      name: _prefer(remoteName, localName),
      location: _prefer(remoteLocation, localLocation),
      phone: _prefer(remotePhone, localPhone),
      email: _prefer(remoteEmail, localEmail),
      preferredContact: _prefer(remoteContact, localContact),
      photoBase64: localPhotoBase64,   // always local only
      photoUrl: (remotePhotoUrl != null && remotePhotoUrl.isNotEmpty)
          ? remotePhotoUrl
          : localPhotoUrl,
    );
  }

  // ─── Save ────────────────────────────────────────────────────────────────

  Future<void> save({
    required String name,
    required String location,
    required String phone,
    required String email,
    required String preferredContact,
    String? photoBase64,
  }) async {
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();

    // 1. Local — user-scoped
    if (uid != null) {
      await prefs.setString(_key('profile_name', uid), name);
      await prefs.setString(_key('profile_location', uid), location);
      await prefs.setString(_key('profile_phone', uid), phone);
      await prefs.setString(_key('profile_email', uid), email);
      await prefs.setString(_key('profile_preferred_contact', uid), preferredContact);

      if (photoBase64 != null && photoBase64.isNotEmpty) {
        await prefs.setString(_key('profile_photo', uid), photoBase64);
      } else {
        await prefs.remove(_key('profile_photo', uid));
      }
    }

    // 2. Firestore — silent fail, no photoBase64
    try {
      if (uid != null) {
        await _firestore.collection(_collection).doc(uid).set({
          'name': name,
          'location': location,
          'phone': phone,
          'email': email,
          'preferredContact': preferredContact,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> savePhotoUrl(String photoUrl) async {
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();

    // 1. Local — user-scoped
    if (uid != null) {
      await prefs.setString(_key('profile_photo_url', uid), photoUrl);
    }

    // 2. Firestore — silent fail
    try {
      if (uid != null) {
        await _firestore.collection(_collection).doc(uid).set(
          {'photoUrl': photoUrl},
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  Future<void> saveFcmToken(String token) async {
    try {
      final uid = _uid;
      if (uid != null) {
        await _firestore.collection(_collection).doc(uid).set(
          {
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  Future<void> clearFcmToken() async {
    try {
      final uid = _uid;
      if (uid == null) return;
      await _firestore.collection(_collection).doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (_) {}
  }

  /// Clears all locally cached profile data for [uid].
  /// Called during logout — must receive uid before Firebase sign-out.
  Future<void> clearLocalData(String? uid) async {
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final base in [
      'profile_name',
      'profile_location',
      'profile_phone',
      'profile_email',
      'profile_preferred_contact',
      'profile_photo',
      'profile_photo_url',
    ]) {
      await prefs.remove(_key(base, uid));
    }
  }

  // ─── Helper ──────────────────────────────────────────────────────────────

  String _prefer(String? remote, String local) {
    if (remote != null && remote.isNotEmpty) return remote;
    return local;
  }
}
