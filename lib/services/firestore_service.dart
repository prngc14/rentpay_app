import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===============================
  // CREATE USER
  // ===============================
  Future<void> createUser(UserModel user) async {
    await _db.collection("users").doc(user.uid).set({
      ...user.toMap(),

      // ✅ DEFAULT FIELDS (VERY IMPORTANT)
      "job": "",
      "phone": "",
      "paymentStatus": "unpaid",
      "gcashQR": null,
      "mayaQR": null,
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
  // SAVE OWNER QR
  // ===============================
  Future<void> saveOwnerQR(
    String ownerId,
    String? gcashUrl,
    String? mayaUrl,
  ) async {
    await _db.collection("users").doc(ownerId).update({
      "gcashQR": gcashUrl,
      "mayaQR": mayaUrl,
    });
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
  ) async {
    var query = await _db
        .collection("rooms")
        .where("roomNumber", isEqualTo: roomNumber)
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception("Room not found");

    var roomDoc = query.docs.first;

    await roomDoc.reference.update({
      "tenantId": tenantId,
    });

    String ownerId = roomDoc["ownerId"];

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
  // UPDATE TENANT PROFILE ✅ FIXED
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
