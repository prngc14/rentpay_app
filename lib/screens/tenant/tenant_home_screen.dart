import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/app_warning_banner.dart';
import '../../widgets/rentpay_backdrop.dart';

class TenantHomeScreen extends StatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  final FirestoreService _tenantFirestoreService = FirestoreService();

  bool _contractDueNotificationShown = false;
  String? _profileImageOverride;

  static const double _avatarMaxSize = 200;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _textPrimary =>
      _isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);

  Color get _textSecondary =>
      _isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);

  Color get _avatarBg =>
      _isDark ? const Color(0xFF232A2E) : const Color(0xD9FFFFFF);

  Color get _dividerColor =>
      _isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFDCE6EA);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        _maybeSendContractDueNotification(user.uid);
      }
    });
  }

  Future<void> _maybeSendContractDueNotification(
    String tenantId,
  ) async {
    if (_contractDueNotificationShown) return;

    _contractDueNotificationShown = true;

    final shouldSend = await _tenantFirestoreService
        .shouldSendContractDueNotification(tenantId);

    if (!mounted || !shouldSend) return;

    final DateTime? dueDate =
        await _tenantFirestoreService.getNextContractDueDateForTenant(tenantId);

    if (!mounted || dueDate == null) return;

    await NotificationService.showLocalNotification(
      title: 'RentPay Reminder',
      body: 'Your contract-based rent due date is '
          '${DateFormat("MMMM dd, yyyy").format(dueDate)}. '
          'Please pay if not yet paid.',
    );
  }

  String _statusLabel(
    String paymentStatus,
    bool isOverdue,
  ) {
    if (paymentStatus == "paid") return "PAID";
    if (paymentStatus == "partial") return "PARTIAL PAYMENT";
    if (isOverdue) return "OVERDUE";

    return "UNPAID";
  }

  Color _statusColor(
    String paymentStatus,
    bool isOverdue,
  ) {
    if (paymentStatus == "paid") {
      return const Color(0xFF1EBA63);
    }

    if (paymentStatus == "partial") {
      return const Color(0xFF3E8BEA);
    }

    if (isOverdue) {
      return const Color(0xFFE93636);
    }

    return const Color(0xFFF2A51E);
  }

  IconData _statusIcon(
    String paymentStatus,
    bool isOverdue,
  ) {
    if (paymentStatus == "paid") {
      return Icons.check_circle;
    }

    if (paymentStatus == "partial") {
      return Icons.timelapse;
    }

    if (isOverdue) {
      return Icons.error;
    }

    return Icons.schedule;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text("User not logged in"),
      );
    }

    return RentPayBackdrop(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return _TenantHomeStateView(
              icon: Icons.error_outline,
              title: "Unable to load profile",
              message: userSnapshot.error.toString(),
            );
          }

          if (!userSnapshot.hasData) {
            return const _TenantHomeStateView(
              icon: Icons.home_work_outlined,
              title: "Loading your home",
              message: "Getting your room and billing details...",
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

          if (userData == null) {
            return const _TenantHomeStateView(
              icon: Icons.person_outline,
              title: "Profile unavailable",
              message: "We could not load your account details yet.",
            );
          }

          final String room = (userData["room"] ?? "").toString();

          final String ownerId = (userData["ownerId"] ?? "").toString();

          final String name = (userData["name"] ?? "Tenant").toString();

          final String? profileImageUrl =
              _profileImageOverride ?? userData["profileImageUrl"]?.toString();

          if (room.isEmpty || ownerId.isEmpty) {
            return _buildPage(
              name: name,
              profileImageUrl: profileImageUrl,
              content: const _TenantHomeStateView(
                icon: Icons.meeting_room_outlined,
                title: "No room connected yet",
                message: "Connect to your owner to view your monthly billing.",
                embedded: true,
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("rooms")
                .where(
                  "roomNumber",
                  isEqualTo: room,
                )
                .where(
                  "ownerId",
                  isEqualTo: ownerId,
                )
                .limit(1)
                .snapshots(),
            builder: (context, roomSnapshot) {
              if (roomSnapshot.hasError) {
                return _TenantHomeStateView(
                  icon: Icons.error_outline,
                  title: "Unable to load billing",
                  message: roomSnapshot.error.toString(),
                );
              }

              if (!roomSnapshot.hasData) {
                return const _TenantHomeStateView(
                  icon: Icons.receipt_long_outlined,
                  title: "Loading billing",
                  message: "Getting the latest billing details...",
                );
              }

              if (roomSnapshot.data!.docs.isEmpty) {
                return _buildPage(
                  name: name,
                  profileImageUrl: profileImageUrl,
                  content: const _TenantHomeStateView(
                    icon: Icons.search_off_outlined,
                    title: "Room not found",
                    message:
                        "Your owner may need to check the room connection.",
                    embedded: true,
                  ),
                );
              }

              final roomData =
                  roomSnapshot.data!.docs.first.data() as Map<String, dynamic>;

              final double rent = (roomData["monthlyRent"] ?? 0).toDouble();

              final double electricConsumption =
                  (roomData["electricConsumption"] ?? 0).toDouble();

              final double electricBill =
                  (roomData["electricBill"] ?? 0).toDouble();

              final double waterConsumption =
                  (roomData["waterConsumption"] ?? 0).toDouble();

              final double waterBill = (roomData["waterBill"] ?? 0).toDouble();

              final double totalBill = (roomData["totalBill"] ?? 0).toDouble();

              final double amountPaid =
                  (roomData["amountPaid"] ?? 0).toDouble();

              final double remainingBalance =
                  (roomData["remainingBalance"] ?? (totalBill - amountPaid))
                      .toDouble();

              final String paymentStatus =
                  (roomData["paymentStatus"] ?? "unpaid").toString();

              final bool isOverdue = roomData["isOverdue"] ?? false;

              final Timestamp? paidAt = roomData["paidAt"];

              String paidDate = "Not paid yet";

              if (paidAt != null) {
                paidDate = DateFormat(
                  "MMMM dd, yyyy - hh:mm a",
                ).format(paidAt.toDate());
              }

              final double displayedTotal =
                  paymentStatus == "partial" ? remainingBalance : totalBill;

              return _buildPage(
                name: name,
                profileImageUrl: profileImageUrl,
                content: _buildStatusPanel(
                  paymentStatus: paymentStatus,
                  isOverdue: isOverdue,
                  tenantId: user.uid,
                  paidDate: paidDate,
                  remainingBalance: remainingBalance,
                ),
                bottom: _buildBillingPanel(
                  room: room,
                  rent: rent,
                  electricConsumption: electricConsumption,
                  electricBill: electricBill,
                  waterConsumption: waterConsumption,
                  waterBill: waterBill,
                  displayedTotal: displayedTotal,
                  paymentStatus: paymentStatus,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPage({
    required String name,
    required String? profileImageUrl,
    required Widget content,
    Widget? bottom,
  }) {
    const EdgeInsets padding = EdgeInsets.fromLTRB(16, 4, 16, 8);

    final Widget nameText = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 23,
        height: 1.0,
        fontWeight: FontWeight.w700,
        color: _textPrimary,
      ),
    );

    final Widget tenantText = Text(
      "Tenant",
      style: TextStyle(
        color: _textSecondary,
        fontSize: 11,
        height: 1.0,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact =
            constraints.hasBoundedHeight && constraints.maxHeight < 570;

        final bool flexibleHeader = bottom != null && !compact;

        final double fixedAvatarSize = compact ? 100 : _avatarMaxSize;

        final Widget header = flexibleHeader
            ? Expanded(
                child: Column(
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _avatarMaxSize,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _buildAvatar(
                            profileImageUrl,
                          ),
                        ),
                      ),
                    ),

                    // Ibinaba nang kaunti ang name at Tenant.
                    const SizedBox(height: 12),

                    nameText,
                    tenantText,
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: fixedAvatarSize,
                    height: fixedAvatarSize,
                    child: _buildAvatar(
                      profileImageUrl,
                    ),
                  ),

                  // Ibinaba nang kaunti ang name at Tenant.
                  const SizedBox(height: 12),

                  nameText,
                  tenantText,
                ],
              );

        final Widget column = Column(
          children: [
            header,
            if (bottom != null) ...[
              const SizedBox(height: 10),
              content,
              const SizedBox(height: 8),
              bottom,
            ] else ...[
              const SizedBox(height: 16),
              content,
            ],
          ],
        );

        if (compact) {
          return SingleChildScrollView(
            padding: padding,
            child: column,
          );
        }

        return Padding(
          padding: padding,
          child: column,
        );
      },
    );
  }

  Widget _buildAvatar(String? profileImageUrl) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _chooseProfileImageSource,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: ColoredBox(
                color: _avatarBg,
                child: profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? Image.network(
                        profileImageUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) {
                          return Center(
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: _isDark
                                  ? Colors.white
                                  : const Color(0xFF111111),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: const Color(0xFF111111),
                        ),
                      ),
              ),
            ),
          ),

          // Plain camera icon lamang.
          // Walang bilog, background, border, o shadow.
          Positioned(
            right: 24,
            bottom: 12,
            child: Icon(
              Icons.camera_alt,
              size: 22,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseProfileImageSource() async {
    debugPrint("TENANT AVATAR TAPPED");

    try {
      await _showProfileImageSheet();
    } catch (error) {
      debugPrint("TENANT AVATAR ERROR: $error");

      if (mounted) {
        showAppWarningBanner(
          context,
          "Unable to open photo options: $error",
        );
      }
    }
  }

  Future<void> _showProfileImageSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1B2124) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              "Update profile photo",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Divider(
              color: _dividerColor,
              height: 1,
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt_outlined,
                color: _textPrimary,
              ),
              title: Text(
                "Take a photo",
                style: TextStyle(
                  color: _textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(
                  context,
                  ImageSource.camera,
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: _textPrimary,
              ),
              title: Text(
                "Choose from gallery",
                style: TextStyle(
                  color: _textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(
                  context,
                  ImageSource.gallery,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source != null) {
      await _pickProfileImage(source);
    }
  }

  Future<void> _pickProfileImage(
    ImageSource source,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 78,
    );

    if (picked == null || !mounted) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Profile Photo',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Adjust Profile Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
        ),
      ],
    );

    if (croppedFile == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final imageUrl = await uploadToCloudinary(
        File(croppedFile.path),
      );

      if (imageUrl == null) {
        throw Exception(
          "Unable to upload profile image",
        );
      }

      final versionedImageUrl =
          "$imageUrl?v=${DateTime.now().millisecondsSinceEpoch}";

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({
        "profileImageUrl": versionedImageUrl,
        "profileImageUpdatedAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _profileImageOverride = versionedImageUrl;
        });

        Navigator.of(context).pop();

        showAppSuccessBanner(
          context,
          "Profile photo updated",
        );
      }
    } catch (error) {
      if (mounted) {
        Navigator.of(context).pop();

        showAppWarningBanner(
          context,
          "Unable to update profile image",
        );
      }
    }
  }

  Widget _buildDashboardPanel({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? titleTrailing,
    double headerGap = 8,
    EdgeInsetsGeometry? padding,
  }) {
    return _GlassPanel(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF111111),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              if (titleTrailing != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: titleTrailing,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: headerGap),
          child,
        ],
      ),
    );
  }

  DateTime? _lastContractDue;

  // Due date ay galing lang sa contract ng tenant. Kapag walang contract,
  // "No due date" ang lalabas (at hindi rin lalabas ang OVERDUE).
  Widget _buildStatusPanel({
    required String tenantId,
    required String paymentStatus,
    required bool isOverdue,
    required String paidDate,
    required double remainingBalance,
  }) {
    return FutureBuilder<DateTime?>(
      future: _tenantFirestoreService.getNextContractDueDateForTenant(tenantId),
      initialData: _lastContractDue,
      builder: (context, snapshot) {
        final DateTime? contractDue = snapshot.data;

        if (snapshot.connectionState == ConnectionState.done) {
          _lastContractDue = contractDue;
        }

        final String dueDateText = contractDue != null
            ? DateFormat("MMMM dd, yyyy").format(contractDue)
            : "No due date";

        return _buildStatusPanelBody(
          paymentStatus: paymentStatus,
          isOverdue: isOverdue && contractDue != null,
          dueDate: dueDateText,
          paidDate: paidDate,
          remainingBalance: remainingBalance,
        );
      },
    );
  }

  Widget _buildStatusPanelBody({
    required String paymentStatus,
    required bool isOverdue,
    required String dueDate,
    required String paidDate,
    required double remainingBalance,
  }) {
    final Color color = _statusColor(
      paymentStatus,
      isOverdue,
    );

    return _buildDashboardPanel(
      title: "Payment Status",
      icon: Icons.receipt_long,
      headerGap: 6,
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        20,
      ),
      titleTrailing: Container(
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
              _statusIcon(
                paymentStatus,
                isOverdue,
              ),
              color: color,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              _statusLabel(
                paymentStatus,
                isOverdue,
              ),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              "Due Date",
              dueDate,
            ),
            const SizedBox(height: 5),
            paymentStatus == "partial"
                ? _buildInfoRow(
                    "Remaining",
                    "₱${remainingBalance.toStringAsFixed(2)}",
                  )
                : _buildInfoRow(
                    "Paid Date",
                    paidDate,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: _textSecondary,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBillingPanel({
    required String room,
    required double rent,
    required double electricConsumption,
    required double electricBill,
    required double waterConsumption,
    required double waterBill,
    required double displayedTotal,
    required String paymentStatus,
  }) {
    return _buildDashboardPanel(
      title: "Monthly Billing",
      icon: Icons.account_balance_wallet,
      headerGap: 10,
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        20,
      ),
      child: Column(
        children: [
          _buildBillingRow(
            icon: Icons.apartment,
            color: const Color(0xFF111111),
            title: "Room $room",
            subtitle: "Monthly Rent",
            amount: "₱${rent.toStringAsFixed(2)}",
          ),
          Divider(
            color: _dividerColor,
            height: 10,
            thickness: 0.8,
          ),
          _buildBillingRow(
            icon: Icons.flash_on,
            color: const Color(0xFFF2A51E),
            title: "Electricity",
            subtitle: "${electricConsumption.toStringAsFixed(1)} kWh",
            amount: "₱${electricBill.toStringAsFixed(2)}",
          ),
          Divider(
            color: _dividerColor,
            height: 10,
            thickness: 0.8,
          ),
          _buildBillingRow(
            icon: Icons.water_drop,
            color: const Color(0xFF3E8BEA),
            title: "Water",
            subtitle: "${waterConsumption.toStringAsFixed(1)} m³",
            amount: "₱${waterBill.toStringAsFixed(2)}",
          ),
          Divider(
            color: _dividerColor,
            height: 10,
            thickness: 0.8,
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 50,
              top: 5,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    paymentStatus == "partial"
                        ? "Remaining Balance"
                        : "Total Bill",
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  "₱${displayedTotal.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Color(0xFFE97818),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String amount,
  }) {
    return SizedBox(
      height: 55,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.13),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// GLASS PANEL
// =====================================================

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      16,
      12,
      16,
      16,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xCC1B2124) : const Color(0xB8FFFFFF),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.82),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7196A3).withOpacity(0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TenantHomeStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool embedded;

  const _TenantHomeStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final panel = _GlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF111111),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return panel;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: panel,
      ),
    );
  }
}
