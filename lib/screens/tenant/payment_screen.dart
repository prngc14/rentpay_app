import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/app_warning_banner.dart'; // <-- ayusin ang path kung iba ang location 
import 'tenant_payment_history_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FirestoreService firestore = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  String room = "";
  String ownerId = "";

  double rent = 0;
  double waterBill = 0;
  double electricBill = 0;
  double totalBill = 0;

  // PARTIAL PAYMENT TRACKING
  double amountPaid = 0;
  double remainingBalance = 0;
  double carriedOverBalance = 0;
  double minimumPayment = 0;

  // FULL / PARTIAL TOGGLE
  bool isPartialSelected = false;
  final TextEditingController partialAmountController =
      TextEditingController();

  String? gcashQR;
  String? mayaQR;

  bool loading = true;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    loadTenantData();
  }

  @override
  void dispose() {
    partialAmountController.dispose();
    super.dispose();
  }

  
  // LOAD TENANT + ROOM + OWNER QR
 
  Future<void> loadTenantData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => loading = false);
        return;
      }

      
      // GET TENANT DATA
     
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() => loading = false);
        return;
      }

      final userData = userDoc.data();

      ownerId = userData?["ownerId"] ?? "";
      room = userData?["room"] ?? "";

     
      // CHECK CONNECTION
      
      if (ownerId.isEmpty || room.isEmpty) {
        setState(() => loading = false);

        if (!mounted) return;
        showAppWarningBanner(
            context, "Connect to owner and select a room first");

        return;
      }

      
      // GET ROOM DATA
     
      final roomQuery = await FirebaseFirestore.instance
          .collection("rooms")
          .where("roomNumber", isEqualTo: room)
          .where("ownerId", isEqualTo: ownerId)
          .limit(1)
          .get();

      if (roomQuery.docs.isNotEmpty) {
        final roomData = roomQuery.docs.first.data();

        rent = (roomData["monthlyRent"] ?? 0).toDouble();

        waterBill = (roomData["waterBill"] ?? 0).toDouble();

        electricBill = (roomData["electricBill"] ?? 0).toDouble();

        totalBill = (roomData["totalBill"] ?? 0).toDouble();

        // PARTIAL PAYMENT TRACKING
        amountPaid = (roomData["amountPaid"] ?? 0).toDouble();

        carriedOverBalance = (roomData["carriedOverBalance"] ?? 0).toDouble();

        remainingBalance = totalBill - amountPaid;
        if (remainingBalance < 0) remainingBalance = 0;

        minimumPayment = FirestoreService.calculateMinimumPayment(
          totalBill: totalBill,
          remainingBalance: remainingBalance,
        );

        // AUTO FIX IF TENANT NOT SAVED
        if (roomData["tenantId"] == null ||
            roomData["tenantId"].toString().isEmpty) {
          await roomQuery.docs.first.reference.update({
            "tenantId": user.uid,
          });
        }
      }

     
      // GET OWNER QR
      
      final ownerDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(ownerId)
          .get();

      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data();

        gcashQR = ownerData?["gcashQr"];
        mayaQR = ownerData?["paymayaQr"];
      }

      setState(() => loading = false);
    } catch (e) {
      print("LOAD PAYMENT ERROR: $e");

      setState(() => loading = false);

      if (!mounted) return;
      showAppWarningBanner(context, friendlyAuthError(e));
    }
  }

  
  // AMOUNT NA IPAPADALA (base sa toggle)
  
  double get amountToSubmit {
    if (!isPartialSelected) return remainingBalance;

    return double.tryParse(partialAmountController.text) ?? 0;
  }

  
  // VALIDATION MESSAGE (null kung valid)
  
  String? get partialAmountErrorText {
    if (!isPartialSelected) return null;

    final text = partialAmountController.text.trim();

    if (text.isEmpty) {
      return "Ilagay ang halagang babayaran";
    }

    final value = double.tryParse(text);

    if (value == null || value <= 0) {
      return "Invalid na halaga";
    }

    if (value > remainingBalance + 0.01) {
      return "Hindi pwedeng lumagpas sa natitirang balanse (₱${remainingBalance.toStringAsFixed(2)})";
    }

    if (value < minimumPayment - 0.01) {
      return "Minimum na ₱${minimumPayment.toStringAsFixed(2)} ang dapat bayaran";
    }

    return null;
  }

  
  // CHECK IF IMAGE IS POSSIBLY BLURRED
  
  Future<bool> isImageBlurred(File file) async {
    try {
      Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 1,
      );

      if (compressed == null) {
        return true;
      }

      // CHECK FILE SIZE
      int originalSize = await file.length();

      // TOO SMALL = POSSIBLY BLURRY
      if (originalSize < 80000) {
        return true;
      }

      return false;
    } catch (e) {
      return true;
    }
  }

 
  // SHOW FULL IMAGE
  
  void showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }

  
  // UPLOAD PAYMENT
  
  Future<void> uploadAndSubmitPayment(double amount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (picked == null) return;

      setState(() => uploading = true);

      File file = File(picked.path);

      
      // CHECK BLUR
      
      bool blurred = await isImageBlurred(file);

      if (blurred) {
        setState(() => uploading = false);

        if (!mounted) return;
        showAppWarningBanner(
            context, "Blurred or low quality receipt detected");

        return;
      }

      
      // UPLOAD IMAGE
      
      String? url = await uploadToCloudinary(file);

      if (url == null) {
        throw Exception("Cloudinary upload failed");
      }

      
      // SAVE PAYMENT
     
      await firestore.submitPayment(
        user.uid,
        ownerId,
        room,
        amount,
        url,
      );

      setState(() => uploading = false);

      if (!mounted) return;
      showAppSuccessBanner(context, "Payment submitted successfully");
    } catch (e) {
      print("UPLOAD ERROR: $e");

      setState(() => uploading = false);

      if (!mounted) return;
      showAppWarningBanner(context, friendlyAuthError(e));
    }
  }

 
  // CONFIRM PAYMENT
 
  void confirmPayment() {
    if (totalBill <= 0) {
      showAppWarningBanner(context, "No bill found");
      return;
    }

    if (remainingBalance <= 0) {
      showAppWarningBanner(context, "No bill found");
      return;
    }

    // VALIDATE PARTIAL AMOUNT (kung partial ang napili)
    final error = partialAmountErrorText;

    if (error != null) {
      showAppWarningBanner(context, error);
      return;
    }

    final double amount = amountToSubmit;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: Text(
          "Upload proof of payment for ₱${amount.toStringAsFixed(2)}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              uploadAndSubmitPayment(amount);
            },
            child: const Text("Upload"),
          ),
        ],
      ),
    );
  }

 
  // UI
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Rent"),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Payment History",
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TenantPaymentHistoryScreen(
                    tenantId: user.uid,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ROOM CARD
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            "Room: $room",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Room Rent: ₱$rent",
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Water Bill: ₱$waterBill",
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Electric Bill: ₱$electricBill",
                            style: const TextStyle(
                              fontSize: 18,
                            ),
                          ),

                          // CARRIED OVER BALANCE (kung meron)
                          if (carriedOverBalance > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              "Carried Over Balance: ₱${carriedOverBalance.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],

                          const Divider(
                            height: 30,
                            thickness: 1,
                          ),
                          Text(
                            "Total Bill: ₱${totalBill.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          // ALREADY PAID + REMAINING (kung may partial na)
                          if (amountPaid > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              "Already Paid: ₱${amountPaid.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              "Remaining Balance",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "₱${remainingBalance.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Text(
                              "₱${remainingBalance.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                 
                  // FULL / PARTIAL TOGGLE
                  
                  if (remainingBalance > 0)
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Payment Option",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: !isPartialSelected
                                          ? Colors.deepOrange
                                          : null,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        isPartialSelected = false;
                                      });
                                    },
                                    child: Text(
                                      "Full Payment",
                                      style: TextStyle(
                                        color: !isPartialSelected
                                            ? Colors.white
                                            : Colors.deepOrange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: isPartialSelected
                                          ? Colors.deepOrange
                                          : null,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        isPartialSelected = true;

                                        // I-PREFILL NG MINIMUM AMOUNT
                                        if (partialAmountController
                                            .text.isEmpty) {
                                          partialAmountController.text =
                                              minimumPayment
                                                  .toStringAsFixed(2);
                                        }
                                      });
                                    },
                                    child: Text(
                                      "Partial Payment",
                                      style: TextStyle(
                                        color: isPartialSelected
                                            ? Colors.white
                                            : Colors.deepOrange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // PARTIAL AMOUNT INPUT
                            if (isPartialSelected) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: partialAmountController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: "Halagang Babayaran",
                                  prefixText: "₱ ",
                                  border: const OutlineInputBorder(),
                                  helperText:
                                      "Minimum: ₱${minimumPayment.toStringAsFixed(2)} • Max: ₱${remainingBalance.toStringAsFixed(2)}",
                                  errorText: partialAmountErrorText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // GCASH QR
                  if (gcashQR != null && gcashQR!.isNotEmpty)
                    Column(
                      children: [
                        const Text(
                          "GCash QR",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => showFullImage(gcashQR!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              gcashQR!,
                              height: 220,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),

                  // MAYA QR
                  if (mayaQR != null && mayaQR!.isNotEmpty)
                    Column(
                      children: [
                        const Text(
                          "Maya QR",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => showFullImage(mayaQR!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              mayaQR!,
                              height: 220,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),

                  // UPLOAD BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: uploading ? null : confirmPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                      child: uploading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              "Upload Payment Screenshot",
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}