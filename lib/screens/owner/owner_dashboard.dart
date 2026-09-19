import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;

import 'owner_rooms_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../owner_esign/contract_list_screen.dart';

import 'payment_requests_screen.dart';
import 'upload_qr_screen.dart';
import '../../widgets/app_warning_banner.dart';
import '../../widgets/rentpay_backdrop.dart';
import '../../widgets/juggernaut_chat_screen.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../../main.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _selectedIndex = 0;
  String? _profileImageOverride;

  // ===== THEME-AWARE COLORS (dark mode support) =====
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary => _isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);
  Color get _textSecondary => _isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);
  Color get _panelTint => _isDark ? const Color(0xCC1B2124) : const Color(0xB8FFFFFF);
  Color get _panelBorder => _isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.82);
  Color get _avatarBg => _isDark ? const Color(0xFF232A2E) : const Color(0xD9FFFFFF);
  Color get _navBg => _isDark ? const Color(0xFF15191B).withOpacity(0.92) : Colors.white.withOpacity(0.92);
  Color get _navIndicator => _isDark ? const Color(0xFF26313A) : const Color(0xFFE5F1F3);
  Color get _iconCircleBg => _isDark ? Colors.white.withOpacity(0.12) : const Color(0x66FFFFFF);

  @override
  void initState() {
    super.initState();
    generateOwnerCode();
    _refreshOverdue();
  }

  // Sinusuri kung aling rooms ang overdue at ina-update ang isOverdue field.
  Future<void> _refreshOverdue() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      await FirestoreService().checkOverdueRooms(ownerId: user.uid);
    } catch (error) {
      debugPrint("OVERDUE CHECK ERROR: $error");
    }
  }

  Future<void> generateOwnerCode() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final data = doc.data();

    if (data == null ||
        data["ownerCode"] == null ||
        data["ownerCode"].toString().isEmpty) {
      final random = Random();

      String code = (100000 + random.nextInt(900000)).toString();

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({
        "ownerCode": code,
        "role": "owner",
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      appBar: _selectedIndex == 0 || _selectedIndex == 4
          ? AppBar(
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
              leading: user != null ? _buildNotificationButton(user.uid) : null,
              actions: [
                _buildDarkModeButton(),
              ],
            )
          : null,
      body: _selectedIndex == 0
          ? RentPayBackdrop(
              child: user == null
                  ? const Center(child: Text("Not logged in"))
                  : StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("users")
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              "Unable to load tenant information: ${snapshot.error}",
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>;

                        final String ownerCode = userData["ownerCode"] ?? "------";
                        final String name = userData["name"] ?? "Owner";
                        final String? profileImageUrl =
                            _profileImageOverride ?? userData["profileImageUrl"];

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("rooms")
                              .where("ownerId", isEqualTo: user.uid)
                              .snapshots(),
                          builder: (context, roomsSnapshot) {
                            if (!roomsSnapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final rooms = roomsSnapshot.data!.docs;
                            final totalRooms = rooms.length;
                            final occupiedRooms = rooms.where((room) {
                              final data = room.data() as Map<String, dynamic>;
                              final tenantId = data["tenantId"]?.toString() ?? "";
                              return tenantId.isNotEmpty;
                            }).length;
                            final availableRooms = totalRooms - occupiedRooms;
                            final totalCollection = rooms.fold<double>(0, (total, room) {
                              final data = room.data() as Map<String, dynamic>;
                              return total + (data["amountPaid"] ?? 0).toDouble();
                            });

                            int paidPayments = 0;
                            int pendingPayments = 0;
                            int partialPayments = 0;
                            int overduePayments = 0;

                            for (final room in rooms) {
                              final data = room.data() as Map<String, dynamic>;

                              final tenantId = data["tenantId"]?.toString() ?? "";

                              // Huwag bilangin ang vacant room sa payment status.
                              if (tenantId.isEmpty) {
                                continue;
                              }

                              final status = (data["paymentStatus"] ?? "pending")
                                  .toString()
                                  .toLowerCase()
                                  .trim();

                              final isOverdue = data["isOverdue"] == true;

                              if (isOverdue || status == "overdue") {
                                overduePayments++;
                              } else if (status == "paid") {
                                paidPayments++;
                              } else if (status == "partial") {
                                partialPayments++;
                              } else {
                                pendingPayments++;
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 28, 16, 3),
                              child: Column(
                                children: [
                                  _buildOwnerHeader(name, ownerCode, profileImageUrl),
                                  const SizedBox(height: 20),
                                  _buildCollectionCard(
                                    totalCollection: totalCollection,
                                    ownerId: user.uid,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildOverviewCard(
                                    totalRooms: totalRooms,
                                    occupiedRooms: occupiedRooms,
                                    availableRooms: availableRooms,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPaymentStatusCard(
                                    paidRooms: paidPayments,
                                    pendingPayments: pendingPayments,
                                    partialPayments: partialPayments,
                                    overduePayments: overduePayments,
                                  ),
                                  const Spacer(),
                                  // Pindutin ang Juggernaut card para buksan ang AI chat.
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const JuggernautChatScreen(),
                                        ),
                                      );
                                    },
                                    child: _buildJuggernautCard(),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            )
          : (_selectedIndex >= 1 && _selectedIndex <= 3 && user != null)
              // Ang Rooms, Payments at Contracts ay may sariling AppBar, kaya
              // inilalagay ang bell sa ibabaw nito, sa parehong pwesto ng bell
              // sa AppBar ng Home at More.
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildOwnerTabBody(user),
                    Positioned(
                      left: 0,
                      top: MediaQuery.of(context).padding.top,
                      child: Material(
                        type: MaterialType.transparency,
                        child: SizedBox(
                          width: 56,
                          height: kToolbarHeight,
                          child: _buildNotificationButton(user.uid),
                        ),
                      ),
                    ),
                  ],
                )
              : _buildOwnerTabBody(user),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: _navBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _navIndicator,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 0) {
            _refreshOverdue();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room),
            label: "Rooms",
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: "Payments",
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: "Contracts",
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more),
            label: "More",
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1 && user != null
          ? SizedBox(
              height: 36,
              child: FloatingActionButton.extended(
                heroTag: "createRoomFab",
                onPressed: () => _showCreateRoomDialog(context, user.uid),
                backgroundColor: const Color(0xE6FFFFFF),
                foregroundColor: _textPrimary,
                elevation: 1,
                extendedPadding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                icon: const Icon(Icons.add_home, size: 15),
                label: const Text("Create Room", style: TextStyle(fontSize: 11)),
              ),
            )
          : null,
    );
  }

  // =====================================================
  // DARK MODE TOGGLE BUTTON
  // =====================================================

  Widget _buildDarkModeButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (context, currentMode, _) {
          final isDark = currentMode == ThemeMode.dark;
          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: _iconCircleBg, shape: BoxShape.circle),
              child: Icon(
                isDark ? Icons.dark_mode : Icons.dark_mode_outlined,
                color: _textPrimary,
                size: 22,
              ),
            ),
          );
        },
      ),
    );
  }

  // =====================================================
  // NOTIFICATION BELL
  // Pinagsasama ang: pending payments, overdue rooms,
  // contract na hinihintay pirmahan ng tenant, at contract
  // na napirmahan na ng tenant (hindi pa nakikita ng owner).
  // =====================================================

  Widget _buildNotificationButton(String ownerId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("payments")
          .where("ownerId", isEqualTo: ownerId)
          .snapshots(),
      builder: (context, paymentsSnapshot) {
        final int pendingCount = paymentsSnapshot.data?.docs.where((payment) {
              final data = payment.data() as Map<String, dynamic>;
              return (data["status"] ?? "pending")
                      .toString()
                      .toLowerCase() ==
                  "pending";
            }).length ??
            0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("rooms")
              .where("ownerId", isEqualTo: ownerId)
              .snapshots(),
          builder: (context, roomsSnapshot) {
            // Mga room na may tenant pero overdue ang bayad.
            final List<Map<String, String>> overdueRooms = [];

            for (final room in roomsSnapshot.data?.docs ?? []) {
              final data = room.data() as Map<String, dynamic>;
              final String tenantId = data["tenantId"]?.toString() ?? "";

              if (tenantId.isNotEmpty && data["isOverdue"] == true) {
                overdueRooms.add({
                  "room": (data["roomNumber"] ?? "?").toString(),
                  "tenantId": tenantId,
                });
              }
            }

            overdueRooms.sort((a, b) => a["room"]!.compareTo(b["room"]!));

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("contracts")
                  .where("ownerId", isEqualTo: ownerId)
                  .snapshots(),
              builder: (context, contractsSnapshot) {
                const inactiveStatuses = [
                  "Expired",
                  "Cancelled",
                  "Terminated",
                  "Renewed",
                ];

                // Na-send na pero hindi pa pumipirma ang tenant.
                final List<Map<String, String>> waitingContracts = [];
                // Pumirma na ang tenant pero hindi pa nakikita ng owner.
                final List<Map<String, String>> signedContracts = [];

                for (final doc in contractsSnapshot.data?.docs ?? []) {
                  final data = doc.data() as Map<String, dynamic>;

                  final String status =
                      (data["status"] ?? "Pending Signature").toString();

                  if (inactiveStatuses.contains(status)) continue;

                  final signature = data["tenantSignature"];
                  final bool hasSignature =
                      signature is List && signature.isNotEmpty;

                  final Map<String, String> item = {
                    "id": doc.id,
                    "room": (data["roomNumber"] ?? "?").toString(),
                    "tenant": (data["tenantName"] ?? "Tenant").toString(),
                  };

                  if (hasSignature) {
                    if (data["ownerSeenSignedAt"] == null) {
                      signedContracts.add(item);
                    }
                  } else if (data["useDigitalContract"] != false) {
                    waitingContracts.add(item);
                  }
                }

                waitingContracts
                    .sort((a, b) => a["room"]!.compareTo(b["room"]!));
                signedContracts
                    .sort((a, b) => a["room"]!.compareTo(b["room"]!));

                final int count = pendingCount +
                    overdueRooms.length +
                    waitingContracts.length +
                    signedContracts.length;

                // Ang bell ay kapareho ng dark mode button: ang InkWell ay nasa
                // mismong 42x42 na bilog lang, kaya pareho ang laki ng pindot.
                // Ang badge ay nasa labas ng InkWell at hindi humaharang sa tap.
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Center(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                if (count > 0) {
                                  _showNotificationPanel(
                                    ownerId: ownerId,
                                    pendingCount: pendingCount,
                                    overdueRooms: overdueRooms,
                                    waitingContracts: waitingContracts,
                                    signedContracts: signedContracts,
                                  );
                                }
                              },
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _iconCircleBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.notifications,
                                  color: _textPrimary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),

                          if (count > 0)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE93636),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    count > 99 ? "99+" : "$count",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
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
      },
    );
  }

  // Notification panel na lumalabas sa ilalim ng bell (hindi na sa ibaba ng screen).
  // - Contract na napirmahan ng tenant -> Contracts tab (minamarkahang "seen")
  // - Payment na hinihintay ang approval -> Payments tab
  // - Overdue na room -> Contracts tab
  // - Contract na hinihintay pirmahan ng tenant -> Contracts tab
  void _showNotificationPanel({
    required String ownerId,
    required int pendingCount,
    required List<Map<String, String>> overdueRooms,
    required List<Map<String, String>> waitingContracts,
    required List<Map<String, String>> signedContracts,
  }) {
    final Stream<QuerySnapshot> tenantsStream =
        FirestoreService().getOwnerTenants(ownerId);

    final int total = pendingCount +
        overdueRooms.length +
        waitingContracts.length +
        signedContracts.length;
    final String paymentLabel = pendingCount == 1 ? 'payment' : 'payments';

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Notifications",
      barrierColor: Colors.black.withOpacity(0.18),
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final double topInset =
            MediaQuery.of(dialogContext).padding.top + kToolbarHeight + 4;

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 16),
            child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 460),
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xF01B2124)
                          : const Color(0xF2FFFFFF),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _panelBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7196A3).withOpacity(0.18),
                          blurRadius: 26,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // HEADER
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
                          child: Row(
                            children: [
                              Text(
                                "Notifications",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE93636),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "$total",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Spacer(),
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
                        ),

                        // NOTIFICATION LIST
                        Flexible(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: tenantsStream,
                            builder: (context, tenantSnapshot) {
                              final Map<String, String> tenantNames = {};

                              for (final tenant
                                  in tenantSnapshot.data?.docs ?? []) {
                                final tenantData =
                                    tenant.data() as Map<String, dynamic>;
                                tenantNames[tenant.id] =
                                    (tenantData["name"] ?? "")
                                        .toString()
                                        .trim();
                              }

                              String overdueSubtitle(String? tenantName) {
                                if (tenantName == null || tenantName.isEmpty) {
                                  return "The tenant has not paid yet";
                                }
                                return "$tenantName has not paid yet";
                              }

                              return ListView(
                                shrinkWrap: true,
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 14),
                                children: [
                                  // TENANT SIGNED (berde)
                                  for (final item in signedContracts)
                                    _buildNotificationTile(
                                      icon: Icons.check_circle,
                                      color: const Color(0xFF1EBA63),
                                      title:
                                          "Room ${item["room"]} - Contract signed",
                                      subtitle:
                                          "${item["tenant"]} signed the contract",
                                      onTap: () async {
                                        Navigator.pop(dialogContext);
                                        setState(() {
                                          _selectedIndex = 3;
                                        });

                                        // Markahan bilang "seen" para mawala sa bell.
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection("contracts")
                                              .doc(item["id"])
                                              .update({
                                            "ownerSeenSignedAt":
                                                Timestamp.now(),
                                          });
                                        } catch (error) {
                                          debugPrint(
                                              "MARK SIGNED SEEN ERROR: $error");
                                        }
                                      },
                                    ),

                                  // PENDING PAYMENTS
                                  if (pendingCount > 0)
                                    _buildNotificationTile(
                                      icon: Icons.schedule,
                                      color: const Color(0xFFF2A51E),
                                      title:
                                          "$pendingCount $paymentLabel waiting for approval",
                                      subtitle: "Tap to review payments",
                                      onTap: () {
                                        Navigator.pop(dialogContext);
                                        setState(() {
                                          _selectedIndex = 2;
                                        });
                                      },
                                    ),

                                  // OVERDUE ROOMS
                                  for (final item in overdueRooms)
                                    _buildNotificationTile(
                                      icon: Icons.error,
                                      color: const Color(0xFFE93636),
                                      title:
                                          "Room ${item["room"]} - Payment overdue",
                                      subtitle: overdueSubtitle(
                                        tenantNames[item["tenantId"]],
                                      ),
                                      onTap: () {
                                        Navigator.pop(dialogContext);
                                        setState(() {
                                          _selectedIndex = 3;
                                        });
                                      },
                                    ),

                                  // WAITING FOR TENANT SIGNATURE (asul)
                                  for (final item in waitingContracts)
                                    _buildNotificationTile(
                                      icon: Icons.hourglass_top,
                                      color: const Color(0xFF3E8BEA),
                                      title:
                                          "Room ${item["room"]} - Waiting for signature",
                                      subtitle:
                                          "${item["tenant"]} has not signed the contract yet",
                                      onTap: () {
                                        Navigator.pop(dialogContext);
                                        setState(() {
                                          _selectedIndex = 3;
                                        });
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: color.withOpacity(0.10),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(0.25)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.18),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: _textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerHeader(String name, String ownerCode, String? profileImageUrl) {
    return Column(
      children: [
        GestureDetector(
          onTap: _chooseOwnerImageSource,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: Container(
                  width: 116,
                  height: 116,
                  color: _avatarBg,
                  child: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? Image.network(
                          profileImageUrl,
                          width: 116,
                          height: 116,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 42,
                            color: Color(0xFFE88916),
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_outlined,
                          size: 38,
                          color: Color(0xFFE88916),
                        ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _textPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, size: 17, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        Text(
          ownerCode,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Color(0xFFE97818),
          ),
        ),
        const SizedBox(height: 2),
        Text("Owner Code", style: TextStyle(color: _textSecondary, fontSize: 11)),
      ],
    );
  }

  Future<void> _chooseOwnerImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text(
              "Update profile photo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text("Take a photo"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("Choose from gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source != null) {
      await _pickOwnerProfileImage(source);
    }
  }

  Future<void> _pickOwnerProfileImage(ImageSource source) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 78);

    if (picked == null || !mounted) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Profile Photo',
          toolbarColor: _textPrimary,
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
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final imageUrl = await uploadToCloudinary(File(croppedFile.path));
      if (imageUrl == null) {
        throw Exception("Unable to upload profile image");
      }

      final versionedImageUrl =
          "$imageUrl?v=${DateTime.now().millisecondsSinceEpoch}";
      await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
        "profileImageUrl": versionedImageUrl,
        "profileImageUpdatedAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _profileImageOverride = versionedImageUrl;
        });
        Navigator.of(context).pop();
        showAppSuccessBanner(context, "Profile photo updated");
      }
    } catch (error) {
      if (mounted) {
        Navigator.of(context).pop();
        showAppWarningBanner(context, "Unable to update profile image");
      }
    }
  }

  Widget _buildOverviewCard({
    required int totalRooms,
    required int occupiedRooms,
    required int availableRooms,
  }) {
    return _buildDashboardPanel(
      title: "Property Overview",
      icon: Icons.home_work,
      child: Row(
        children: [
          _buildOverviewMetric(Icons.home_work_outlined, totalRooms, "Total Rooms", const Color(0xFFE88916)),
          _buildOverviewMetric(Icons.person, occupiedRooms, "Total Tenants", const Color(0xFF2BB98A)),
          _buildOverviewMetric(Icons.person_pin, occupiedRooms, "Occupied", const Color(0xFF3E8BEA)),
          _buildOverviewMetric(Icons.radio_button_unchecked, availableRooms, "Available", const Color(0xFF9EA7AA)),
        ],
      ),
    );
  }

  Widget _buildOverviewMetric(IconData icon, int value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.13),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(height: 5),
          Text(
            "$value",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textPrimary),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard({
    required double totalCollection,
    required String ownerId,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
          decoration: BoxDecoration(
            color: _panelTint,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: _panelBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7196A3).withOpacity(0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFFFA02E),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 21,
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Monthly Collection",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "₱${totalCollection.toStringAsFixed(2)}",
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // TRANSPARENT HISTORY BUTTON
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showCollectionHistory(
                  context,
                  ownerId,
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.history_rounded,
                    color: _textPrimary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCollectionHistory(
    BuildContext context,
    String ownerId,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: _textPrimary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Collection History",
                  style: TextStyle(fontSize: 19),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("rooms")
                  .where("ownerId", isEqualTo: ownerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text("Unable to load collection history"),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final historyItems = <Map<String, dynamic>>[];

                for (final room in snapshot.data!.docs) {
                  final roomData =
                      room.data() as Map<String, dynamic>;

                  final roomNumber =
                      (roomData["roomNumber"] ?? "Unknown").toString();

                  final history = roomData["history"];

                  if (history is! Map) continue;

                  for (final entry in history.entries) {
                    final month = entry.key.toString();
                    final historyData = entry.value;

                    if (historyData is! Map) continue;

                    historyItems.add({
                      "roomNumber": roomNumber,
                      "month": month,
                      "totalBill": historyData["totalBill"] ?? 0,
                      "amountPaid": historyData["amountPaid"] ?? 0,
                      "paymentStatus":
                          historyData["paymentStatus"] ?? "unpaid",
                      "carriedOverBalance":
                          historyData["carriedOverBalance"] ?? 0,
                    });
                  }
                }

                historyItems.sort((a, b) {
                  final monthA = a["month"].toString();
                  final monthB = b["month"].toString();

                  return monthB.compareTo(monthA);
                });

                if (historyItems.isEmpty) {
                  return const Center(
                    child: Text("No collection history yet"),
                  );
                }

                return ListView.separated(
                  itemCount: historyItems.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final item = historyItems[index];

                    final double totalBill =
                        (item["totalBill"] as num).toDouble();

                    final double amountPaid =
                        (item["amountPaid"] as num).toDouble();

                    final double carriedOver =
                        (item["carriedOverBalance"] as num)
                            .toDouble();

                    final String status =
                        item["paymentStatus"].toString();

                    Color statusColor;

                    switch (status.toLowerCase()) {
                      case "paid":
                        statusColor = Colors.green;
                        break;
                      case "partial":
                        statusColor = Colors.blue;
                        break;
                      case "overdue":
                        statusColor = Colors.red;
                        break;
                      default:
                        statusColor = Colors.orange;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Room ${item["roomNumber"]}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              item["month"].toString(),
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Total Bill: ₱${totalBill.toStringAsFixed(2)}",
                        ),

                        Text(
                          "Amount Paid: ₱${amountPaid.toStringAsFixed(2)}",
                        ),

                        if (carriedOver > 0)
                          Text(
                            "Carried Over: ₱${carriedOver.toStringAsFixed(2)}",
                          ),

                        const SizedBox(height: 4),

                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentStatusCard({
    required int paidRooms,
    required int pendingPayments,
    required int partialPayments,
    required int overduePayments,
  }) {
    return _buildDashboardPanel(
      title: "Payment Status",
      icon: Icons.receipt_long,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _buildStatusMetric(
              Icons.check_circle,
              "Paid",
              paidRooms,
              const Color(0xFF1EBA63),
            ),
          ),
          Expanded(
            child: _buildStatusMetric(
              Icons.schedule,
              "Pending",
              pendingPayments,
              const Color(0xFFF2A51E),
            ),
          ),
          Expanded(
            child: _buildStatusMetric(
              Icons.timelapse,
              "Partial",
              partialPayments,
              const Color(0xFF3E8BEA),
            ),
          ),
          Expanded(
            child: _buildStatusMetric(
              Icons.error,
              "Overdue",
              overduePayments,
              const Color(0xFFE93636),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMetric(
    IconData icon,
    String label,
    int value,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 11,
          ),
        ),
        Text(
          "$value",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildJuggernautCard() {
    return Container(
      width: double.infinity,
      height: 78,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: _panelTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _panelBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7196A3).withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              color: Colors.white,
              padding: const EdgeInsets.all(3),
              child: Image.asset(
                "assets/images/juggernaut_logo.png",
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.security, color: _textPrimary, size: 28);
                },
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Juggernaut",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textPrimary),
                ),
                SizedBox(height: 1),
                Text(
                  "AI Receipt Slasher",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: _textSecondary, size: 21),
        ],
      ),
    );
  }

  Widget _buildDashboardPanel({
    required String title,
    required IconData icon,
    required Widget child,
    Color? tint,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: tint ?? _panelTint,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: _panelBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7196A3).withOpacity(0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFFFA02E),
                    child: Icon(icon, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerTabBody(User? user) {
    if (user == null) {
      return const Center(child: Text("Not logged in"));
    }

    switch (_selectedIndex) {
      case 1:
        return OwnerRoomsScreen(ownerId: user.uid);
      case 2:
        return const PaymentRequestsScreen();
      case 3:
        return ContractListScreen();
      case 4:
        return _buildMoreTab(user.uid);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMoreTab(String ownerId) {
    return RentPayBackdrop(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Owner tools", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text("Tenant Verification"),
                  subtitle: const Text("Review uploaded tenant IDs"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTenantsDialog(context, ownerId),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.qr_code_2),
                  title: const Text("Payment QR"),
                  subtitle: const Text("Manage GCash and Maya QR codes"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UploadQrScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("Log out"),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textPrimary,
                side: const BorderSide(color: Color(0x33123E5A)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTenantsDialog(BuildContext context, String ownerId) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Center(
            child: Text(
              "Rentpay",
              style: TextStyle(
                fontFamily: 'RentpayScript',
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: _textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .where("role", isEqualTo: "tenant")
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      "Unable to load tenant IDs: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tenants = snapshot.data!.docs.where((tenant) {
                  final data = tenant.data() as Map<String, dynamic>;
                  return data["ownerId"] == ownerId;
                }).toList();

                if (tenants.isEmpty) {
                  return const Center(child: Text("No tenants found"));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: tenants.length,
                  itemBuilder: (context, index) {
                    final tenant = tenants[index];
                    final data = tenant.data() as Map<String, dynamic>;

                    final String name = data["name"] ?? "No Name";
                    final String job = data["job"] ?? "No Work";
                    final String phone = data["phone"] ?? "No Phone";
                    final String room = data["room"] ?? "No Room";
                    final String image = data["workIdUrl"] ?? "";

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (image.isEmpty) return;
                                showDialog(
                                  context: context,
                                  builder: (_) {
                                    return Dialog(
                                      child: InteractiveViewer(
                                        child: Image.network(
                                          image,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => const Center(
                                            child: Text("Unable to load Work ID image"),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: Colors.grey.shade300),
                                  image: image.isNotEmpty
                                      ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: image.isEmpty
                                    ? const Center(child: Icon(Icons.image, size: 38, color: Colors.grey))
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xff1D1D1F)),
                            ),
                            const SizedBox(height: 4),
                            Text("Job: $job", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text("Phone: $phone", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text("Room: $room", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close", style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassPanel({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _panelTint,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _panelBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B6048).withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context, String ownerId) {
    final roomController = TextEditingController();
    final rentController = TextEditingController();
    final electricRateController = TextEditingController(text: "13.09");
    final waterRateController = TextEditingController(text: "30.00");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Room"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomController,
              decoration: const InputDecoration(labelText: "Room Number"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Monthly Rent"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: electricRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Electric Rate per kWh"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: waterRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Water Rate per m³"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (roomController.text.isEmpty ||
                  rentController.text.isEmpty ||
                  electricRateController.text.isEmpty ||
                  waterRateController.text.isEmpty) {
                showAppWarningBanner(context, "Please fill all fields");
                return;
              }

              await FirebaseFirestore.instance.collection("rooms").add({
                "roomNumber": roomController.text.trim(),
                "ownerId": ownerId,
                "tenantId": null,

                "monthlyRent":
                    double.tryParse(rentController.text.trim()) ?? 0,

                "electricRate":
                    double.tryParse(electricRateController.text.trim()) ?? 0,

                "waterRate":
                    double.tryParse(waterRateController.text.trim()) ?? 0,

                "paymentStatus": "pending",
                "amountPaid": 0.0,
                "isOverdue": false,

                "createdAt": Timestamp.now(),
              });

              if (!context.mounted) return;
              Navigator.pop(context);

              showAppSuccessBanner(context, "Room created successfully");
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}