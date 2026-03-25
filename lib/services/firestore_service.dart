import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ===============================
  // CREATE USER
  // ===============================
  Future<void> createUser(UserModel user) async {
    await _db.collection("users").doc(user.uid).set({
      ...user.toMap(),

      // DEFAULT FIELDS
      "job": "",
      "phone": "",
      "paymentStatus": "unpaid",
      "gcashQr": null,
      "paymayaQr": null,
    });
  }

  // ===============================
  // GET OWNER BY CODE
  // ===============================
  Future<QueryDocumentSnapshot?> getOwnerByCode(String code) async {
    var query = await _db
        .collection("users")
        .where("ownerCode", isEqualTo: code)
        .where("role", isEqualTo: "owner")
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }

  // ===============================
  // GET OWNER QR
  // ===============================
  Future<Map<String, dynamic>?> getOwnerQR(String ownerId) async {
    var doc = await _db.collection("users").doc(ownerId).get();

    if (!doc.exists) return null;
    return doc.data();
  }

  // ===============================
  // SAVE OWNER QR (OLD METHOD - KEEPING THIS)
  // ===============================
  Future<void> saveOwnerQR(
    String ownerId,
    String? gcashUrl,
    String? mayaUrl,
  ) async {
    await _db.collection("users").doc(ownerId).update({
      "gcashQr": gcashUrl,
      "paymayaQr": mayaUrl,
    });
  }

  // ===============================
  // NEW: GET CURRENT OWNER QR DATA
  // Used by upload_qr_screen.dart
  // ===============================
  Future<Map<String, dynamic>?> getOwnerQrData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection("users").doc(user.uid).get();

    if (!doc.exists) return null;
    return doc.data();
  }

  // ===============================
  // NEW: UPLOAD OWNER QR IMAGE
  // Used by upload_qr_screen.dart
  // ===============================
  Future<void> uploadOwnerQr({
    required File file,
    required String type,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final fileName = "${type}_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final ref = _storage.ref().child("owner_qr/${user.uid}/$fileName");

    await ref.putFile(file);
    final downloadUrl = await ref.getDownloadURL();

    if (type == "gcash") {
      await _db.collection("users").doc(user.uid).update({
        "gcashQr": downloadUrl,
      });
    } else if (type == "maya") {
      await _db.collection("users").doc(user.uid).update({
        "paymayaQr": downloadUrl,
      });
    }
  }

  // ===============================
  // CREATE ROOM
  // ===============================
  Future<void> createRoom(
    String roomNumber,
    String ownerId,
    double monthlyRent,
  ) async {
    await _db.collection("rooms").add({
      "roomNumber": roomNumber,
      "ownerId": ownerId,
      "tenantId": null,
      "monthlyRent": monthlyRent,
      "createdAt": Timestamp.now(),
    });
  }

  // ===============================
  // GET OWNER ROOMS
  // ===============================
  Stream<QuerySnapshot> getOwnerRooms(String ownerId) {
    return _db
        .collection("rooms")
        .where("ownerId", isEqualTo: ownerId)
        .snapshots();
  }

  // ===============================
  // CONNECT TENANT TO ROOM
  // ===============================
  Future<void> connectTenantToRoom(
    String roomNumber,
    String tenantId,
    String ownerCode,
  ) async {
    var ownerQuery = await _db
        .collection("users")
        .where("ownerCode", isEqualTo: ownerCode)
        .where("role", isEqualTo: "owner")
        .limit(1)
        .get();

    if (ownerQuery.docs.isEmpty) {
      throw Exception("Owner not found");
    }

    String ownerId = ownerQuery.docs.first.id;

    var roomQuery = await _db
        .collection("rooms")
        .where("roomNumber", isEqualTo: roomNumber)
        .where("ownerId", isEqualTo: ownerId)
        .limit(1)
        .get();

    if (roomQuery.docs.isEmpty) {
      throw Exception("Room not found for this owner");
    }

    var roomDoc = roomQuery.docs.first;

    await roomDoc.reference.update({
      "tenantId": tenantId,
    });

    await _db.collection("users").doc(tenantId).update({
      "room": roomNumber,
      "ownerId": ownerId,
      "approved": false,
      "paymentStatus": "unpaid",
    });
  }

  // ===============================
  // APPROVE TENANT
  // ===============================
  Future<void> approveTenant(String tenantId) async {
    await _db.collection("users").doc(tenantId).update({
      "approved": true,
    });
  }

  // ===============================
  // UPDATE TENANT PROFILE
  // ===============================
  Future<void> updateTenantInfo(
    String tenantId,
    String name,
    String job,
    String phone,
  ) async {
    await _db.collection("users").doc(tenantId).update({
      "name": name,
      "job": job,
      "phone": phone,
    });
  }

  // ===============================
  // SUBMIT PAYMENT
  // ===============================
  Future<void> submitPayment(
    String tenantId,
    String ownerId,
    String room,
    double amount,
    String screenshotUrl,
  ) async {
    await _db.collection("payments").add({
      "tenantId": tenantId,
      "ownerId": ownerId,
      "room": room,
      "amount": amount,
      "screenshot": screenshotUrl,
      "status": "pending",
      "date": Timestamp.now(),
    });
  }

  // ===============================
  // APPROVE PAYMENT
  // ===============================
  Future<void> approvePayment(String paymentId, String tenantId) async {
    await _db.collection("payments").doc(paymentId).update({
      "status": "verified",
    });

    await _db.collection("users").doc(tenantId).update({
      "paymentStatus": "paid",
    });
  }

  // ===============================
  // REJECT PAYMENT
  // ===============================
  Future<void> rejectPayment(String paymentId) async {
    await _db.collection("payments").doc(paymentId).update({
      "status": "rejected",
    });
  }

  // ===============================
  // GET TENANT PAYMENTS
  // ===============================
  Stream<QuerySnapshot> getTenantPayments(String tenantId) {
    return _db
        .collection("payments")
        .where("tenantId", isEqualTo: tenantId)
        .orderBy("date", descending: true)
        .snapshots();
  }

  // ===============================
  // GET OWNER PAYMENTS
  // ===============================
  Stream<QuerySnapshot> getOwnerPayments(String ownerId) {
    return _db
        .collection("payments")
        .where("ownerId", isEqualTo: ownerId)
        .orderBy("date", descending: true)
        .snapshots();
  }

  // ===============================
  // GET OWNER TENANTS
  // ===============================
  Stream<QuerySnapshot> getOwnerTenants(String ownerId) {
    return _db
        .collection("users")
        .where("ownerId", isEqualTo: ownerId)
        .where("role", isEqualTo: "tenant")
        .snapshots();
  }
}
