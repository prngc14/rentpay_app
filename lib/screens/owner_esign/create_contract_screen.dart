
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_warning_banner.dart';

class CreateContractScreen extends StatefulWidget {
  final Map<String, dynamic>? renewalData;

  const CreateContractScreen({
    super.key,
    this.renewalData,
  });

  @override
  State<CreateContractScreen> createState() =>
      _CreateContractScreenState();
}

class _CreateContractScreenState extends State<CreateContractScreen> {
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  final _advanceController = TextEditingController();
  final _electricRateController = TextEditingController();
  final _waterRateController = TextEditingController();
  final _termsController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _tenantOptions = [];
  List<Map<String, dynamic>> _roomOptions = [];

  String? _selectedTenantId;
  String? _selectedRoomId;

  DateTime? startDate;
  DateTime? endDate;

  bool useESign = true;
  bool _isLoading = true;

  bool get _isRenewal => widget.renewalData != null;

  static const List<String> _inactiveContractStatuses = [
    "Expired",
    "Cancelled",
    "Terminated",
    "Renewed",
  ];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _rentController.dispose();
    _depositController.dispose();
    _advanceController.dispose();
    _electricRateController.dispose();
    _waterRateController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  // =====================================================
  // LOAD OPTIONS
  // =====================================================

  Future<void> _loadOptions() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final tenantsSnapshot = await _firestore
          .collection("users")
          .where("ownerId", isEqualTo: user.uid)
          .get();

      final roomsSnapshot = await _firestore
          .collection("rooms")
          .where("ownerId", isEqualTo: user.uid)
          .get();

      final tenantDocuments = <String, Map<String, dynamic>>{};

      for (final doc in tenantsSnapshot.docs) {
        final data = doc.data();

        if (data["role"] == "tenant") {
          tenantDocuments[doc.id] = data;
        }
      }

      for (final roomDoc in roomsSnapshot.docs) {
        final tenantId =
            roomDoc.data()["tenantId"]?.toString();

        if (tenantId == null ||
            tenantId.isEmpty ||
            tenantDocuments.containsKey(tenantId)) {
          continue;
        }

        final tenantDoc = await _firestore
            .collection("users")
            .doc(tenantId)
            .get();

        final tenantData = tenantDoc.data();

        if (tenantDoc.exists &&
            tenantData != null &&
            tenantData["role"] == "tenant") {
          tenantDocuments[tenantId] = tenantData;
        }
      }

      final contractsSnapshot = await _firestore
          .collection("contracts")
          .where("ownerId", isEqualTo: user.uid)
          .get();

      final String? renewingContractId = _isRenewal
          ? widget.renewalData!["contractId"] as String?
          : null;

      final activeContracts = contractsSnapshot.docs.where((doc) {
        if (renewingContractId != null &&
            doc.id == renewingContractId) {
          return false;
        }

        final status =
            (doc.data()["status"] ?? "").toString();

        return !_inactiveContractStatuses.contains(status);
      });

      final tenantIdsWithActiveContract = activeContracts
          .map((doc) => doc.data()["tenantId"] as String?)
          .whereType<String>()
          .toSet();

      final roomIdsWithActiveContract = activeContracts
          .map((doc) => doc.data()["roomId"] as String?)
          .whereType<String>()
          .toSet();

      if (!mounted) return;

