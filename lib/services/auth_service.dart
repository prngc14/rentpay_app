import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===============================
  // LOGIN
  // ===============================
  Future<User?> login(String email, String password) async {
    try {
      var userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      return null;
    }
  }

  // ===============================
  // REGISTER (🔥 FIXED)
  // ===============================
  Future<User?> register(String email, String password) async {
    try {
      var userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User user = userCredential.user!;

      // ✅ SAVE TO FIRESTORE (IMPORTANT)
      await _db.collection("users").doc(user.uid).set({
        "email": email,
        "role": "tenant", // 🔥 DEFAULT ROLE
        "createdAt": Timestamp.now(),

        // default fields
        "job": "",
        "phone": "",
        "paymentStatus": "unpaid",
        "gcashQr": null,
        "paymayaQr": null,
        "approved": false,
        "room": "",
        "ownerId": "",
      });

      await user.sendEmailVerification();

      return user;
    } catch (e) {
      print("REGISTER ERROR: $e");
      return null;
    }
  }

  // ===============================
  // GET USER ROLE (🔥 ADD THIS)
  // ===============================
  Future<String?> getUserRole(String uid) async {
    try {
      var doc = await _db.collection("users").doc(uid).get();

      if (!doc.exists) return null;

      var data = doc.data() as Map<String, dynamic>;

      return data['role'];
    } catch (e) {
      print("GET ROLE ERROR: $e");
      return null;
    }
  }

  // ===============================
  // FORGOT PASSWORD
  // ===============================
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ===============================
  // LOGOUT
  // ===============================
  Future<void> logout() async {
    await _auth.signOut();
  }
}
