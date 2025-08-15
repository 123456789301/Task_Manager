import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static bool get isLoggedIn => _auth.currentUser != null;

  static Future<void> signup(String email, String password, String name, String phone, String role) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _db.collection('users').doc(cred.user!.uid).set({
      'email': email, 'name': name, 'phone': phone, 'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> login(String email, String password) =>
    _auth.signInWithEmailAndPassword(email: email, password: password);

  static Future<void> logout() => _auth.signOut();

  static Future<String> fetchRole() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['role'] as String?) ?? 'employee';
  }

  static Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  static String? get currentUid => _auth.currentUser?.uid;
}
