import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import 'cloudinary_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===============================
  // CREATE USER
  // ===============================
  Future<void> createUser(
    UserModel user,
  ) async {
    await _db.collection("users").doc(user.uid).set({
      ...user.toMap(),

      // DEFAULT FIELDS
      "job": "",
      "phone": "",
      "paymentStatus": "unpaid",
      "lastPaymentDate": null,
      "gcashQr": null,
      "paymayaQr": null,

      // CONNECTION
      "ownerId": null,
      "room": "",
      "approved": false,
      "connected": false,
    });
  }

  // ===============================
  // GET OWNER BY CODE
  // ===============================
  Future<QueryDocumentSnapshot?> getOwnerByCode(
    String code,
  ) async {
    var query = await _db
        .collection("users")
        .where(
          "ownerCode",
          isEqualTo: code,
        )
        .where(
          "role",
          isEqualTo: "owner",
        )
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    return query.docs.first;
  }

  // ===============================
  // CONNECT TENANT USING OWNER CODE
  // ===============================
  Future<void> connectTenantByCode(
    String code,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        "User not logged in",
      );
    }

    var ownerQuery = await _db
        .collection("users")
        .where(
          "ownerCode",
          isEqualTo: code,
        )
        .where(
          "role",
          isEqualTo: "owner",
        )
        .limit(1)
        .get();

    if (ownerQuery.docs.isEmpty) {
      throw Exception(
        "Owner not found",
      );
    }

    final ownerDoc = ownerQuery.docs.first;

    final ownerId = ownerDoc.id;

    await _db.collection("users").doc(user.uid).update({
      "ownerId": ownerId,
      "connected": true,
      "approved": false,
    });
  }

  // ===============================
  // GET OWNER QR
  // ===============================
  Future<Map<String, dynamic>?> getOwnerQR(
    String ownerId,
  ) async {
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
      "gcashQr": gcashUrl,
      "paymayaQr": mayaUrl,
    });
  }

  // ===============================
  // GET CURRENT OWNER QR DATA
  // ===============================
  Future<Map<String, dynamic>?> getOwnerQrData() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    final doc = await _db.collection("users").doc(user.uid).get();

    if (!doc.exists) return null;

    return doc.data();
  }

  // ===============================
  // UPLOAD OWNER QR IMAGE
  // ===============================
  Future<void> uploadOwnerQr({
    required File file,
    required String type,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        "User not logged in",
      );
    }

    final imageUrl = await uploadToCloudinary(file);

    if (imageUrl == null) {
      throw Exception(
        "Cloudinary upload failed",
      );
    }

    if (type == "gcash") {
      await _db.collection("users").doc(user.uid).update({
        "gcashQr": imageUrl,
      });
    } else if (type == "maya") {
      await _db.collection("users").doc(user.uid).update({
        "paymayaQr": imageUrl,
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

      // RENT
      "monthlyRent": monthlyRent,

      // ELECTRIC
      "previousElectric": 0,
      "currentElectric": 0,
      "electricRate": 12,
      "electricConsumption": 0,
      "electricBill": 0,

      // WATER
      "previousWater": 0,
      "currentWater": 0,
      "waterRate": 30,
      "waterConsumption": 0,
      "waterBill": 0,

      // TOTAL
      "totalBill": monthlyRent,

      // PAYMENT STATUS
      "paymentStatus": "unpaid",
      "paidAt": null,

      // HISTORY
      "history": {},

      "createdAt": Timestamp.now(),
    });
  }

  // ===============================
  // UPDATE ROOM BILLING
  // ===============================
  Future<void> updateRoomBilling({
    required String roomId,
    required double previousElectric,
    required double currentElectric,
    required double previousWater,
    required double currentWater,
  }) async {
    final roomDoc = await _db.collection("rooms").doc(roomId).get();

    final data = roomDoc.data();

    if (data == null) return;

    double electricRate = (data["electricRate"] ?? 12).toDouble();

    double waterRate = (data["waterRate"] ?? 30).toDouble();

    double monthlyRent = (data["monthlyRent"] ?? 0).toDouble();

    // ELECTRIC
    double electricConsumption = currentElectric - previousElectric;

    double electricBill = electricConsumption * electricRate;

    // WATER
    double waterConsumption = currentWater - previousWater;

    double waterBill = waterConsumption * waterRate;

    // TOTAL
    double totalBill = monthlyRent + electricBill + waterBill;

    // MONTH KEY
    String monthKey =
        "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";

    // UPDATE ROOM
    await _db.collection("rooms").doc(roomId).update({
      // ELECTRIC
      "previousElectric": previousElectric,
      "currentElectric": currentElectric,
      "electricConsumption": electricConsumption,
      "electricBill": electricBill,

      // WATER
      "previousWater": previousWater,
      "currentWater": currentWater,
      "waterConsumption": waterConsumption,
      "waterBill": waterBill,

      // TOTAL
      "totalBill": totalBill,

      // RESET PAYMENT STATUS EVERY BILLING UPDATE
      "paymentStatus": "unpaid",
      "paidAt": null,

      // HISTORY
      "history.$monthKey": {
        "month": monthKey,
        "electricConsumption": electricConsumption,
        "waterConsumption": waterConsumption,
        "electricBill": electricBill,
        "waterBill": waterBill,
        "totalBill": totalBill,
      },
    });
  }

  // ===============================
  // GET OWNER ROOMS
  // ===============================
  Stream<QuerySnapshot> getOwnerRooms(
    String ownerId,
  ) {
    return _db
        .collection("rooms")
        .where(
          "ownerId",
          isEqualTo: ownerId,
        )
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
    try {
      // FIND OWNER
      var ownerQuery = await _db
          .collection("users")
          .where(
            "ownerCode",
            isEqualTo: ownerCode,
          )
          .where(
            "role",
            isEqualTo: "owner",
          )
          .limit(1)
          .get();

      if (ownerQuery.docs.isEmpty) {
        throw Exception(
          "Owner not found",
        );
      }

      String ownerId = ownerQuery.docs.first.id;

      // FIND ROOM
      var roomQuery = await _db
          .collection("rooms")
          .where(
            "roomNumber",
            isEqualTo: roomNumber,
          )
          .where(
            "ownerId",
            isEqualTo: ownerId,
          )
          .limit(1)
          .get();

      if (roomQuery.docs.isEmpty) {
        throw Exception(
          "Room does not exist",
        );
      }

      var roomDoc = roomQuery.docs.first;

      // CHECK OCCUPIED
      if (roomDoc["tenantId"] != null &&
          roomDoc["tenantId"].toString().isNotEmpty) {
        throw Exception(
          "Room already occupied",
        );
      }

      // SAVE TENANT
      await roomDoc.reference.update({
        "tenantId": tenantId,
        "paymentStatus": "unpaid",
        "paidAt": null,
      });

      // UPDATE TENANT
      await _db.collection("users").doc(tenantId).update({
        "room": roomNumber,
        "ownerId": ownerId,
        "approved": false,
        "paymentStatus": "unpaid",
        "lastPaymentDate": null,
        "connected": true,
      });
    } catch (e) {
      print("CONNECT ROOM ERROR: $e");

      rethrow;
    }
  }

  // ===============================
  // APPROVE TENANT
  // ===============================
  Future<void> approveTenant(
    String tenantId,
  ) async {
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
  Future<void> approvePayment(
    String paymentId,
    String tenantId,
  ) async {
    try {
      final paymentDoc = await _db.collection("payments").doc(paymentId).get();

      final paymentData = paymentDoc.data();

      if (paymentData == null) return;

      String roomNumber = paymentData["room"] ?? "";

      Timestamp paidTime = Timestamp.now();

      // UPDATE PAYMENT
      await _db.collection("payments").doc(paymentId).update({
        "status": "verified",
        "verifiedAt": paidTime,
      });

      // UPDATE USER
      await _db.collection("users").doc(tenantId).update({
        "approved": true,
        "paymentStatus": "paid",
        "lastPaymentDate": paidTime,
      });

      // FIND ROOM
      final roomQuery = await _db
          .collection("rooms")
          .where("roomNumber", isEqualTo: roomNumber)
          .where("tenantId", isEqualTo: tenantId)
          .limit(1)
          .get();

      if (roomQuery.docs.isNotEmpty) {
        await roomQuery.docs.first.reference.update({
          "paymentStatus": "paid",
          "paidAt": paidTime,
        });
      }
    } catch (e) {
      print("APPROVE PAYMENT ERROR: $e");
    }
  }

  // ===============================
  // REJECT PAYMENT
  // ===============================
  Future<void> rejectPayment(
    String paymentId,
  ) async {
    try {
      await _db.collection("payments").doc(paymentId).update({
        "status": "rejected",
      });
    } catch (e) {
      print("REJECT PAYMENT ERROR: $e");
    }
  }

  // ===============================
  // DELETE PAYMENT
  // ===============================
  Future<void> deletePayment(
    String paymentId,
  ) async {
    try {
      await _db.collection("payments").doc(paymentId).delete();
    } catch (e) {
      print("DELETE PAYMENT ERROR: $e");
    }
  }

  // ===============================
  // GET TENANT PAYMENTS
  // ===============================
  Stream<QuerySnapshot> getTenantPayments(
    String tenantId,
  ) {
    return _db
        .collection("payments")
        .where(
          "tenantId",
          isEqualTo: tenantId,
        )
        .orderBy(
          "date",
          descending: true,
        )
        .snapshots();
  }

  // ===============================
  // GET OWNER PAYMENTS
  // ===============================
  Stream<QuerySnapshot> getOwnerPayments(
    String ownerId,
  ) {
    return _db
        .collection("payments")
        .where(
          "ownerId",
          isEqualTo: ownerId,
        )
        .orderBy(
          "date",
          descending: true,
        )
        .snapshots();
  }

  // ===============================
  // GET OWNER TENANTS
  // ===============================
  Stream<QuerySnapshot> getOwnerTenants(
    String ownerId,
  ) {
    return _db
        .collection("users")
        .where(
          "ownerId",
          isEqualTo: ownerId,
        )
        .where(
          "role",
          isEqualTo: "tenant",
        )
        .snapshots();
  }

  // ===============================
  // GET CURRENT USER DATA
  // ===============================
  Stream<DocumentSnapshot> getCurrentUserData() {
    final user = _auth.currentUser;

    return _db.collection("users").doc(user!.uid).snapshots();
  }
}
