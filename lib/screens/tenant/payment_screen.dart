import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/app_warning_banner.dart';
import '../../widgets/rentpay_glass_panel.dart';
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

  double amountPaid = 0;
  double remainingBalance = 0;
  double carriedOverBalance = 0;
  double minimumPayment = 0;

  bool isPartialSelected = false;

  final TextEditingController partialAmountController = TextEditingController();

  final TextEditingController _fullAmountController = TextEditingController();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _roomSub;

  String? gcashQR;
  String? mayaQR;

  bool loading = true;
  bool uploading = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _textPrimary =>
      _isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);

  Color get _textSecondary =>
      _isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);

  Color get _dividerColor =>
      _isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFDCE6EA);

  Color get _dialogColor => _isDark ? const Color(0xFF1B2124) : Colors.white;

  static const double _maxQrSize = 170;
  static const double _minQrSize = 110;
  static const double _screenChrome = 180;

  static const double _roomPanelHeight = 124;
  static const double _optionPanelHeight = 132;
  static const double _uploadButtonHeight = 32;
  static const double _qrTitleHeight = 26;
  static const double _qrBlockGap = 16;

  @override
  void initState() {
    super.initState();
    loadTenantData();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    partialAmountController.dispose();
    _fullAmountController.dispose();
    super.dispose();
  }


  Future<void> loadTenantData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() => loading = false);
        }
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        if (mounted) {
          setState(() => loading = false);
        }
        return;
      }

      final userData = userDoc.data();

      ownerId = (userData?["ownerId"] ?? "").toString();
      room = (userData?["room"] ?? "").toString();

      if (ownerId.isEmpty || room.isEmpty) {
        if (mounted) {
          setState(() => loading = false);
        }
        return;
      }

      final roomQuery = await FirebaseFirestore.instance
          .collection("rooms")
          .where("roomNumber", isEqualTo: room)
          .where("ownerId", isEqualTo: ownerId)
          .limit(1)
          .get();

      if (roomQuery.docs.isNotEmpty) {
        final roomData = roomQuery.docs.first.data();

        _applyRoomData(roomData);

        if (roomData["tenantId"] == null ||
            roomData["tenantId"].toString().isEmpty) {
          await roomQuery.docs.first.reference.update({
            "tenantId": user.uid,
          });
        }
      }

      final ownerDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(ownerId)
          .get();

      if (ownerDoc.exists) {
        final ownerData = ownerDoc.data();

        gcashQR = ownerData?["gcashQr"]?.toString();
        mayaQR = ownerData?["paymayaQr"]?.toString();
      }

      if (mounted) {
        setState(() => loading = false);
        _listenToRoom();
      }
    } catch (e) {
      debugPrint("LOAD PAYMENT ERROR: $e");

      if (mounted) {
        setState(() => loading = false);
        showAppWarningBanner(
          context,
          friendlyAuthError(e),
        );
      }
    }
  }

  void _applyRoomData(Map<String, dynamic> roomData) {
    final double newTotal = _toDouble(roomData["totalBill"]);

    final double newPaid = _toDouble(roomData["amountPaid"]);

    double newRemaining = newTotal - newPaid;

    if (newRemaining < 0) {
      newRemaining = 0;
    }

    final bool billChanged = (newTotal - totalBill).abs() > 0.001 ||
        (newRemaining - remainingBalance).abs() > 0.001;

    rent = _toDouble(roomData["monthlyRent"]);
    waterBill = _toDouble(roomData["waterBill"]);
    electricBill = _toDouble(roomData["electricBill"]);
    carriedOverBalance = _toDouble(roomData["carriedOverBalance"]);

    totalBill = newTotal;
    amountPaid = newPaid;
    remainingBalance = newRemaining;

    _fullAmountController.text = remainingBalance.toStringAsFixed(2);

    minimumPayment = FirestoreService.calculateMinimumPayment(
      totalBill: totalBill,
      remainingBalance: remainingBalance,
    );

    if (billChanged) {
      partialAmountController.text =
          minimumPayment > 0 ? minimumPayment.toStringAsFixed(2) : "";
    }
  }

  void _listenToRoom() {
    _roomSub?.cancel();

    if (room.isEmpty || ownerId.isEmpty) {
      return;
    }

    _roomSub = FirebaseFirestore.instance
        .collection("rooms")
        .where("roomNumber", isEqualTo: room)
        .where("ownerId", isEqualTo: ownerId)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted || snapshot.docs.isEmpty) {
          return;
        }

        setState(() {
          _applyRoomData(snapshot.docs.first.data());
        });
      },
      onError: (e) {
        debugPrint("ROOM LISTENER ERROR: $e");
      },
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? "",
        ) ??
        0;
  }

  // =====================================================
  // PAYMENT LOGIC
  // =====================================================

  double get amountToSubmit {
    if (!isPartialSelected) {
      return remainingBalance;
    }

    return double.tryParse(
          partialAmountController.text,
        ) ??
        0;
  }

  String? get partialAmountErrorText {
    if (!isPartialSelected) {
      return null;
    }

    final text = partialAmountController.text.trim();

    if (text.isEmpty) {
      return "Amount Due";
    }

    final value = double.tryParse(text);

    if (value == null || value <= 0) {
      return "Invalid na halaga";
    }

    if (value > remainingBalance + 0.01) {
      return "Hindi pwedeng lumagpas sa natitirang balance";
    }

    if (value < minimumPayment - 0.01) {
      return "Minimum na ₱${minimumPayment.toStringAsFixed(2)}";
    }

    return null;
  }


  Future<bool> isImageBlurred(File file) async {
    try {
      final Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: 1,
      );

      if (compressed == null) {
        return true;
      }

      final int originalSize = await file.length();

      if (originalSize < 80000) {
        return true;
      }

      return false;
    } catch (e) {
      return true;
    }
  }



  void showFullImage(String url) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(
                          child: Text(
                            "Failed to load QR image",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF123E5A),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 22,
                      color: Color(0xFF123E5A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  Future<void> uploadAndSubmitPayment(
    double amount,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (picked == null || !mounted) {
        return;
      }

      setState(() => uploading = true);

      final File file = File(picked.path);

      final bool blurred = await isImageBlurred(file);

      if (blurred) {
        if (mounted) {
          setState(() => uploading = false);

          showAppWarningBanner(
            context,
            "Blurred or low quality receipt detected",
          );
        }

        return;
      }

      final String? url = await uploadToCloudinary(file);

      if (url == null) {
        throw Exception("Cloudinary upload failed");
      }

      await firestore.submitPayment(
        user.uid,
        ownerId,
        room,
        amount,
        url,
      );

      if (mounted) {
        setState(() => uploading = false);

        showAppSuccessBanner(
          context,
          "Payment submitted successfully",
        );
      }
    } catch (e) {
      debugPrint("UPLOAD ERROR: $e");

      if (mounted) {
        setState(() => uploading = false);

        showAppWarningBanner(
          context,
          friendlyAuthError(e),
        );
      }
    }
  }

  // =====================================================
  // CONFIRM PAYMENT
  // =====================================================

  // =====================================================
// CONFIRM PAYMENT
// =====================================================

  void confirmPayment() {
    if (totalBill <= 0 || remainingBalance <= 0) {
      showAppWarningBanner(
        context,
        "No bill found",
      );
      return;
    }

    final error = partialAmountErrorText;

    if (error != null) {
      showAppWarningBanner(context, error);
      return;
    }

    final double amount = amountToSubmit;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _dialogColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          // CENTERED TITLE
          title: Center(
            child: Text(
              "Confirm Payment",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),

          // CENTERED CONTENT
          content: Text(
            "Upload proof of payment for "
            "₱${amount.toStringAsFixed(2)}?",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
            ),
          ),

          // BUTTONS AT THE BOTTOM AND CENTERED
          actionsAlignment: MainAxisAlignment.center,

          actionsPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 18,
            top: 4,
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(
                foregroundColor: _textSecondary,
                overlayColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 14),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                uploadAndSubmitPayment(amount);
              },
              style: TextButton.styleFrom(
                foregroundColor: _textPrimary,
                backgroundColor: Colors.transparent,
                overlayColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              icon: const Icon(
                Icons.upload_file_outlined,
                size: 17,
              ),
              label: const Text(
                "Upload",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // MAIN UI
  // =====================================================

  bool get _hasGcash => gcashQR != null && gcashQR!.trim().isNotEmpty;

  bool get _hasMaya => mayaQR != null && mayaQR!.trim().isNotEmpty;

  double get _qrSize {
    final int qrCount = (_hasGcash ? 1 : 0) + (_hasMaya ? 1 : 0);

    if (qrCount == 0) {
      return _maxQrSize;
    }

    final double screenHeight = MediaQuery.of(context).size.height;

    final double optionSpace =
        remainingBalance > 0 ? _optionPanelHeight + 8 : 0;

    final double fixedHeight = 4 +
        _roomPanelHeight +
        8 +
        optionSpace +
        (qrCount * _qrTitleHeight) +
        ((qrCount - 1) * _qrBlockGap) +
        8 +
        _uploadButtonHeight +
        8;

    final double perQr = (screenHeight - _screenChrome - fixedHeight) / qrCount;

    return perQr.clamp(_minQrSize, _maxQrSize).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Rentpay",
          style: TextStyle(
            fontFamily: 'RentpayScript',
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: _textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          _buildHistoryButton(),
        ],
      ),
      body: loading
          ? Center(
              child: CircularProgressIndicator(
                color: _textPrimary,
              ),
            )
          : (room.isEmpty || ownerId.isEmpty)
              ? _buildNoRoom()
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      8,
                    ),
                    child: _buildPaymentContent(),
                  ),
                ),
    );
  }


  Widget _buildHistoryButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          final user = FirebaseAuth.instance.currentUser;

          if (user == null) {
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TenantPaymentHistoryScreen(
                tenantId: user.uid,
              ),
            ),
          );
        },
        child: SizedBox(
          width: 42,
          height: 42,
          child: Tooltip(
            message: "Payment History",
            child: Icon(
              Icons.history,
              color: _textPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildNoRoom() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: RentpayGlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0xFF111111),
                child: Icon(
                  Icons.meeting_room_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "No room connected yet",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Connect to your owner to view "
                "your bill and pay.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildPaymentContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRoomPanel(),
        const SizedBox(height: 8),
        if (remainingBalance > 0) ...[
          _buildPaymentOptionPanel(),
          const SizedBox(height: 8),
        ],
        _buildQrArea(_qrSize),
        const SizedBox(height: 8),
        _buildUploadButton(),
      ],
    );
  }



  Widget? _buildStatusPill() {
    if (totalBill <= 0) {
      return null;
    }

    final bool paid = remainingBalance <= 0;
    final bool partial = !paid && amountPaid > 0;

    if (!paid && !partial) {
      return null;
    }

    final Color color =
        paid ? const Color(0xFF1EBA63) : const Color(0xFF3E8BEA);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid ? Icons.check_circle : Icons.timelapse,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            paid ? "PAID" : "PARTIAL",
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRoomPanel() {
    const double indent = 35;

    return RentpayGlassPanel(
      padding: const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RentpayPanelHeader(
            icon: Icons.receipt_long,
            title: "Room $room",
            dense: true,
            trailing: _buildStatusPill(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(
              left: indent,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMiniAmount(
                            "Room Rent",
                            rent,
                          ),
                          const SizedBox(width: 12),
                          _buildMiniAmount(
                            "Water Bill",
                            waterBill,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildMiniAmount(
                        "Already Paid",
                        amountPaid,
                        color: const Color(0xFF1EBA63),
                        align: CrossAxisAlignment.center,
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMiniAmount(
                            "Electric Bill",
                            electricBill,
                          ),
                          const SizedBox(width: 12),
                          _buildMiniAmount(
                            "Total Bill",
                            totalBill,
                            color: const Color(0xFF3E8BEA),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildMiniAmount(
                        "Remaining Balance",
                        remainingBalance,
                        color: const Color(0xFFE97818),
                        size: 14,
                        align: CrossAxisAlignment.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (carriedOverBalance > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(
                left: indent,
              ),
              child: _buildMiniAmount(
                "Carried Over",
                carriedOverBalance,
                color: const Color(0xFFE93636),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniAmount(
    String label,
    double amount, {
    Color? color,
    double size = 12,
    CrossAxisAlignment align = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          "₱${amount.toStringAsFixed(2)}",
          maxLines: 1,
          style: TextStyle(
            color: color ?? _textPrimary,
            fontSize: size,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }



  Widget _buildPaymentOptionPanel() {
    return RentpayGlassPanel(
      padding: const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RentpayPanelHeader(
            icon: Icons.payments_outlined,
            title: "Payment Option",
            dense: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _paymentToggleButton(
                  title: "Full Payment",
                  selected: !isPartialSelected,
                  onPressed: () {
                    setState(() {
                      isPartialSelected = false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _paymentToggleButton(
                  title: "Partial",
                  selected: isPartialSelected,
                  onPressed: () {
                    setState(() {
                      isPartialSelected = true;

                      if (partialAmountController.text.isEmpty) {
                        partialAmountController.text =
                            minimumPayment.toStringAsFixed(2);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: isPartialSelected
                ? partialAmountController
                : _fullAmountController,
            readOnly: !isPartialSelected,
            showCursor: isPartialSelected,
            enableInteractiveSelection: isPartialSelected,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            cursorColor: _textPrimary,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              isDense: true,
              labelText: "Amount Due",
              labelStyle: TextStyle(
                color: _textSecondary,
                fontSize: 12,
              ),
              floatingLabelStyle: TextStyle(
                color: _textPrimary,
              ),
              prefixText: "₱ ",
              prefixStyle: TextStyle(
                color: _textPrimary,
              ),
              errorText: partialAmountErrorText,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _isDark
                      ? const Color(0xFF3A464C)
                      : const Color(0xFFCBD8DE),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _textPrimary,
                  width: 1.4,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE93636),
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE93636),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentToggleButton({
    required String title,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    const Color blue = Color(0xFF3E8BEA);

    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor:
              selected ? blue.withOpacity(0.14) : Colors.transparent,
          side: BorderSide(
            color: selected ? blue : _dividerColor,
            width: selected ? 1.2 : 1,
          ),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? blue : _textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }



  Widget _buildQrArea(double qrSize) {
    final List<Widget> blocks = [
      if (_hasGcash)
        _buildQrBlock(
          title: "GCash QR",
          url: gcashQR!,
          size: qrSize,
        ),
      if (_hasMaya)
        _buildQrBlock(
          title: "PayMaya QR",
          url: mayaQR!,
          size: qrSize,
        ),
    ];

    if (blocks.isEmpty) {
      return SizedBox(
        height: 200,
        child: _buildNoQr(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < blocks.length; i++) ...[
          blocks[i],
          if (i < blocks.length - 1) const SizedBox(height: _qrBlockGap),
        ],
      ],
    );
  }

  Widget _buildQrBlock({
    required String title,
    required String url,
    required double size,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size,
          height: size,
          child: _buildQrBox(url),
        ),
      ],
    );
  }

  Widget _buildQrBox(String url) {
    return GestureDetector(
      onTap: () => showFullImage(url),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }

            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF123E5A),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
                size: 30,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoQr() {
    return Center(
      child: RentpayGlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFF111111),
              child: Icon(
                Icons.qr_code_2,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "No payment QR available",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Your owner has not uploaded a QR yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildUploadButton() {
    return Center(
      child: InkWell(
        onTap: uploading ? null : confirmPayment,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          child: uploading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _textPrimary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.upload_rounded,
                      size: 15,
                      color: _textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Upload Payment Screenshot",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}


