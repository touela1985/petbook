import 'package:firebase_auth/firebase_auth.dart';

import 'profile_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<String?> signUpWithEmailPassword(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // επιτυχία
    } on FirebaseAuthException catch (e) {
      return _mapErrorCode(e.code);
    } catch (_) {
      return 'Προέκυψε σφάλμα. Δοκίμασε ξανά.';
    }
  }

  Future<String?> signInWithEmailPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // επιτυχία
    } on FirebaseAuthException catch (e) {
      return _mapErrorCode(e.code);
    } catch (_) {
      return 'Προέκυψε σφάλμα. Δοκίμασε ξανά.';
    }
  }

  Future<void> signOut() async {
    await ProfileService().clearFcmToken();
    await _auth.signOut();
  }

  String _mapErrorCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Μη έγκυρο email.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Λανθασμένο email ή κωδικός.';
      case 'email-already-in-use':
        return 'Το email χρησιμοποιείται ήδη.';
      case 'weak-password':
        return 'Ο κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες.';
      case 'network-request-failed':
        return 'Δεν υπάρχει σύνδεση δικτύου.';
      case 'too-many-requests':
        return 'Πολλές αποτυχημένες προσπάθειες. Δοκίμασε αργότερα.';
      default:
        return 'Προέκυψε σφάλμα. Δοκίμασε ξανά.';
    }
  }
}
