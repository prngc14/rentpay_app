import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_warning_banner.dart';

class TenantContractsScreen extends StatefulWidget {
  const TenantContractsScreen({super.key});

  @override
  State<TenantContractsScreen> createState() => _TenantContractsScreenState();
}

class _TenantContractsScreenState extends State<TenantContractsScreen> {
  final List<Offset> _signaturePoints = [];

  // Ginagamit ng Save button sa E-Sign dialog para ipakita ang loading.
  final ValueNotifier<bool> _isSaving = ValueNotifier<bool>(false);

  // ===== KULAY (kapareho ng ibang tenant screens; walang orange) =====
  static const Color _navy = Color(0xFF123E5A);
  static const Color _slate = Color(0xFF587287);
  static const Color _blue = Color(0xFF3E8BEA);
  static const Color _green = Color(0xFF1EBA63);

  // ===== THEME-AWARE COLORS (sumusunod sa light/dark mode ng app) =====
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _textPrimary =>
      _isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);

  Color get _textSecondary =>
      _isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);

  Color get _cardColor => _isDark ? const Color(0xFF1B2124) : Colors.white;

  Color get _innerBoxColor =>
      _isDark ? const Color(0xFF242C30) : const Color(0xFFF7F7FA);

  Color get _dividerColor =>
      _isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB);

  Color get _fieldBorder =>
      _isDark ? const Color(0xFF3A464C) : const Color(0xFFCBD8DE);

  // Kulay ng mga pangunahing button (navy sa light, asul sa dark para
  // makita sa madilim na background).
  Color get _accent => _isDark ? _blue : _navy;

  static const List<String> _inactiveStatuses = [
    'Expired',
    'Cancelled',
    'Terminated',
    'Renewed',
  ];

  final Map<String, String> _ownerCodeCache = {};

  @override
  void dispose() {
    _isSaving.dispose();
    super.dispose();
  }

  Future<String> _getOwnerCode(String ownerId) async {
    if (ownerId.isEmpty) return "--";

    if (_ownerCodeCache.containsKey(ownerId)) {
      return _ownerCodeCache[ownerId]!;
    }

    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(ownerId)
          .get();

      final data = ownerDoc.data();
      final ownerCode = (data?["ownerCode"] as String?) ?? "--";

      _ownerCodeCache[ownerId] = ownerCode;
      return ownerCode;
    } catch (e) {
      return "--";
    }
  }

  Future<void> _saveSignature(String contractId) async {
    if (_signaturePoints.isEmpty) {
      showAppWarningBanner(context, "Please sign the contract first.");
      return;
    }

    _isSaving.value = true;

    try {
      final contractDoc = await FirebaseFirestore.instance
          .collection("contracts")
          .doc(contractId)
          .get();

      final contractData = contractDoc.data();
      final currentStatus = contractData?['status'] ?? 'Pending Signature';
      final isLocked = contractData?['signatureLocked'] == true ||
          currentStatus == 'Sent to Owner';

      if (isLocked) {
        if (mounted) {
          showAppWarningBanner(context,
              "This signature is already locked and cannot be changed.");
        }
        return;
      }

      final signatureData = _signaturePoints
          .map((point) => {
                "x": point.dx,
                "y": point.dy,
              })
          .toList();

      await FirebaseFirestore.instance
          .collection("contracts")
          .doc(contractId)
          .update({
        "tenantSignature": signatureData,
        "status": "Signed by Tenant",
        "tenantSignedAt": Timestamp.now(),
      });

      if (mounted) {
        Navigator.pop(context);
      }

      _signaturePoints.clear();

      if (mounted) {
        showAppSuccessBanner(context, "Signature saved successfully.");
      }
    } catch (e) {
      if (mounted) {
        showAppWarningBanner(context, friendlyAuthError(e));
      }
    } finally {
      if (mounted) {
        _isSaving.value = false;
      }
    }
  }

  Future<void> _sendToOwner(String contractId) async {
    await FirebaseFirestore.instance
        .collection("contracts")
        .doc(contractId)
        .update({
      "status": "Sent to Owner",
      "signatureLocked": true,
      "tenantSentAt": Timestamp.now(),
    });

    if (mounted) {
      showAppSuccessBanner(context, "Contract sent to owner.");
    }
  }

  // =====================================================
  // E-SIGN DIALOG
  // =====================================================
  void _showSignatureDialog({
    required String contractId,
    required String roomNumber,
  }) {
    _signaturePoints.clear();
    _isSaving.value = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final bool hasSignature = _signaturePoints.isNotEmpty;

            // Kulay ng signature pad (madilim sa dark mode, puti sa light).
            final Color padColor =
                _isDark ? const Color(0xFF12171A) : Colors.white;
            final Color inkColor = _isDark ? const Color(0xFFE8EEF0) : _navy;
            final Color guideColor = _isDark
                ? Colors.white.withOpacity(0.12)
                : const Color(0xFFDCE6EA);
            final Color hintColor =
                _isDark ? Colors.white.withOpacity(0.20) : Colors.grey.shade300;

            return Dialog(
              backgroundColor: _cardColor,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ============ HEADER ============
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.draw_outlined,
                              color: _accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "E-Sign Contract",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Rental Contract · Room $roomNumber",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close,
                              color: _textSecondary,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Text(
                        "Draw your signature inside the box below.",
                        style: TextStyle(fontSize: 13, color: _textSecondary),
                      ),

                      const SizedBox(height: 10),

                      // ============ SIGNATURE PAD ============
                      Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: padColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasSignature
                                ? _accent.withOpacity(0.55)
                                : _fieldBorder,
                            width: 1.4,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            children: [
                              // Guide line + "x" na marka
                              Positioned(
                                left: 18,
                                right: 18,
                                bottom: 56,
                                child: Container(
                                  height: 1.2,
                                  color: guideColor,
                                ),
                              ),
                              Positioned(
                                left: 18,
                                bottom: 62,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: hintColor,
                                ),
                              ),

                              // Hint na nawawala kapag may sinusulat na
                              if (!hasSignature)
                                Center(
                                  child: Text(
                                    "Sign here",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: hintColor,
                                    ),
                                  ),
                                ),

                              // Lugar na sinusulatan
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (details) {
                                    setDialogState(() {
                                      _signaturePoints
                                          .add(details.localPosition);
                                    });
                                  },
                                  onPanUpdate: (details) {
                                    setDialogState(() {
                                      _signaturePoints
                                          .add(details.localPosition);
                                    });
                                  },
                                  child: CustomPaint(
                                    size: Size.infinite,
                                    painter: SignaturePainter(
                                      _signaturePoints,
                                      color: inkColor,
                                      strokeWidth: 2.6,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Center(
                        child: Text(
                          "By signing, you agree to the terms of this contract.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: _textSecondary),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ============ BUTTONS ============
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _textPrimary,
                                disabledForegroundColor:
                                    _textSecondary.withOpacity(0.5),
                                side: BorderSide(color: _fieldBorder),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: hasSignature
                                  ? () {
                                      setDialogState(() {
                                        _signaturePoints.clear();
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                "Clear",
                                maxLines: 1,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _isSaving,
                              builder: (context, saving, _) {
                                return ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accent,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        _accent.withOpacity(0.25),
                                    disabledForegroundColor: Colors.white70,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: (saving || !hasSignature)
                                      ? null
                                      : () => _saveSignature(contractId),
                                  child: saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check, size: 18),
                                            SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                "Save Signature",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // STATUS DISPLAY HELPERS
  Color _statusColor(String status) {
    switch (status) {
      case "Signed by Tenant":
        return _blue;
      case "Sent to Owner":
        return _green;
      default:
        // Slate; mas maliwanag sa dark mode para mabasa.
        return _isDark ? const Color(0xFF9FB4C2) : _slate;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "Signed by Tenant":
        return Icons.edit_document;
      case "Sent to Owner":
        return Icons.mark_email_read_outlined;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  // SMALL DETAIL ROW (icon + label + value)
  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _textSecondary),
          const SizedBox(width: 10),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Maliit na action button (Review & Sign / Send to Owner).
  Widget _compactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            _isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
        disabledForegroundColor: _textSecondary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not logged in"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("contracts")
            .where("tenantId", isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: _textPrimary),
            );
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'Pending Signature';
            return !_inactiveStatuses.contains(status);
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: _textSecondary.withOpacity(0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No contracts found",
                    style: TextStyle(fontSize: 16, color: _textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final contractId = docs[index].id;
              final data = docs[index].data() as Map<String, dynamic>;

              final roomNumber = data["roomNumber"] ?? "Room";
              final ownerId = data["ownerId"] ?? "";
              final status = data["status"] ?? "Pending Signature";
              final terms = data["termsAndConditions"] ?? "";
              final electricRate = data["electricRate"] ?? 0;
              final waterRate = data["waterRate"] ?? 0;

              Timestamp? startTimestamp = data["startDate"];
              Timestamp? endTimestamp = data["endDate"];
              Timestamp? createdTimestamp = data["createdAt"];

              String startDate = "--";
              String endDate = "--";
              String createdDate = "--";

              if (startTimestamp != null) {
                startDate =
                    DateFormat("MMM dd, yyyy").format(startTimestamp.toDate());
              }

              if (endTimestamp != null) {
                endDate =
                    DateFormat("MMM dd, yyyy").format(endTimestamp.toDate());
              }

              if (createdTimestamp != null) {
                createdDate = DateFormat("MMM dd, yyyy")
                    .format(createdTimestamp.toDate());
              }

              final bool isSigned = status == "Signed by Tenant";
              final bool isSentToOwner = status == "Sent to Owner";
              final Color statusColor = _statusColor(status);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: _isDark
                      ? Border.all(color: Colors.white.withOpacity(0.08))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isDark ? 0.25 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= HEADER =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(_isDark ? 0.12 : 0.08),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.article_outlined,
                              color: statusColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Rental Contract",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary,
                                  ),
                                ),
                                Text(
                                  "Room $roomNumber",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _statusIcon(status),
                                  size: 13,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ================= DETAILS =================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow(
                            icon: Icons.meeting_room_outlined,
                            label: "Room",
                            value: roomNumber.toString(),
                          ),
                          FutureBuilder<String>(
                            future: _getOwnerCode(ownerId),
                            builder: (context, ownerSnapshot) {
                              final displayCode =
                                  ownerSnapshot.data ?? "Loading...";
                              return _detailRow(
                                icon: Icons.badge_outlined,
                                label: "Owner ID",
                                value: displayCode,
                              );
                            },
                          ),
                          _detailRow(
                            icon: Icons.flash_on_outlined,
                            label: "Electric Rate",
                            value: "₱$electricRate per kWh",
                          ),
                          _detailRow(
                            icon: Icons.water_drop_outlined,
                            label: "Water Rate",
                            value: "₱$waterRate per m³",
                          ),
                          _detailRow(
                            icon: Icons.calendar_today_outlined,
                            label: "Start Date",
                            value: startDate,
                          ),
                          _detailRow(
                            icon: Icons.event_busy_outlined,
                            label: "End Date",
                            value: endDate,
                          ),
                          _detailRow(
                            icon: Icons.history_outlined,
                            label: "Created",
                            value: createdDate,
                          ),
                        ],
                      ),
                    ),

                    // ================= TERMS =================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _innerBoxColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.notes_outlined,
                                  size: 15,
                                  color: _textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Terms & Conditions",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              terms.isEmpty ? "No terms provided" : terms,
                              style: TextStyle(
                                fontSize: 13,
                                color: _textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                    Divider(height: 1, color: _dividerColor),

                    // ================= ACTIONS =================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                      child: Column(
                        children: [
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _compactButton(
                                  icon: isSentToOwner
                                      ? Icons.lock_outline
                                      : Icons.draw,
                                  label: isSentToOwner
                                      ? "Signature Locked"
                                      : "Review & Sign",
                                  color: _accent,
                                  onPressed: isSentToOwner
                                      ? null
                                      : () => _showSignatureDialog(
                                            contractId: contractId,
                                            roomNumber: roomNumber.toString(),
                                          ),
                                ),
                                if (isSigned && !isSentToOwner)
                                  _compactButton(
                                    icon: Icons.send,
                                    label: "Send to Owner",
                                    color: _green,
                                    onPressed: () => _sendToOwner(contractId),
                                  ),
                              ],
                            ),
                          ),
                          if (isSentToOwner) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _green.withOpacity(0.30),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified_outlined,
                                    color: _green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Signature is locked and sent to owner for verification.",
                                      style: TextStyle(
                                        color: _isDark
                                            ? const Color(0xFF6FDC9E)
                                            : Colors.green.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  // Ang default na kulay ay hindi ginalaw para hindi maapektuhan ang ibang
  // screen na gumagamit ng SignaturePainter.
  SignaturePainter(
    this.points, {
    this.color = Colors.deepOrange,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    if (points.length < 2) {
      if (points.isNotEmpty) {
        canvas.drawCircle(points.first, strokeWidth / 2 + 0.5, paint);
      }
      return;
    }

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) {
    return true;
  }
}
