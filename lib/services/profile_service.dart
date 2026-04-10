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

  // ─── Load ────────────────────────────────────────────────────────────────

  Future<ProfileData> load() async {
    // 1. Local — always available
    final prefs = await SharedPreferences.getInstance();
    final localName = prefs.getString('profile_name') ?? '';
    final localLocation = prefs.getString('profile_location') ?? '';
    final localPhone = prefs.getString('profile_phone') ?? '';
    final localEmail = prefs.getString('profile_email') ?? '';
    final localContact = prefs.getString('profile_preferred_contact') ?? 'all';
    final localPhotoBase64 = prefs.getString('profile_photo');
    final localPhotoUrl = prefs.getString('profile_photo_url');

    // 2. Firestore — best-effort
    String? remoteName;
    String? remoteLocation;
    String? remotePhone;
    String? remoteEmail;
    String? remoteContact;
    String? remotePhotoUrl;

    try {
      final uid = _uid;
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
    // 1. Local
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', name);
    await prefs.setString('profile_location', location);
    await prefs.setString('profile_phone', phone);
    await prefs.setString('profile_email', email);
    await prefs.setString('profile_preferred_contact', preferredContact);

    if (photoBase64 != null && photoBase64.isNotEmpty) {
      await prefs.setString('profile_photo', photoBase64);
    } else {
      await prefs.remove('profile_photo');
    }

    // 2. Firestore — silent fail, no photoBase64
    try {
      final uid = _uid;
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
    // 1. Local
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_photo_url', photoUrl);

    // 2. Firestore — silent fail
    try {
      final uid = _uid;
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

  // ─── Helper ──────────────────────────────────────────────────────────────

  String _prefer(String? remote, String local) {
    if (remote != null && remote.isNotEmpty) return remote;
    return local;
  }
}
