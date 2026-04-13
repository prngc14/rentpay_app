import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===============================
  // EMAIL LOGIN
  // ===============================
  Future<User?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("LOGIN ERROR: $e");
      return null;
    }
  }

  // ===============================
  // EMAIL REGISTER
  // ===============================
  Future<User?> register(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user!;

      final doc = _db.collection("users").doc(user.uid);

      await doc.set({
        "uid": user.uid,
        "email": email,
        "role": "tenant",
        "createdAt": Timestamp.now(),
        "job": "",
        "phone": "",
        "paymentStatus": "unpaid",
        "gcashQr": null,
        "paymayaQr": null,
        "approved": false,
        "room": "",
        "ownerId": "",
        "ownerCode": "",
      });

      return user;
    } catch (e) {
      print("REGISTER ERROR: $e");
      return null;
    }
  }

  // ===============================
  // GOOGLE LOGIN (FIXED + AUTO FIRESTORE)
  // ===============================
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user!;

      final docRef = _db.collection("users").doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          "uid": user.uid,
          "email": user.email ?? "",
          "name": user.displayName ?? "",
          "role": "tenant",
          "createdAt": Timestamp.now(),
          "job": "",
          "phone": "",
          "paymentStatus": "unpaid",
          "gcashQr": null,
          "paymayaQr": null,
          "approved": false,
          "room": "",
          "ownerId": "",
          "ownerCode": "",
        });
      }

      return user;
    } catch (e) {
      print("GOOGLE LOGIN ERROR: $e");
      return null;
    }
  }

  // ===============================
  // LOGOUT
  // ===============================
  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}
