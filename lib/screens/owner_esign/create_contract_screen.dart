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
  State<CreateContractScreen> createState() => _CreateContractScreenState();
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
  bool _isSaving = false;

  bool get _isRenewal => widget.renewalData != null;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _backgroundColor =>
      _isDark ? Colors.black : const Color(0xFFFFF8FC);

  Color get _surfaceColor => _isDark ? const Color(0xFF1B2124) : Colors.white;

  Color get _primaryTextColor =>
      _isDark ? Colors.white : const Color(0xFF123E5A);

  Color get _secondaryTextColor =>
      _isDark ? const Color(0xFFB8C2C7) : const Color(0xFF454B50);

  Color get _borderColor =>
      _isDark ? const Color(0xFF5A6A72) : const Color(0xFFB8B8BE);

  static const List<String> _inactiveContractStatuses = [
    'Expired',
    'Cancelled',
    'Terminated',
    'Renewed',
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final tenantsSnapshot = await _firestore
          .collection('users')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final roomsSnapshot = await _firestore
          .collection('rooms')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final tenantDocuments = <String, Map<String, dynamic>>{};

      for (final doc in tenantsSnapshot.docs) {
        final data = doc.data();

        if (data['role'] == 'tenant') {
          tenantDocuments[doc.id] = data;
        }
      }

      for (final roomDoc in roomsSnapshot.docs) {
        final tenantId = roomDoc.data()['tenantId']?.toString();

        if (tenantId == null ||
            tenantId.isEmpty ||
            tenantDocuments.containsKey(tenantId)) {
          continue;
        }

        final tenantDoc =
            await _firestore.collection('users').doc(tenantId).get();

        final tenantData = tenantDoc.data();

        if (tenantDoc.exists &&
            tenantData != null &&
            tenantData['role'] == 'tenant') {
          tenantDocuments[tenantId] = tenantData;
        }
      }

      final contractsSnapshot = await _firestore
          .collection('contracts')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      final String? renewingContractId =
          _isRenewal ? widget.renewalData!['contractId'] as String? : null;

      final activeContracts = contractsSnapshot.docs.where((doc) {
        if (renewingContractId != null && doc.id == renewingContractId) {
          return false;
        }

        final status = (doc.data()['status'] ?? '').toString();

        return !_inactiveContractStatuses.contains(status);
      });

      final tenantIdsWithActiveContract = activeContracts
          .map(
            (doc) => doc.data()['tenantId'] as String?,
          )
          .whereType<String>()
          .toSet();

      final roomIdsWithActiveContract = activeContracts
          .map(
            (doc) => doc.data()['roomId'] as String?,
          )
          .whereType<String>()
          .toSet();

      if (!mounted) return;

      setState(() {
        _tenantOptions = tenantDocuments.entries.map((entry) {
          final data = entry.value;

          final hasActiveContract =
              tenantIdsWithActiveContract.contains(entry.key);

          final name = (data['name'] ?? 'Tenant').toString();

          return {
            'id': entry.key,
            'name': name,
            'displayName': hasActiveContract ? '$name (Active contract)' : name,
            'hasActiveContract': hasActiveContract,
          };
        }).toList();

        _roomOptions = roomsSnapshot.docs.map((doc) {
          final data = doc.data();

          final hasActiveContract = roomIdsWithActiveContract.contains(doc.id);

          final roomNumber = data['roomNumber'] ?? 'Room';

          return {
            'id': doc.id,
            'roomNumber': roomNumber,
            'displayRoomNumber': hasActiveContract
                ? '$roomNumber (Active contract)'
                : roomNumber,
            'monthlyRent': (data['monthlyRent'] ?? 0).toDouble(),
            'electricRate': (data['electricRate'] ?? 12).toDouble(),
            'waterRate': (data['waterRate'] ?? 30).toDouble(),
            'tenantId': data['tenantId'],
            'hasActiveContract': hasActiveContract,
          };
        }).toList();

        _isLoading = false;

        if (_isRenewal) {
          final r = widget.renewalData!;

          _selectedTenantId = r['tenantId'] as String?;
          _selectedRoomId = r['roomId'] as String?;

          _rentController.text =
              ((r['monthlyRent'] ?? 0) as num).toStringAsFixed(0);

          _depositController.text =
              ((r['securityDeposit'] ?? 0) as num).toStringAsFixed(0);

          _advanceController.text =
              ((r['advancePayment'] ?? 0) as num).toStringAsFixed(0);

          _electricRateController.text =
              ((r['electricRate'] ?? 0) as num).toStringAsFixed(2);

          _waterRateController.text =
              ((r['waterRate'] ?? 0) as num).toStringAsFixed(2);

          _termsController.text = (r['termsAndConditions'] ?? '').toString();

          final renewalStartDate = r['startDate'];
          final renewalEndDate = r['endDate'];

          if (renewalStartDate is Timestamp) {
            startDate = renewalStartDate.toDate();
          }

          if (renewalEndDate is Timestamp) {
            endDate = renewalEndDate.toDate();
          }
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
    final now = DateTime.now();
    final currentDate = isStart ? startDate : endDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _isDark
                      ? const Color(0xFFDDE3E6)
                      : const Color(0xFF123E5A),
                  onPrimary: _isDark ? const Color(0xFF111518) : Colors.white,
                  surface: _surfaceColor,
                  onSurface: _isDark ? Colors.white : Colors.black,
                ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      if (isStart) {
        startDate = pickedDate;
      } else {
        endDate = pickedDate;
      }
    });
  }

  // =====================================================
  // SMOOTH OWNER E-SIGNATURE
  // =====================================================

  Future<List<Offset>?> _showOwnerSignatureDialog({
    required String roomNumber,
  }) async {
    final signatureNotifier = ValueNotifier<List<Offset?>>([]);

    try {
      final result = await showDialog<List<Offset>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: _surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Owner E-Signature',
              style: TextStyle(
                color: _primaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign below to approve the contract '
                  'for Room $roomNumber.',
                  style: TextStyle(
                    color: _secondaryTextColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF111518) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _borderColor,
                    ),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      signatureNotifier.value = [
                        ...signatureNotifier.value,
                        null,
                        details.localPosition,
                      ];
                    },
                    onPanUpdate: (details) {
                      signatureNotifier.value = [
                        ...signatureNotifier.value,
                        details.localPosition,
                      ];
                    },
                    child: CustomPaint(
                      painter: _ContractSignaturePainter(
                        pointsNotifier: signatureNotifier,
                        color: _primaryTextColor,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      signatureNotifier.value = [];
                    },
                    icon: Icon(
                      Icons.refresh,
                      color: _primaryTextColor,
                      size: 18,
                    ),
                    label: Text(
                      'Clear',
                      style: TextStyle(
                        color: _primaryTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: _secondaryTextColor,
                  ),
                ),
              ),
              ValueListenableBuilder<List<Offset?>>(
                valueListenable: signatureNotifier,
                builder: (context, points, child) {
                  final hasSignature = points.whereType<Offset>().isNotEmpty;

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDark
                          ? const Color(0xFFDDE3E6)
                          : const Color(0xFF123E5A),
                      foregroundColor:
                          _isDark ? const Color(0xFF111518) : Colors.white,
                    ),
                    onPressed: !hasSignature
                        ? null
                        : () {
                            final cleanPoints =
                                points.whereType<Offset>().toList();

                            Navigator.pop(
                              dialogContext,
                              cleanPoints,
                            );
                          },
                    child: const Text(
                      'Save Signature',
                    ),
                  );
                },
              ),
            ],
          );
        },
      );

      return result;
    } finally {
      signatureNotifier.dispose();
    }
  }

  // =====================================================
  // CREATE CONTRACT
  // =====================================================

  Future<void> _createContract() async {
    debugPrint('Create Contract button clicked');

    if (_isSaving) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        showAppWarningBanner(
          context,
          'Please log in first.',
        );
      }
      return;
    }

    if (_selectedTenantId == null || _selectedRoomId == null) {
      showAppWarningBanner(
        context,
        'Please select a tenant and room.',
      );
      return;
    }

    if (startDate == null || endDate == null) {
      showAppWarningBanner(
        context,
        'Please select start and end dates.',
      );
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      showAppWarningBanner(
        context,
        'End date cannot be before start date.',
      );
      return;
    }

    final selectedTenant =
        _tenantOptions.cast<Map<String, dynamic>?>().firstWhere(
              (tenant) => tenant!['id'] == _selectedTenantId,
              orElse: () => null,
            );

    final selectedRoom = _roomOptions.cast<Map<String, dynamic>?>().firstWhere(
          (room) => room!['id'] == _selectedRoomId,
          orElse: () => null,
        );

    if (selectedTenant == null || selectedRoom == null) {
      showAppWarningBanner(
        context,
        'The selected tenant or room is no longer available. '
        'Please select them again.',
      );
      return;
    }

    if (!_isRenewal &&
        (selectedTenant['hasActiveContract'] == true ||
            selectedRoom['hasActiveContract'] == true)) {
      showAppWarningBanner(
        context,
        'This tenant or room already has an active contract. '
        'Use Renew Contract instead.',
      );
      return;
    }

    final rent = double.tryParse(_rentController.text.trim()) ?? 0.0;

    final deposit = double.tryParse(_depositController.text.trim()) ?? 0.0;

    final advance = double.tryParse(_advanceController.text.trim()) ?? 0.0;

    final electricRate = double.tryParse(
          _electricRateController.text.trim(),
        ) ??
        0.0;

    final waterRate = double.tryParse(
          _waterRateController.text.trim(),
        ) ??
        0.0;

    final roomNumber = (selectedRoom['roomNumber'] ?? 'Room').toString();

    List<Offset>? ownerSignaturePoints;

    if (useESign) {
      ownerSignaturePoints = await _showOwnerSignatureDialog(
        roomNumber: roomNumber,
      );

      if (!mounted) return;

      if (ownerSignaturePoints == null || ownerSignaturePoints.isEmpty) {
        showAppWarningBanner(
          context,
          'Owner signature is required.',
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final tenantSnapshot =
          await _firestore.collection('users').doc(_selectedTenantId).get();

      final ownerSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      final tenantData = tenantSnapshot.data();
      final ownerData = ownerSnapshot.data();

      final tenantName =
          (tenantData?['name'] ?? selectedTenant['name'] ?? 'Tenant')
              .toString()
              .trim();

      final ownerName =
          (ownerData?['name'] ?? user.displayName ?? 'Owner').toString().trim();

      final ownerSignature = ownerSignaturePoints
          ?.map(
            (point) => {
              'x': point.dx,
              'y': point.dy,
            },
          )
          .toList();

      final contractData = <String, dynamic>{
        'ownerId': user.uid,
        'ownerName': ownerName.isEmpty ? 'Owner' : ownerName,
        'tenantId': _selectedTenantId,
        'tenantName': tenantName.isEmpty ? 'Tenant' : tenantName,
        'roomId': _selectedRoomId,
        'roomNumber': roomNumber,
        'monthlyRent': rent,
        'securityDeposit': deposit,
        'advancePayment': advance,
        'electricRate': electricRate,
        'waterRate': waterRate,
        'startDate': Timestamp.fromDate(startDate!),
        'endDate': Timestamp.fromDate(endDate!),
        'termsAndConditions': _termsController.text.trim(),
        'useDigitalContract': useESign,
        'createdAt': Timestamp.now(),
        'status': useESign ? 'Pending Tenant Signature' : 'Pending Signature',
      };

      if (useESign && ownerSignature != null && ownerSignature.isNotEmpty) {
        contractData['ownerSignature'] = ownerSignature;
        contractData['ownerSignedAt'] = Timestamp.now();
        contractData['ownerSignatureLocked'] = true;
      }

      debugPrint('Saving contract to Firestore...');

      await _firestore.collection('contracts').add(contractData);

      await _firestore.collection('rooms').doc(_selectedRoomId).update({
        'tenantId': _selectedTenantId,
        'electricRate': electricRate,
        'waterRate': waterRate,
      });

      if (_isRenewal) {
        final oldContractId = widget.renewalData!['contractId'] as String?;

        if (oldContractId != null && oldContractId.isNotEmpty) {
          await _firestore.collection('contracts').doc(oldContractId).update({
            'status': 'Renewed',
            'renewedAt': Timestamp.now(),
          });
        }
      }

      debugPrint('Contract saved successfully.');

      if (!mounted) return;

      Navigator.pop(context);

      showAppSuccessBanner(
        context,
        _isRenewal
            ? 'Contract renewed successfully.'
            : 'Contract saved successfully.',
      );
    } catch (e) {
      debugPrint('Create Contract save failed: $e');

      if (!mounted) return;

      showAppWarningBanner(
        context,
        friendlyAuthError(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
      labelStyle: TextStyle(
        color: _secondaryTextColor,
      ),
      hintStyle: TextStyle(
        color: _secondaryTextColor,
      ),
      prefixStyle: TextStyle(
        color: _primaryTextColor,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      filled: true,
      fillColor: _surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _borderColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _primaryTextColor,
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
    final formattedDate = date == null
        ? label
        : '${date.year}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _borderColor,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 15,
                  color: date == null ? _secondaryTextColor : _primaryTextColor,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: 22,
              color: _secondaryTextColor,
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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(
          'Rentpay',
          style: TextStyle(
            fontFamily: 'RentpayScript',
            fontSize: 30,
            fontWeight: FontWeight.w400,
            color: _primaryTextColor,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: _backgroundColor,
        foregroundColor: _primaryTextColor,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: _primaryTextColor,
              ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isRenewal)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(
                          bottom: 10,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isDark
                              ? const Color(0xFF172A35)
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isDark
                                ? const Color(0xFF34586B)
                                : Colors.blue.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: _isDark
                                  ? const Color(0xFFB8DDF5)
                                  : Colors.blue.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Renewing contract for '
                                '${widget.renewalData!['tenantName'] ?? 'tenant'}. '
                                'The old contract will automatically be marked '
                                'as "Renewed" after saving.',
                                style: TextStyle(
                                  color: _isDark
                                      ? const Color(0xFFB8DDF5)
                                      : Colors.blue.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      value: _selectedTenantId,
                      isDense: true,
                      dropdownColor: _surfaceColor,
                      style: TextStyle(
                        color: _primaryTextColor,
                        fontSize: 16,
                      ),
                      decoration: _contractInputDecoration('Tenant'),
                      items: _tenantOptions.map((tenant) {
                        return DropdownMenuItem<String>(
                          value: tenant['id'] as String,
                          enabled:
                              tenant['hasActiveContract'] != true || _isRenewal,
                          child: Text(
                            tenant['displayName'].toString(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _primaryTextColor,
                            ),
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
                    DropdownButtonFormField<String>(
                      value: _selectedRoomId,
                      isDense: true,
                      dropdownColor: _surfaceColor,
                      style: TextStyle(
                        color: _primaryTextColor,
                        fontSize: 16,
                      ),
                      decoration: _contractInputDecoration('Room'),
                      items: _roomOptions.map((room) {
                        return DropdownMenuItem<String>(
                          value: room['id'] as String,
                          enabled:
                              room['hasActiveContract'] != true || _isRenewal,
                          child: Text(
                            room['displayRoomNumber'].toString(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _primaryTextColor,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: _roomOptions.isEmpty
                          ? null
                          : (value) {
                              final selectedRoom = _roomOptions.firstWhere(
                                (room) => room['id'] == value,
                              );

                              setState(() {
                                _selectedRoomId = value;

                                _rentController.text =
                                    (selectedRoom['monthlyRent'] ?? 0.0)
                                        .toStringAsFixed(0);

                                _electricRateController.text =
                                    (selectedRoom['electricRate'] ?? 0.0)
                                        .toStringAsFixed(2);

                                _waterRateController.text =
                                    (selectedRoom['waterRate'] ?? 0.0)
                                        .toStringAsFixed(2);
                              });
                            },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _rentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: _primaryTextColor,
                      ),
                      decoration: _contractInputDecoration(
                        'Monthly Rent',
                        prefixText: '₱ ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _electricRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: _primaryTextColor,
                      ),
                      decoration: _contractInputDecoration(
                        'Electric Rate per kWh',
                        prefixText: '₱ ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _waterRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: _primaryTextColor,
                      ),
                      decoration: _contractInputDecoration(
                        'Water Rate per m³',
                        prefixText: '₱ ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _depositController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: _primaryTextColor,
                      ),
                      decoration: _contractInputDecoration(
                        'Security Deposit',
                        prefixText: '₱ ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _advanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: _primaryTextColor,
                      ),
                      decoration: _contractInputDecoration(
                        'Advance Payment',
                        prefixText: '₱ ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _dateField(
                      label: 'Select Contract Start Date',
                      date: startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                    const SizedBox(height: 10),
                    _dateField(
                      label: 'Select Contract End Date',
                      date: endDate,
                      onTap: () => _pickDate(isStart: false),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _termsController,
                      maxLines: 4,
                      minLines: 3,
                      style: TextStyle(
                        color: _primaryTextColor,
                      ),
                      decoration: _contractInputDecoration(
                        'Terms and Conditions',
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      dense: true,
                      value: useESign,
                      onChanged: (value) {
                        setState(() {
                          useESign = value;
                        });
                      },
                      title: Text(
                        'Use Digital Contract with E-Signature',
                        style: TextStyle(
                          fontSize: 13,
                          color: _primaryTextColor,
                        ),
                      ),
                      activeColor: _isDark
                          ? const Color(0xFFDDE3E6)
                          : const Color(0xFF123E5A),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDark
                              ? const Color(0xFFDDE3E6)
                              : const Color(0xFF123E5A),
                          foregroundColor:
                              _isDark ? const Color(0xFF111518) : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : _createContract,
                        child: _isSaving
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _isDark
                                      ? const Color(0xFF111518)
                                      : Colors.white,
                                ),
                              )
                            : Text(
                                _isRenewal
                                    ? 'Renew Contract'
                                    : 'Create Contract',
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

// =====================================================
// SMOOTH SIGNATURE PAINTER
// =====================================================

class _ContractSignaturePainter extends CustomPainter {
  final ValueNotifier<List<Offset?>> pointsNotifier;
  final Color color;

  _ContractSignaturePainter({
    required this.pointsNotifier,
    required this.color,
  }) : super(repaint: pointsNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final points = pointsNotifier.value;

    if (points.isEmpty) return;

    Path? path;
    bool hasPointInCurrentStroke = false;

    for (final point in points) {
      if (point == null) {
        if (path != null && hasPointInCurrentStroke) {
          canvas.drawPath(path, paint);
        }

        path = null;
        hasPointInCurrentStroke = false;
        continue;
      }

      if (path == null) {
        path = Path();
        path.moveTo(point.dx, point.dy);
        hasPointInCurrentStroke = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    if (path != null && hasPointInCurrentStroke) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(
    covariant _ContractSignaturePainter oldDelegate,
  ) {
    return oldDelegate.color != color ||
        oldDelegate.pointsNotifier != pointsNotifier;
  }
}