      setState(() {
        _tenantOptions = tenantDocuments.entries.map((entry) {
          final data = entry.value;

          final hasActiveContract =
              tenantIdsWithActiveContract.contains(entry.key);

          final name = (data["name"] ?? "Tenant").toString();

          return {
            "id": entry.key,
            "name": name,
            "displayName": hasActiveContract
                ? "$name (Active contract)"
                : name,
            "hasActiveContract": hasActiveContract,
          };
        }).toList();

        _roomOptions = roomsSnapshot.docs.map((doc) {
          final data = doc.data();

          final hasActiveContract =
              roomIdsWithActiveContract.contains(doc.id);

          return {
            "id": doc.id,
            "roomNumber": data["roomNumber"] ?? "Room",
            "displayRoomNumber": hasActiveContract
                ? "${data["roomNumber"] ?? "Room"} (Active contract)"
                : (data["roomNumber"] ?? "Room"),
            "monthlyRent":
                (data["monthlyRent"] ?? 0).toDouble(),
            "electricRate":
                (data["electricRate"] ?? 12).toDouble(),
            "waterRate":
                (data["waterRate"] ?? 30).toDouble(),
            "tenantId": data["tenantId"],
            "hasActiveContract": hasActiveContract,
          };
        }).toList();

        _isLoading = false;

        if (_isRenewal) {
          final r = widget.renewalData!;

          _selectedTenantId = r["tenantId"] as String?;
          _selectedRoomId = r["roomId"] as String?;

          _rentController.text =
              ((r["monthlyRent"] ?? 0) as num)
                  .toStringAsFixed(0);

          _depositController.text =
              ((r["securityDeposit"] ?? 0) as num)
                  .toStringAsFixed(0);

          _advanceController.text =
              ((r["advancePayment"] ?? 0) as num)
                  .toStringAsFixed(0);

          _electricRateController.text =
              ((r["electricRate"] ?? 0) as num)
                  .toStringAsFixed(2);

          _waterRateController.text =
              ((r["waterRate"] ?? 0) as num)
                  .toStringAsFixed(2);

          _termsController.text =
              (r["termsAndConditions"] ?? "").toString();
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      showAppWarningBanner(
        context,
        friendlyAuthError(e),
      );
    }
  }

  // =====================================================
  // PICK DATE
  // =====================================================

  Future<void> _pickDate({
    required bool isStart,
  }) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    setState(() {
      if (isStart) {
        startDate = pickedDate;
      } else {
        endDate = pickedDate;
      }
    });
  }

  // =====================================================
  // CREATE CONTRACT
  // =====================================================

