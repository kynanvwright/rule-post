import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> register(String email, String password) async {
  try {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return null; // success
  } on FirebaseAuthException catch (e) {
    return e.message;
  }
}


  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get userChanges => _auth.userChanges();
}
