import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // LogIn function
  Future<User?> signIn(String email, String password) async {
    var user = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return user.user;
  }

  // Registration function
  Future<User?> signUp(String email, String password, String name) async {
    var userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // If registration is successful, save user data to Firestore
    if (userCredential.user != null) {
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': DateTime.now(),
        'settings': {'theme': 'dark', 'sidebarCollapsed': false},
      });
    }

    return userCredential.user;
  }

  // SignOut function
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
