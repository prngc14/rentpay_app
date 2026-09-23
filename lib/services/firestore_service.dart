import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import 'cloudinary_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // CREATE USER
  Future<void> createUser(
    UserModel user,
  ) async {
    await _db.collection("users").doc(user.uid).set({
      ...user.toMap(),
      "job": "",
      "phone": "",
      "paymentStatus": "unpaid",
      "lastPaymentDate": null,
      "gcashQr": null,
      "paymayaQr": null,
      "ownerId": null,
      "room": "",
      "connected": false,
      "activePaymentId": null,
    });
  }

  // GET OWNER BY CODE
  Future<QueryDocumentSnapshot?> getOwnerByCode(
    String code,
  ) async {
    var query = await _db
        .collection("users")
        .where("ownerCode", isEqualTo: code)
        .where("role", isEqualTo: "owner")
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    return query.docs.first;
  }

  // CONNECT TENANT USING OWNER CODE
  Future<void> connectTenantByCode(
    String code,
  ) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    var ownerQuery = await _db
        .collection("users")
        .where("ownerCode", isEqualTo: code)
        .where("role", isEqualTo: "owner")
        .limit(1)
        .get();

    if (ownerQuery.docs.isEmpty) {
      throw Exception("Owner not found");
    }

    final ownerDoc = ownerQuery.docs.first;

    final ownerId = ownerDoc.id;

    await _db.collection("users").doc(user.uid).update({
      "ownerId": ownerId,
      "connected": true,
      "approved": false,
    });
  }

  // GET OWNER QR
  Future<Map<String, dynamic>?> getOwnerQR(
    String ownerId,
  ) async {
    var doc = await _db.collection("users").doc(ownerId).get();

    if (!doc.exists) return null;

    return doc.data();
  }

  // SAVE OWNER QR
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

  // GET CURRENT OWNER QR DATA
  Future<Map<String, dynamic>?> getOwnerQrData() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    final doc = await _db.collection("users").doc(user.uid).get();

    if (!doc.exists) return null;

    return doc.data();
  }

  // UPLOAD OWNER QR IMAGE
  Future<void> uploadOwnerQr({
    required File file,
    required String type,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not logged in");
    }

    final imageUrl = await uploadToCloudinary(file);

    if (imageUrl == null) {
      throw Exception("Cloudinary upload failed");
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

  // CREATE ROOM
  Future<void> createRoom(
    String roomNumber,
    String ownerId,
    double monthlyRent,
  ) async {
    DateTime now = DateTime.now();

    DateTime dueDate = DateTime(now.year, now.month, 5);

    await _db.collection("rooms").add({
      "roomNumber": roomNumber,
      "ownerId": ownerId,
      "tenantId": null,
      "monthlyRent": monthlyRent,
      "previousElectric": 0,
      "currentElectric": 0,
      "electricRate": 12,
      "electricConsumption": 0,
      "electricBill": 0,
      "previousWater": 0,
      "currentWater": 0,
      "waterRate": 30,
      "waterConsumption": 0,
      "waterBill": 0,
      "totalBill": monthlyRent,
      "amountPaid": 0,
      "remainingBalance": monthlyRent,
      "carriedOverBalance": 0,
      "paymentStatus": "unpaid",
      "paidAt": null,
      "dueDate": Timestamp.fromDate(dueDate),
      "isOverdue": false,
      "billingMonth": "${now.year}-${now.month.toString().padLeft(2, '0')}",
      "history": {},
      "createdAt": Timestamp.now(),
    });
  }

  // UPDATE ROOM BILLING WITH MONTHLY HISTORY
  //
  // Bawat update ng owner ay BAGONG BILL: ang babayaran ng tenant ay ang
  // bagong total na inilagay ng owner, at nagre-reset sa 0 ang amountPaid.
  // Hindi dinededuct sa bagong bill ang mga nakaraang bayad. (Nasa
  // "payments" collection pa rin ang lahat ng nakaraang bayad ng tenant,
  // kaya hindi nawawala ang record.)
  //
  // Bagong buwan   -> ini-archive ang nakaraang buwan sa history, at ang
  //                   hindi pa nababayaran ay nagiging carriedOverBalance.
  // Parehong buwan -> hindi nadodoble ang carriedOverBalance: kapag "paid"
  //                   na ang huling bill, 0 na ito (bayad na); kung hindi,
  //                   nananatili ang dating carriedOverBalance.
  Future<void> updateRoomBilling({
    required String roomId,
    required double monthlyRent,
    required double previousElectric,
    required double currentElectric,
    required double previousWater,
    required double currentWater,
  }) async {
    final roomRef = _db.collection("rooms").doc(roomId);
    final roomDoc = await roomRef.get();
    final data = roomDoc.data();

    if (data == null) return;

    final double electricRate = (data["electricRate"] ?? 12).toDouble();

    final double waterRate = (data["waterRate"] ?? 30).toDouble();

    final double electricConsumption = currentElectric - previousElectric;

    final double electricBill = electricConsumption * electricRate;

    final double waterConsumption = currentWater - previousWater;

    final double waterBill = waterConsumption * waterRate;

    final double previousTotalBill = (data["totalBill"] ?? 0).toDouble();

    final double previousAmountPaid = (data["amountPaid"] ?? 0).toDouble();

    final double previousCarriedOver =
        (data["carriedOverBalance"] ?? 0).toDouble();

    final String previousStatus =
        (data["paymentStatus"] ?? "unpaid").toString();

    final String previousBillingMonth = (data["billingMonth"] ?? "").toString();

    final DateTime now = DateTime.now();

    final DateTime dueDate = DateTime(now.year, now.month, 5);

    final String currentMonthKey =
        "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final bool isSameMonth = previousBillingMonth == currentMonthKey;

    double carriedOverBalance;

    if (isSameMonth) {
      // Same-month edit: kung bayad na ang huling bill, bayad na rin ang
      // carry-over nito, kaya hindi na ito isasama ulit.
      carriedOverBalance = previousStatus == "paid" ? 0 : previousCarriedOver;
    } else {
      // New month: unpaid balance moves forward.
      carriedOverBalance =
          previousStatus == "paid" ? 0 : previousTotalBill - previousAmountPaid;
    }

    if (carriedOverBalance < 0) {
      carriedOverBalance = 0;
    }

    final double totalBill =
        monthlyRent + electricBill + waterBill + carriedOverBalance;

    // BAGONG BILL: walang ibinabawas na nakaraang bayad.
    const double amountPaid = 0.0;
    final double remainingBalance = totalBill;
    const String paymentStatus = "unpaid";
    const dynamic paidAt = null;

    final Map<String, dynamic> updates = {
      "monthlyRent": monthlyRent,
      "previousElectric": previousElectric,
      "currentElectric": currentElectric,
      "electricConsumption": electricConsumption,
      "electricBill": electricBill,
      "previousWater": previousWater,
      "currentWater": currentWater,
      "waterConsumption": waterConsumption,
      "waterBill": waterBill,
      "totalBill": totalBill,
      "amountPaid": amountPaid,
      "remainingBalance": remainingBalance,
      "carriedOverBalance": carriedOverBalance,
      "paymentStatus": paymentStatus,
      "paidAt": paidAt,
      "dueDate": Timestamp.fromDate(dueDate),
      "isOverdue": false,
      "billUpdated": true,
      "billingMonth": currentMonthKey,

      // Save the current billing history
      "history.$currentMonthKey": {
        "month": currentMonthKey,
        "monthlyRent": monthlyRent,
        "electricConsumption": electricConsumption,
        "waterConsumption": waterConsumption,
        "electricBill": electricBill,
        "waterBill": waterBill,
        "carriedOverBalance": carriedOverBalance,
        "totalBill": totalBill,
        "amountPaid": amountPaid,
        "remainingBalance": remainingBalance,
        "paymentStatus": paymentStatus,
        "paidAt": paidAt,
        "updatedAt": Timestamp.now(),
      },
    };

    // Save previous month before moving to a new month
    if (previousBillingMonth.isNotEmpty && !isSameMonth) {
      updates["history.$previousBillingMonth"] = {
        "month": previousBillingMonth,
        "monthlyRent": data["monthlyRent"] ?? 0,
        "electricConsumption": data["electricConsumption"] ?? 0,
        "waterConsumption": data["waterConsumption"] ?? 0,
        "electricBill": data["electricBill"] ?? 0,
        "waterBill": data["waterBill"] ?? 0,
        "carriedOverBalance": data["carriedOverBalance"] ?? 0,
        "totalBill": previousTotalBill,
        "amountPaid": previousAmountPaid,
        "remainingBalance": data["remainingBalance"] ?? 0,
        "paymentStatus": previousStatus,
        "paidAt": data["paidAt"],
        "archivedAt": Timestamp.now(),
      };
    }

    await roomRef.update(updates);

    // Isabay ang status ng tenant (users doc) sa bagong bill.
    final String tenantId = (data["tenantId"] ?? "").toString();

    if (tenantId.isNotEmpty) {
      try {
        await _db.collection("users").doc(tenantId).update({
          "paymentStatus": paymentStatus,
        });
      } catch (e) {
        print("UPDATE TENANT STATUS ERROR: $e");
      }
    }
  }

  // GET OWNER ROOMS
  Stream<QuerySnapshot> getOwnerRooms(
    String ownerId,
  ) {
    return _db
        .collection("rooms")
        .where("ownerId", isEqualTo: ownerId)
        .snapshots();
  }

  // CONNECT TENANT TO ROOM
  Future<void> connectTenantToRoom(
    String roomNumber,
    String tenantId,
    String ownerCode,
  ) async {
    try {
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
        throw Exception("Room does not exist");
      }

      var roomDoc = roomQuery.docs.first;

      if (roomDoc["tenantId"] != null &&
          roomDoc["tenantId"].toString().isNotEmpty) {
        throw Exception("Room already occupied");
      }

      await roomDoc.reference.update({
        "tenantId": tenantId,
        "paymentStatus": "unpaid",
        "paidAt": null,
      });

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

  // APPROVE TENANT
  Future<void> approveTenant(
    String tenantId,
  ) async {
    await _db.collection("users").doc(tenantId).update({
      "approved": true,
    });
  }

  // UPDATE TENANT PROFILE
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

  // CALCULATE MINIMUM PAYMENT
  static double calculateMinimumPayment({
    required double totalBill,
    required double remainingBalance,
  }) {
    double half = totalBill * 0.5;
    return remainingBalance < half ? remainingBalance : half;
  }

  // SUBMIT PAYMENT
  Future<String> submitPayment(
    String tenantId,
    String ownerId,
    String room,
    double amount,
    String screenshotUrl,
  ) async {
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
    String paymentMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    bool isPartial = amount < remainingBalance - 0.01;

    final paymentRef = await _db.collection("payments").add({
      "tenantId": tenantId,
      "ownerId": ownerId,
      "room": room,
      "amount": amount,
      "screenshot": screenshotUrl,
      "status": "pending",
      "isPartial": isPartial,
      "date": Timestamp.now(),
      "paymentMonth": paymentMonth,
    });

    await _db.collection("users").doc(tenantId).update({
      "activePaymentId": paymentRef.id,
    });

    return paymentRef.id;
  }

  // APPROVE PAYMENT
  // Hindi ini-clear ang activePaymentId dito, kahit "partial" na ang
  // bagong status. Ang PendingPaymentScreen ang bahala magpakita ng
  // tamang mensahe (buo o partial, gamit ang isPartial field ng
  // payment doc), at ang tenant mismo ang mag-tap ng "Continue/Go to
  // Dashboard" bago ma-clear ang lock -- consistent ang behavior para
  // sa buo at partial na bayad.
  //
  // Lahat ng updates (payment, room, tenant) ay nasa iisang batch, kaya
  // either sabay-sabay silang mag-succeed o wala. Kapag may error,
  // nire-rethrow para makita ng caller.
  Future<void> approvePayment(
    String paymentId,
    String tenantId,
  ) async {
    try {
      final paymentRef = _db.collection("payments").doc(paymentId);

      final paymentDoc = await paymentRef.get();
      final paymentData = paymentDoc.data();

      if (paymentData == null) {
        throw Exception("Payment not found");
      }

      final String roomNumber = (paymentData["room"] ?? "").toString();

      final double approvedAmount = paymentData["amount"] is num
          ? (paymentData["amount"] as num).toDouble()
          : double.tryParse(
                (paymentData["amount"] ?? "0").toString(),
              ) ??
              0.0;

      final String paymentMonth =
          (paymentData["paymentMonth"] ?? "").toString();

      final Timestamp approvedTime = Timestamp.now();

      final roomQuery = await _db
          .collection("rooms")
          .where("roomNumber", isEqualTo: roomNumber)
          .where("tenantId", isEqualTo: tenantId)
          .limit(1)
          .get();

      if (roomQuery.docs.isEmpty) {
        throw Exception("Room not found for this tenant");
      }

      final roomDoc = roomQuery.docs.first;
      final roomRef = roomDoc.reference;
      final roomData = roomDoc.data();

      final double totalBill = roomData["totalBill"] is num
          ? (roomData["totalBill"] as num).toDouble()
          : 0.0;

      final double currentAmountPaid = roomData["amountPaid"] is num
          ? (roomData["amountPaid"] as num).toDouble()
          : 0.0;

      double newAmountPaid = currentAmountPaid + approvedAmount;

      if (newAmountPaid > totalBill) {
        newAmountPaid = totalBill;
      }

      double newRemainingBalance = totalBill - newAmountPaid;

      if (newRemainingBalance < 0) {
        newRemainingBalance = 0;
      }

      final bool isFullPayment = newRemainingBalance <= 0.01;

      final String newStatus = isFullPayment ? "paid" : "partial";

      final batch = _db.batch();

      // UPDATE PAYMENT STATUS
      batch.update(paymentRef, {
        "status": "verified",
        "verifiedAt": approvedTime,
        "resultType": isFullPayment ? "approved_full" : "approved_partial",
        "tenantSeen": false,
      });

      // UPDATE ROOM PAYMENT STATUS
      final Map<String, dynamic> roomUpdates = {
        "amountPaid": newAmountPaid,
        "remainingBalance": newRemainingBalance,
        "paymentStatus": newStatus,
        "paidAt": isFullPayment ? approvedTime : null,
        "isOverdue": false,
      };

      if (paymentMonth.isNotEmpty) {
        roomUpdates["history.$paymentMonth.paymentStatus"] = newStatus;

        roomUpdates["history.$paymentMonth.paidAt"] =
            isFullPayment ? approvedTime : null;

        roomUpdates["history.$paymentMonth.amountPaid"] = newAmountPaid;
      }

      batch.update(roomRef, roomUpdates);

      // UPDATE TENANT STATUS
      final tenantRef = _db.collection("users").doc(tenantId);

      batch.update(tenantRef, {
        "approved": true,
        "paymentStatus": newStatus,
        "lastPaymentDate": approvedTime,
      });

      // APPLY ALL UPDATES TOGETHER
      await batch.commit();

      print(
        "PAYMENT APPROVED: $paymentId | STATUS: $newStatus",
      );
    } catch (e) {
      print("APPROVE PAYMENT ERROR: $e");
      rethrow;
    }
  }

  // REJECT PAYMENT
  // Isang parameter lang (paymentId). Hindi natin ini-clear ang
  // activePaymentId dito -- dapat manatiling naka-lock ang tenant
  // sa PendingPaymentScreen (para makita muna ang "Payment
  // Rejected" na screen) hanggang pindutin niya ang "Submit New
  // Payment", na siyang tumatawag sa clearActivePayment().
  Future<void> rejectPayment(
    String paymentId,
  ) async {
    try {
      await _db.collection("payments").doc(paymentId).update({
        "status": "rejected",
        "resultType": "rejected",
        "tenantSeen": false,
      });
    } catch (e) {
      print("REJECT PAYMENT ERROR: $e");
    }
  }

  // CLEAR ACTIVE PAYMENT (unlock dashboard)
  Future<void> clearActivePayment(
    String tenantId,
  ) async {
    await _db.collection("users").doc(tenantId).update({
      "activePaymentId": null,
    });
  }

  // DELETE PAYMENT
  Future<void> deletePayment(
    String paymentId,
  ) async {
    try {
      await _db.collection("payments").doc(paymentId).delete();
    } catch (e) {
      print("DELETE PAYMENT ERROR: $e");
    }
  }

  // CHECK OVERDUE
  //
  // Kapag may ownerId: ang rooms ng owner na iyon lang ang sinusuri, at ang
  // due date ay kinukuha sa contract ng tenant (parehong logic sa notification
  // na natatanggap ng tenant). Kapag walang contract ang tenant, ang dueDate
  // field ng room ang gamit.
  //
  // Ang vacant room at ang room na "paid" na ay hindi kailanman overdue.
  // Nagsusulat lang sa Firestore kapag nagbago ang value ng isOverdue.
  Future<void> checkOverdueRooms({String? ownerId}) async {
    final Query<Map<String, dynamic>> roomsQuery = ownerId == null
        ? _db.collection("rooms")
        : _db.collection("rooms").where("ownerId", isEqualTo: ownerId);

    final rooms = await roomsQuery.get();

    // Pinakabagong active contract (start date) ng bawat tenant.
    final Map<String, DateTime> contractStartByTenant = {};

    if (ownerId != null) {
      final contracts = await _db
          .collection("contracts")
          .where("ownerId", isEqualTo: ownerId)
          .get();

      for (final doc in contracts.docs) {
        final contract = doc.data();

        final String status = (contract["status"] ?? "").toString();
        if (_inactiveContractStatuses.contains(status)) continue;

        final String contractTenantId = (contract["tenantId"] ?? "").toString();
        final Timestamp? startTimestamp = contract["startDate"] as Timestamp?;

        if (contractTenantId.isEmpty || startTimestamp == null) continue;

        final DateTime startDate = startTimestamp.toDate();
        final DateTime? existing = contractStartByTenant[contractTenantId];

        if (existing == null || startDate.isAfter(existing)) {
          contractStartByTenant[contractTenantId] = startDate;
        }
      }
    }

    final DateTime now = DateTime.now();

    for (final room in rooms.docs) {
      final data = room.data();

      final String tenantId = (data["tenantId"] ?? "").toString();
      final String paymentStatus =
          (data["paymentStatus"] ?? "unpaid").toString().toLowerCase();

      bool overdue = false;

      if (tenantId.isNotEmpty && paymentStatus != "paid") {
        DateTime? dueDate;

        final DateTime? contractStart = contractStartByTenant[tenantId];

        if (contractStart != null) {
          // May contract: hindi pa overdue kung hindi pa nagsisimula.
          if (!now.isBefore(contractStart)) {
            dueDate = _computeContractDueDate(contractStart, now);
          }
        } else {
          // Walang contract: gamitin ang dueDate ng room (kung meron).
          final Timestamp? dueTimestamp = data["dueDate"] as Timestamp?;
          dueDate = dueTimestamp?.toDate();
        }

        if (dueDate != null) {
          overdue = !now.isBefore(dueDate);
        }
      }

      if (data["isOverdue"] != overdue) {
        await room.reference.update({
          "isOverdue": overdue,
        });
      }
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

  // GET TENANT PAYMENTS (tenant mismo ang tumitingin)
  Stream<QuerySnapshot> getTenantPayments(
    String tenantId,
  ) {
    return _db
        .collection("payments")
        .where("tenantId", isEqualTo: tenantId)
        .snapshots();
  }

  // GET TENANT PAYMENTS (FOR OWNER VIEW)
  Stream<QuerySnapshot> getTenantPaymentsForOwner(
    String ownerId,
    String tenantId,
  ) {
    return _db
        .collection("payments")
        .where("ownerId", isEqualTo: ownerId)
        .where("tenantId", isEqualTo: tenantId)
        .orderBy("date", descending: true)
        .snapshots();
  }

  // GET OWNER PAYMENTS
  Stream<QuerySnapshot> getOwnerPayments(
    String ownerId,
  ) {
    return _db
        .collection("payments")
        .where("ownerId", isEqualTo: ownerId)
        .orderBy("date", descending: true)
        .snapshots();
  }

  // GET OWNER TENANTS
  Stream<QuerySnapshot> getOwnerTenants(
    String ownerId,
  ) {
    return _db
        .collection("users")
        .where("ownerId", isEqualTo: ownerId)
        .where("role", isEqualTo: "tenant")
        .snapshots();
  }

  // GET CURRENT USER DATA
  Stream<DocumentSnapshot> getCurrentUserData() {
    final user = _auth.currentUser;

    return _db.collection("users").doc(user!.uid).snapshots();
  }
}
