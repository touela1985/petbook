import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<String?> signUpWithEmailPassword(
    String email,
    String password, {
    bool isEl = false,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorCode(e.code, isEl: isEl);
    } catch (_) {
      return isEl ? 'Προέκυψε σφάλμα. Δοκίμασε ξανά.' : 'An error occurred. Please try again.';
    }
  }

  Future<String?> signInWithEmailPassword(
    String email,
    String password, {
    bool isEl = false,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorCode(e.code, isEl: isEl);
    } catch (_) {
      return isEl ? 'Προέκυψε σφάλμα. Δοκίμασε ξανά.' : 'An error occurred. Please try again.';
    }
  }

  Future<String?> sendPasswordResetEmail(String email, {bool isEl = false}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorCode(e.code, isEl: isEl);
    } catch (_) {
      return isEl ? 'Προέκυψε σφάλμα. Δοκίμασε ξανά.' : 'An error occurred. Please try again.';
    }
  }

  Future<void> signOut() async {
    // Capture uid before any sign-out step invalidates auth state.
    final uid = _auth.currentUser?.uid;

    // 1. Remove FCM token from Firestore so no more notifications are sent.
    await ProfileService().clearFcmToken();

    // 2. Clear locally cached profile data for this user.
    await ProfileService().clearLocalData(uid);

    // 3. Clear Firestore-backed local caches (safe to delete — Firestore is source of truth).
    await _clearLocalCaches(uid);

    // 4. Sign out from Firebase Auth.
    await _auth.signOut();
  }

  Future<void> _clearLocalCaches(String? uid) async {
    final prefs = await SharedPreferences.getInstance();

    // User-scoped caches.
    if (uid != null) {
      await prefs.remove('pets_$uid');
    }

    // Global caches backed by Firestore — safe to clear, will reload on next login.
    await prefs.remove('lost_pet_reports');
    await prefs.remove('found_pet_reports');
    await prefs.remove('adoption_pets');
    await prefs.remove('lost_pet_messages');
    await prefs.remove('found_pet_messages');

    // NOTE: 'community_places' / 'community_tips' are LOCAL-ONLY — do NOT clear on logout.
    // NOTE: 'pet_health_events' is LOCAL-ONLY — isolation handled via userId field filtering.
  }

  String _mapErrorCode(String code, {bool isEl = false}) {
    switch (code) {
      case 'invalid-email':
        return isEl ? 'Μη έγκυρο email.' : 'Invalid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return isEl ? 'Λανθασμένο email ή κωδικός.' : 'Incorrect email or password.';
      case 'email-already-in-use':
        return isEl ? 'Το email χρησιμοποιείται ήδη.' : 'This email is already in use.';
      case 'weak-password':
        return isEl
            ? 'Ο κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες.'
            : 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return isEl ? 'Δεν υπάρχει σύνδεση δικτύου.' : 'No network connection.';
      case 'too-many-requests':
        return isEl
            ? 'Πολλές αποτυχημένες προσπάθειες. Δοκίμασε αργότερα.'
            : 'Too many failed attempts. Try again later.';
      default:
        return isEl ? 'Προέκυψε σφάλμα. Δοκίμασε ξανά.' : 'An error occurred. Please try again.';
    }
  }
}
