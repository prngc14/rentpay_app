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

      // PENDING PAYMENT LOCK
      "activePaymentId": null,
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
    DateTime now = DateTime.now();

    // DEFAULT DUE DATE
    DateTime dueDate = DateTime(
      now.year,
      now.month,
      5,
    );

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

      // PARTIAL PAYMENT TRACKING
      "amountPaid": 0,
      "remainingBalance": monthlyRent,
      "carriedOverBalance": 0,

      // PAYMENT
      "paymentStatus": "unpaid",
      "paidAt": null,

      // DUE DATE
      "dueDate": Timestamp.fromDate(dueDate),

      // OVERDUE
      "isOverdue": false,

      // BILLING MONTH
      "billingMonth": "${now.year}-${now.month.toString().padLeft(2, '0')}",

      // HISTORY
      "history": {},

      "createdAt": Timestamp.now(),
    });
  }

  // ===============================
  // UPDATE ROOM BILLING
  // ===============================
  // Bagong cycle = bagong rent+utilities bill, DAGDAG ang
  // natitirang unpaid balance mula sa nakaraang cycle
  // (rollover, parang Home Credit / GGives).
  // ===============================
  Future<void> updateRoomBilling({
    required String roomId,
    required double monthlyRent,
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

    // ELECTRIC
    double electricConsumption = currentElectric - previousElectric;

    double electricBill = electricConsumption * electricRate;

    // WATER
    double waterConsumption = currentWater - previousWater;

    double waterBill = waterConsumption * waterRate;

    // ===============================
    // ROLLOVER: dalhin ang natitirang unpaid
    // balance mula sa nakaraang cycle
    // ===============================
    double previousTotalBill = (data["totalBill"] ?? 0).toDouble();

    double previousAmountPaid = (data["amountPaid"] ?? 0).toDouble();

    String previousStatus = data["paymentStatus"] ?? "unpaid";

    double carriedOverBalance = previousStatus == "paid"
        ? 0
        : (previousTotalBill - previousAmountPaid);

    if (carriedOverBalance < 0) carriedOverBalance = 0;

    // TOTAL = bagong bill + carried-over na utang
    double totalBill =
        monthlyRent + electricBill + waterBill + carriedOverBalance;

    DateTime now = DateTime.now();

    // DUE DATE
    DateTime dueDate = DateTime(
      now.year,
      now.month,
      5,
    );

    // MONTH KEY
    String monthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    // UPDATE ROOM
    await _db.collection("rooms").doc(roomId).update({
      // RENT
      "monthlyRent": monthlyRent,

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

      // RESET PARTIAL PAYMENT TRACKING (bagong cycle)
      "amountPaid": 0,
      "remainingBalance": totalBill,
      "carriedOverBalance": carriedOverBalance,

      // RESET PAYMENT
      "paymentStatus": "unpaid",
      "paidAt": null,

      // DUE DATE
      "dueDate": Timestamp.fromDate(dueDate),

      // OVERDUE
      "isOverdue": false,

      // MONTH
      "billingMonth": monthKey,

      // HISTORY
      "history.$monthKey": {
        "month": monthKey,
        "monthlyRent": monthlyRent,
        "electricConsumption": electricConsumption,
        "waterConsumption": waterConsumption,
        "electricBill": electricBill,
        "waterBill": waterBill,
        "carriedOverBalance": carriedOverBalance,
        "totalBill": totalBill,
        "paymentStatus": "unpaid",
        "paidAt": null,
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
  // CALCULATE MINIMUM PAYMENT
  // ===============================
  // 50% ng totalBill, MALIBAN kung mas maliit na
  // ang natitirang balance (huling bahagi na lang) -
  // doon, ang buong natitira na lang ang minimum.
  // Ginagamit ng UI (Payment Screen) at ng
  // submitPayment() validation - iisang formula lang.
  // ===============================
  static double calculateMinimumPayment({
    required double totalBill,
    required double remainingBalance,
  }) {
    double half = totalBill * 0.5;
    return remainingBalance < half ? remainingBalance : half;
  }

  // ===============================
  // SUBMIT PAYMENT
  // ===============================
  // Gumagawa ng bagong payment doc, va-validate laban
  // sa kasalukuyang balance ng room (minimum 50%,
  // hindi pwedeng lumagpas sa natitira), at ise-set
  // ang activePaymentId sa tenant para i-gate papunta
  // sa PendingPaymentScreen. Ibinabalik ang payment doc ID.
  // ===============================
  Future<String> submitPayment(
    String tenantId,
    String ownerId,
    String room,
    double amount,
    String screenshotUrl,
  ) async {
    // FETCH CURRENT ROOM BALANCE
    final roomQuery = await _db
        .collection("rooms")
        .where("roomNumber", isEqualTo: room)
        .where("ownerId", isEqualTo: ownerId)
        .limit(1)
        .get();

    if (roomQuery.docs.isEmpty) {
      throw Exception("Room not found");
    }

    final roomData = roomQuery.docs.first.data();

    double totalBill = (roomData["totalBill"] ?? 0).toDouble();

    double amountPaid = (roomData["amountPaid"] ?? 0).toDouble();

    double remainingBalance = totalBill - amountPaid;

    if (remainingBalance < 0) remainingBalance = 0;

    if (remainingBalance <= 0) {
      throw Exception("Wala nang natitirang balanse na dapat bayaran");
    }

    double minimumRequired = calculateMinimumPayment(
      totalBill: totalBill,
      remainingBalance: remainingBalance,
    );

    if (amount <= 0) {
      throw Exception("Invalid na halaga ng bayad");
    }

    if (amount > remainingBalance + 0.01) {
      throw Exception(
        "Ang halaga ay lumampas sa natitirang balanse (₱${remainingBalance.toStringAsFixed(2)})",
      );
    }

    if (amount < minimumRequired - 0.01) {
      throw Exception(
        "Kailangan ng hindi bababa sa ₱${minimumRequired.toStringAsFixed(2)} (minimum payment)",
      );
    }

    DateTime now = DateTime.now();

    String paymentMonth =
        "${now.year}-${now.month.toString().padLeft(2, '0')}";

    bool isPartial = amount < remainingBalance - 0.01;

    final paymentRef = await _db.collection("payments").add({
      "tenantId": tenantId,
      "ownerId": ownerId,
      "room": room,
      "amount": amount,
      "screenshot": screenshotUrl,

      // STATUS
      "status": "pending",
      "isPartial": isPartial,

      // DATE
      "date": Timestamp.now(),

      // MONTH
      "paymentMonth": paymentMonth,
    });

    // LOCK: i-gate ang tenant papunta sa Pending Payment Screen
    await _db.collection("users").doc(tenantId).update({
      "activePaymentId": paymentRef.id,
    });

    return paymentRef.id;
  }

  // ===============================
  // APPROVE PAYMENT
  // ===============================
  // Kinukwenta kung buo na ba ang total bayad
  // (amountPaid + itong bagong payment) laban sa
  // totalBill. Kung buo na -> "paid" (manual Continue
  // sa Pending screen). Kung hindi pa -> "partial"
  // (awtomatikong nawawala ang lock, walang kailangang
  // i-tap na Continue - diretso balik sa Payments tab).
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

      double approvedAmount = (paymentData["amount"] ?? 0).toDouble();

      Timestamp approvedTime = Timestamp.now();

      String paymentMonth = paymentData["paymentMonth"] ?? "";

      // UPDATE PAYMENT DOC
      await _db.collection("payments").doc(paymentId).update({
        "status": "verified",
        "verifiedAt": approvedTime,
      });

      // FIND ROOM
      final roomQuery = await _db
          .collection("rooms")
          .where("roomNumber", isEqualTo: roomNumber)
          .where("tenantId", isEqualTo: tenantId)
          .limit(1)
          .get();

      String newStatus = "paid";

      if (roomQuery.docs.isNotEmpty) {
        final roomRef = roomQuery.docs.first.reference;
        final roomData = roomQuery.docs.first.data();

        double totalBill = (roomData["totalBill"] ?? 0).toDouble();

        double currentAmountPaid = (roomData["amountPaid"] ?? 0).toDouble();

        double newAmountPaid = currentAmountPaid + approvedAmount;

        if (newAmountPaid > totalBill) newAmountPaid = totalBill;

        double newRemaining = totalBill - newAmountPaid;

        if (newRemaining < 0) newRemaining = 0;

        bool isFull = newRemaining <= 0.01;

        newStatus = isFull ? "paid" : "partial";

        await roomRef.update({
          "amountPaid": newAmountPaid,
          "remainingBalance": newRemaining,
          "paymentStatus": newStatus,
          "paidAt": isFull ? approvedTime : null,
          "isOverdue": false,

          // HISTORY
          "history.$paymentMonth.paymentStatus": newStatus,
          "history.$paymentMonth.paidAt": isFull ? approvedTime : null,
          "history.$paymentMonth.amountPaid": newAmountPaid,
        });
      }

      // UPDATE USER
      await _db.collection("users").doc(tenantId).update({
        "approved": true,
        "paymentStatus": newStatus,
        "lastPaymentDate": approvedTime,
      });

      // ===============================
      // PARTIAL PAYMENT: awtomatikong i-unlock
      // (walang kailangang i-tap na "Continue")
      // FULL PAYMENT: mananatiling naka-lock hanggang
      // i-tap ang "Continue to Dashboard"
      // ===============================
      if (newStatus == "partial") {
        await _db.collection("users").doc(tenantId).update({
          "activePaymentId": null,
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
  // CLEAR ACTIVE PAYMENT (unlock dashboard)
  // ===============================
  // Tinatawag pagkatapos ng "Continue to Dashboard"
  // (full payment approved) o "Submit New Payment"
  // (rejected) sa PendingPaymentScreen.
  // ===============================
  Future<void> clearActivePayment(
    String tenantId,
  ) async {
    await _db.collection("users").doc(tenantId).update({
      "activePaymentId": null,
    });
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
  // CHECK OVERDUE
  // ===============================
  Future<void> checkOverdueRooms() async {
    final rooms = await _db.collection("rooms").get();

    DateTime now = DateTime.now();

    for (var room in rooms.docs) {
      final data = room.data();

      Timestamp? dueTimestamp = data["dueDate"];

      if (dueTimestamp == null) continue;

      DateTime dueDate = dueTimestamp.toDate();

      String paymentStatus = data["paymentStatus"] ?? "unpaid";

      bool overdue = now.isAfter(dueDate) && paymentStatus != "paid";

      await room.reference.update({
        "isOverdue": overdue,
      });
    }
  }

  static const List<String> _inactiveContractStatuses = [
    "Expired",
    "Cancelled",
    "Terminated",
  ];

  static DateTime _computeContractDueDate(
    DateTime contractStartDate,
    DateTime referenceDate,
  ) {
    final int dueDay = contractStartDate.day;
    final int year = referenceDate.year;
    final int month = referenceDate.month;
    final int lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final int day = dueDay <= lastDayOfMonth ? dueDay : lastDayOfMonth;

    return DateTime(year, month, day, 23, 59, 59);
  }

  Future<Map<String, dynamic>?> getActiveContractForTenant(
    String tenantId,
  ) async {
    final contractSnapshot = await _db
        .collection("contracts")
        .where("tenantId", isEqualTo: tenantId)
        .get();

    final activeContracts = contractSnapshot.docs.where((doc) {
      final data = doc.data();
      final status = data["status"] ?? "";
      return !_inactiveContractStatuses.contains(status);
    }).toList();

    if (activeContracts.isEmpty) return null;

    activeContracts.sort((a, b) {
      final aStart = (a.data()["startDate"] as Timestamp?)?.toDate();
      final bStart = (b.data()["startDate"] as Timestamp?)?.toDate();

      if (aStart == null && bStart == null) return 0;
      if (aStart == null) return 1;
      if (bStart == null) return -1;

      return bStart.compareTo(aStart);
    });

    return activeContracts.first.data() as Map<String, dynamic>;
  }

  Future<DateTime?> getNextContractDueDateForTenant(
    String tenantId,
  ) async {
    final contractData = await getActiveContractForTenant(tenantId);
    if (contractData == null) return null;

    final Timestamp? startTimestamp = contractData["startDate"];
    if (startTimestamp == null) return null;

    final DateTime contractStartDate = startTimestamp.toDate();
    final DateTime now = DateTime.now();

    if (now.isBefore(contractStartDate)) {
      return null;
    }

    return _computeContractDueDate(contractStartDate, now);
  }

  Future<bool> shouldSendContractDueNotification(
    String tenantId,
  ) async {
    final roomQuery = await _db
        .collection("rooms")
        .where("tenantId", isEqualTo: tenantId)
        .limit(1)
        .get();

    if (roomQuery.docs.isEmpty) {
      return false;
    }

    final roomData = roomQuery.docs.first.data();
    final String paymentStatus = roomData["paymentStatus"] ?? "unpaid";

    if (paymentStatus == "paid") return false;

    final DateTime? contractDueDate =
        await getNextContractDueDateForTenant(tenantId);

    if (contractDueDate == null) return false;

    final DateTime now = DateTime.now();
    return !now.isBefore(contractDueDate);
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
  // GET TENANT PAYMENTS (FOR OWNER VIEW)
  // ===============================
  // Kasama ang ownerId sa query mismo (hindi lang tenantId).
  // Kailangan ito para sa Firestore Security Rules -- sa LIST
  // queries, hindi tulad ng single-doc read, kailangang direktang
  // ma-verify ng rule ang pag-access GAMIT ANG QUERY MISMO, hindi
  // lang sa bawat resultang document. Dahil ang ownerId ang
  // sinusuri para sa access ng Owner, kailangan itong sumali sa
  // where() clause -- kaya hiwalay ito sa getTenantPayments() sa
  // itaas (na para naman sa Tenant mismo na tumitingin sa sarili
  // niyang history).
  // ===============================
  Stream<QuerySnapshot> getTenantPaymentsForOwner(
    String ownerId,
    String tenantId,
  ) {
    return _db
        .collection("payments")
        .where(
          "ownerId",
          isEqualTo: ownerId,
        )
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