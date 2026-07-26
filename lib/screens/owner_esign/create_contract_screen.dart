import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateContractScreen extends StatefulWidget {
  const CreateContractScreen({super.key});

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

  // Mga status na HINDI dapat mag-block sa tenant/room sa dropdown
  // (ibig sabihin: pwede na ulit i-select kapag ganito na ang status)
  static const List<String> _inactiveContractStatuses = [
    "Expired",
    "Cancelled",
    "Terminated",
  ];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final tenantsSnapshot = await _firestore
        .collection("users")
        .where("ownerId", isEqualTo: user.uid)
        .where("role", isEqualTo: "tenant")
        .get();

    final roomsSnapshot = await _firestore
        .collection("rooms")
        .where("ownerId", isEqualTo: user.uid)
        .get();

    // Kunin lahat ng contracts ng owner na ito para malaman kung
    // sino ang mga tenant AT alin sa mga room ang may ACTIVE contract pa
    final contractsSnapshot = await _firestore
        .collection("contracts")
        .where("ownerId", isEqualTo: user.uid)
        .get();

    final activeContracts = contractsSnapshot.docs.where((doc) {
      final status = (doc.data()["status"] ?? "").toString();
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

    setState(() {
      _tenantOptions = tenantsSnapshot.docs
          .where((doc) => !tenantIdsWithActiveContract.contains(doc.id))
          .map((doc) {
        final data = doc.data();
        return {
          "id": doc.id,
          "name": data["name"] ?? "Tenant",
        };
      }).toList();

      _roomOptions = roomsSnapshot.docs
          .where((doc) => !roomIdsWithActiveContract.contains(doc.id))
          .map((doc) {
        final data = doc.data();

        return {
          "id": doc.id,
          "roomNumber": data["roomNumber"] ?? "Room",
          "monthlyRent": (data["monthlyRent"] ?? 0).toDouble(),
          "electricRate": (data["electricRate"] ?? 12).toDouble(),
          "waterRate": (data["waterRate"] ?? 30).toDouble(),
          "tenantId": data["tenantId"],
        };
      }).toList();

      _isLoading = false;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
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

  Future<void> _createContract() async {
    debugPrint("Create Contract button clicked");

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint("Create Contract failed: user is null");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please log in first.")),
        );
      }
      return;
    }

    if (_selectedTenantId == null || _selectedRoomId == null) {
      debugPrint(
        "Create Contract failed: tenant or room not selected. tenant=$_selectedTenantId room=$_selectedRoomId",
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a tenant and room.")),
        );
      }
      return;
    }

    if (startDate == null || endDate == null) {
      debugPrint(
        "Create Contract failed: start or end date missing. start=$startDate end=$endDate",
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select start and end dates.")),
        );
      }
      return;
    }

    final tenant = _tenantOptions.firstWhere(
      (item) => item["id"] == _selectedTenantId,
      orElse: () => {"name": "Tenant"},
    );

    final room = _roomOptions.firstWhere(
      (item) => item["id"] == _selectedRoomId,
      orElse: () => {
        "roomNumber": "Room",
        "monthlyRent": 0.0,
      },
    );

    try {
      debugPrint("Saving contract to Firestore...");

      await _firestore.collection("contracts").add({
        "ownerId": user.uid,
        "tenantId": _selectedTenantId,
        "tenantName": tenant["name"],
        "roomId": _selectedRoomId,
        "roomNumber": room["roomNumber"],
        "monthlyRent": double.tryParse(_rentController.text.trim()) ?? 0.0,
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

      await _firestore.collection("rooms").doc(_selectedRoomId).update({
        "tenantId": _selectedTenantId,
        "electricRate":
            double.tryParse(_electricRateController.text.trim()) ?? 0.0,
        "waterRate":
            double.tryParse(_waterRateController.text.trim()) ?? 0.0,
      });

      debugPrint("Contract saved successfully.");

      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contract saved successfully.")),
        );
      }
    } catch (e) {
      debugPrint("Create Contract save failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving contract: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Rental Contract"),
        backgroundColor: Colors.deepOrange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedTenantId,
                    decoration: const InputDecoration(
                      labelText: "Tenant",
                      border: OutlineInputBorder(),
                    ),
                    items: _tenantOptions.map((tenant) {
                      return DropdownMenuItem<String>(
                        value: tenant["id"],
                        child: Text(tenant["name"]),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTenantId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: _selectedRoomId,
                    decoration: const InputDecoration(
                      labelText: "Room",
                      border: OutlineInputBorder(),
                    ),
                    items: _roomOptions.map((room) {
                      return DropdownMenuItem<String>(
                        value: room["id"],
                        child: Text(room["roomNumber"]),
                      );
                    }).toList(),
                    onChanged: _roomOptions.isEmpty
                        ? null
                        : (value) {
                            final selectedRoom = _roomOptions.firstWhere(
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

                  const SizedBox(height: 15),

                  TextField(
                    controller: _rentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Monthly Rent",
                      prefixText: "₱ ",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: _electricRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Electric Rate per kWh",
                      prefixText: "₱ ",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: _waterRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Water Rate per m³",
                      prefixText: "₱ ",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: _depositController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Security Deposit",
                      prefixText: "₱ ",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: _advanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Advance Payment",
                      prefixText: "₱ ",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    title: Text(
                      startDate == null
                          ? "Select Contract Start Date"
                          : startDate.toString().split(" ")[0],
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _pickDate(isStart: true),
                  ),

                  const SizedBox(height: 15),

                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    title: Text(
                      endDate == null
                          ? "Select Contract End Date"
                          : endDate.toString().split(" ")[0],
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _pickDate(isStart: false),
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: _termsController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: "Terms and Conditions",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  SwitchListTile(
                    value: useESign,
                    onChanged: (value) {
                      setState(() {
                        useESign = value;
                      });
                    },
                    title: const Text("Use Digital Contract with E-Signature"),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                      ),
                      onPressed: _createContract,
                      child: const Text("Create Contract"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}