  Future<void> _createContract() async {
    debugPrint("Create Contract button clicked");

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        showAppWarningBanner(
          context,
          "Please log in first.",
        );
      }
      return;
    }

    if (_selectedTenantId == null ||
        _selectedRoomId == null) {
      if (mounted) {
        showAppWarningBanner(
          context,
          "Please select a tenant and room.",
        );
      }
      return;
    }

    Map<String, dynamic>? selectedTenant;

    for (final item in _tenantOptions) {
      if (item["id"] == _selectedTenantId) {
        selectedTenant = item;
        break;
      }
    }

    Map<String, dynamic>? selectedRoom;

    for (final item in _roomOptions) {
      if (item["id"] == _selectedRoomId) {
        selectedRoom = item;
        break;
      }
    }

    if (selectedTenant == null || selectedRoom == null) {
      showAppWarningBanner(
        context,
        "The selected tenant or room is no longer available. Please select them again.",
      );
      return;
    }

    if (!_isRenewal &&
        (selectedTenant["hasActiveContract"] == true ||
            selectedRoom["hasActiveContract"] == true)) {
      showAppWarningBanner(
        context,
        "This tenant or room already has an active contract. Use Renew Contract instead.",
      );
      return;
    }

    if (startDate == null || endDate == null) {
      if (mounted) {
        showAppWarningBanner(
          context,
          "Please select start and end dates.",
        );
      }
      return;
    }

    final tenant = selectedTenant;

    try {
      final tenantSnapshot = await _firestore
          .collection("users")
          .doc(_selectedTenantId)
          .get();

      final tenantData = tenantSnapshot.data();

      final tenantName =
          (tenantData?["name"] ?? tenant["name"] ?? "Tenant")
              .toString()
              .trim();

      final room = selectedRoom;

      debugPrint("Saving contract to Firestore...");

      await _firestore.collection("contracts").add({
        "ownerId": user.uid,
        "tenantId": _selectedTenantId,
        "tenantName":
            tenantName.isEmpty ? "Tenant" : tenantName,
        "roomId": _selectedRoomId,
        "roomNumber": room["roomNumber"],
        "monthlyRent":
            double.tryParse(_rentController.text.trim()) ?? 0.0,
        "securityDeposit":
            double.tryParse(_depositController.text.trim()) ?? 0.0,
        "advancePayment":
            double.tryParse(_advanceController.text.trim()) ?? 0.0,
        "electricRate":
            double.tryParse(_electricRateController.text.trim()) ?? 0.0,
        "waterRate":
            double.tryParse(_waterRateController.text.trim()) ?? 0.0,
        "startDate": Timestamp.fromDate(startDate!),
        "endDate": Timestamp.fromDate(endDate!),
        "termsAndConditions": _termsController.text.trim(),
        "useDigitalContract": useESign,
        "createdAt": Timestamp.now(),
        "status": "Pending Signature",
      });

      await _firestore
          .collection("rooms")
          .doc(_selectedRoomId)
          .update({
        "tenantId": _selectedTenantId,
        "electricRate":
            double.tryParse(_electricRateController.text.trim()) ?? 0.0,
        "waterRate":
            double.tryParse(_waterRateController.text.trim()) ?? 0.0,
      });

      if (_isRenewal) {
        final oldContractId =
            widget.renewalData!["contractId"] as String?;

        if (oldContractId != null) {
          await _firestore
              .collection("contracts")
              .doc(oldContractId)
              .update({
            "status": "Renewed",
            "renewedAt": Timestamp.now(),
          });
        }
      }

      debugPrint("Contract saved successfully.");

      if (mounted) {
        Navigator.pop(context);

        showAppSuccessBanner(
          context,
          _isRenewal
              ? "Contract renewed successfully."
              : "Contract saved successfully.",
        );
      }
    } catch (e) {
      debugPrint("Create Contract save failed: $e");

      if (mounted) {
        showAppWarningBanner(
          context,
          friendlyAuthError(e),
        );
      }
    }
  }

  // =====================================================
  // INPUT DECORATION
  // =====================================================

  InputDecoration _contractInputDecoration(
    String label, {
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,

      isDense: true,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),

      filled: true,
      fillColor: Colors.white,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFB8B8BE),
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFB8B8BE),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF123E5A),
          width: 1.5,
        ),
      ),
    );
  }

  // =====================================================
  // DATE FIELD
  // =====================================================

  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,

      child: Container(
        height: 52,

        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(14),

          border: Border.all(
            color: const Color(0xFFB8B8BE),
          ),
        ),

        child: Row(
          children: [
            Expanded(
              child: Text(
                date == null
                    ? label
                    : "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",

                style: TextStyle(
                  fontSize: 15,
                  color: date == null
                      ? const Color(0xFF454B50)
                      : const Color(0xFF123E5A),
                ),
              ),
            ),

            const Icon(
              Icons.calendar_today_outlined,
              size: 22,
              color: Color(0xFF454B50),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FC),

      appBar: AppBar(
        automaticallyImplyLeading: true,

        title: const Text(
          "Rentpay",

          style: TextStyle(
            fontFamily: 'RentpayScript',
            fontSize: 30,
            fontWeight: FontWeight.w400,
            color: Color(0xFF123E5A),
            letterSpacing: 0.5,
          ),
        ),

        backgroundColor: const Color(0xFFFFF8FC),
        foregroundColor: const Color(0xFF123E5A),

        centerTitle: true,

        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )

          : SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,

                padding: const EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  20,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    // =====================================
                    // RENEWAL BANNER
                    // =====================================

                    if (_isRenewal)
                      Container(
                        width: double.infinity,

                        margin: const EdgeInsets.only(
                          bottom: 10,
                        ),

                        padding: const EdgeInsets.all(10),

                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,

                          borderRadius:
                              BorderRadius.circular(12),

                          border: Border.all(
                            color: Colors.blue.shade200,
                          ),
                        ),

                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 18,
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: Text(
                                "Renewing contract for "
                                "${widget.renewalData!["tenantName"] ?? "tenant"}. "
                                "The old contract will automatically be marked "
                                'as "Renewed" after saving.',

                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // =====================================
                    // TENANT
                    // =====================================

                    DropdownButtonFormField<String>(
                      value: _selectedTenantId,

                      isDense: true,

                      decoration:
                          _contractInputDecoration("Tenant"),

                      items: _tenantOptions.map((tenant) {
                        return DropdownMenuItem<String>(
                          value: tenant["id"],

                          enabled:
                              tenant["hasActiveContract"] != true ||
                                  _isRenewal,

                          child: Text(
                            tenant["displayName"],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),

                      onChanged: (value) {
                        setState(() {
                          _selectedTenantId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    // =====================================
                    // ROOM
                    // =====================================

                    DropdownButtonFormField<String>(
                      value: _selectedRoomId,

                      isDense: true,

                      decoration:
                          _contractInputDecoration("Room"),

                      items: _roomOptions.map((room) {
                        return DropdownMenuItem<String>(
                          value: room["id"],

                          enabled:
                              room["hasActiveContract"] != true ||
                                  _isRenewal,

                          child: Text(
                            room["displayRoomNumber"],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),

                      onChanged: _roomOptions.isEmpty
                          ? null
                          : (value) {
                              final selectedRoom =
                                  _roomOptions.firstWhere(
                                (room) => room["id"] == value,
                              );

                              setState(() {
                                _selectedRoomId = value;

                                _rentController.text =
                                    (selectedRoom["monthlyRent"] ?? 0.0)
                                        .toStringAsFixed(0);

                                _electricRateController.text =
                                    (selectedRoom["electricRate"] ?? 0.0)
                                        .toStringAsFixed(2);

                                _waterRateController.text =
                                    (selectedRoom["waterRate"] ?? 0.0)
                                        .toStringAsFixed(2);
                              });
                            },
                    ),

                    const SizedBox(height: 10),

                    // =====================================
                    // MONTHLY RENT
                    // =====================================

                    TextField(
                      controller: _rentController,

                      keyboardType: TextInputType.number,

                      decoration: _contractInputDecoration(
                        "Monthly Rent",
                        prefixText: "₱ ",
                      ),
                    ),

                    const SizedBox(height: 10),

                    // =====================================
                    // ELECTRIC RATE
                    // =====================================

                    TextField(
                      controller: _electricRateController,

                      keyboardType: TextInputType.number,

                      decoration: _contractInputDecoration(
                        "Electric Rate per kWh",
                        prefixText: "₱ ",
                      ),
                    ),

                    const SizedBox(height: 10),

                    // =====================================
                    // WATER RATE
                    // =====================================

                    TextField(
                      controller: _waterRateController,

                      keyboardType: TextInputType.number,

                      decoration: _contractInputDecoration(
                        "Water Rate per m³",
                        prefixText: "₱ ",
                      ),
                    ),

                    const SizedBox(height: 10),

                    // =====================================
                    // SECURITY DEPOSIT
                    // =====================================

                    TextField(
                      controller: _depositController,

                      keyboardType: TextInputType.number,

                      decoration: _contractInputDecoration(
                        "Security Deposit",
                        prefixText: "₱ ",
                      ),
                    ),

                    const SizedBox(height: 10),

                    // =====================================
                    // ADVANCE PAYMENT
                    // =====================================

                    TextField(
                      controller: _advanceController,

                      keyboardType: TextInputType.number,

                      decoration: _contractInputDecoration(
                        "Advance Payment",
                        prefixText: "₱ ",
                      ),
                    ),

                    const SizedBox(height: 10),

                    // =====================================
                    // START DATE
                    // =====================================

                    _dateField(
                      label: "Select Contract Start Date",
                      date: startDate,

                      onTap: () =>
                          _pickDate(isStart: true),
                    ),

                    const SizedBox(height: 10),

                    // =====================================
                    // END DATE
                    // =====================================

                    _dateField(
                      label: "Select Contract End Date",
                      date: endDate,

                      onTap: () =>
                          _pickDate(isStart: false),
                    ),

                    const SizedBox(height: 10),

                    // =====================================
                    // TERMS AND CONDITIONS
                    // =====================================

                    TextField(
                      controller: _termsController,

                      maxLines: 4,
                      minLines: 3,

                      decoration:
                          _contractInputDecoration(
                        "Terms and Conditions",
                      ),
                    ),

                    const SizedBox(height: 6),

                    // =====================================
                    // E-SIGNATURE SWITCH
                    // =====================================

                    SwitchListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),

                      dense: true,

                      value: useESign,

                      onChanged: (value) {
                        setState(() {
                          useESign = value;
                        });
                      },

                      title: const Text(
                        "Use Digital Contract with E-Signature",

                        style: TextStyle(
                          fontSize: 13,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // =====================================
                    // SAVE BUTTON
                    // =====================================

                    SizedBox(
                      width: double.infinity,
                      height: 46,

                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF123E5A),

                          foregroundColor: Colors.white,

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),

                        onPressed: _createContract,

                        child: Text(
                          _isRenewal
                              ? "Renew Contract"
                              : "Create Contract",

                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
    );
  }
}