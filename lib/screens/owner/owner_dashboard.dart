import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;

import 'owner_rooms_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../owner_esign/contract_list_screen.dart';

import 'payment_requests_screen.dart';
import '../shared/messages_screen.dart';
import 'upload_qr_screen.dart';
import '../../widgets/app_warning_banner.dart';
import '../../widgets/rentpay_backdrop.dart';
import '../../widgets/messenger_icon.dart';
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
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);
  Color get _panelTint =>
      _isDark ? const Color(0xCC1B2124) : const Color(0xB8FFFFFF);
  Color get _panelBorder =>
      _isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.82);
  Color get _avatarBg =>
      _isDark ? const Color(0xFF232A2E) : const Color(0xD9FFFFFF);
  Color get _navBg => _isDark
      ? const Color(0xFF15191B).withOpacity(0.92)
      : Colors.white.withOpacity(0.92);
  Color get _navIndicator =>
      _isDark ? const Color(0xFF26313A) : const Color(0xFFE5F1F3);
  // Border used for input fields/dividers inside dialogs & sheets.
  Color get _inputBorder =>
      _isDark ? const Color(0xFF3A464C) : const Color(0xFFCBD8DE);

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
              actions: const [],
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
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>;

                        final String ownerCode =
                            userData["ownerCode"] ?? "------";
                        final String name = userData["name"] ?? "Owner";
                        final String? profileImageUrl = _profileImageOverride ??
                            userData["profileImageUrl"];

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("rooms")
                              .where("ownerId", isEqualTo: user.uid)
                              .snapshots(),
                          builder: (context, roomsSnapshot) {
                            if (!roomsSnapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final rooms = roomsSnapshot.data!.docs;
                            final totalRooms = rooms.length;
                            final occupiedRooms = rooms.where((room) {
                              final data = room.data() as Map<String, dynamic>;
                              final tenantId =
                                  data["tenantId"]?.toString() ?? "";
                              return tenantId.isNotEmpty;
                            }).length;
                            final availableRooms = totalRooms - occupiedRooms;
                            final totalCollection =
                                rooms.fold<double>(0, (total, room) {
                              final data = room.data() as Map<String, dynamic>;
                              return total +
                                  (data["amountPaid"] ?? 0).toDouble();
                            });

                            int paidPayments = 0;
                            int pendingPayments = 0;
                            int partialPayments = 0;
                            int overduePayments = 0;

                            for (final room in rooms) {
                              final data = room.data() as Map<String, dynamic>;

                              final tenantId =
                                  data["tenantId"]?.toString() ?? "";

                              // Huwag bilangin ang vacant room sa payment status.
                              if (tenantId.isEmpty) {
                                continue;
                              }

                              final status =
                                  (data["paymentStatus"] ?? "pending")
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
                                  _buildOwnerHeader(
                                      name, ownerCode, profileImageUrl),
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
              // Ang Rooms, Messages at Payment QR ay may sariling AppBar, kaya
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
            icon: MessengerIcon(filled: false),
            selectedIcon: MessengerIcon(),
            label: "Messages",
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2),
            selectedIcon: Icon(Icons.qr_code_2),
            label: "Payment QR",
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more),
            label: "More",
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1 && user != null
          ? Theme(
              // Explicit override kasi may ThemeData.floatingActionButtonTheme
              // posibleng nag-a-apply ng sarili nitong default background,
              // kaya sinisiguro dito na itim talaga ito sa dark mode.
              // Ang colorScheme.surfaceTint (hindi ang per-widget
              // surfaceTintColor, na wala pa sa Flutter version na ito) ang
              // ginagamit ng M3 para sa elevation tint overlay, kaya dito
              // natin ito i-null out.
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                      surfaceTint: Colors.transparent,
                    ),
                floatingActionButtonTheme: FloatingActionButtonThemeData(
                  backgroundColor:
                      _isDark ? Colors.black : const Color(0xE6FFFFFF),
                  foregroundColor: _isDark ? Colors.white : _textPrimary,
                ),
              ),
              child: SizedBox(
                height: 36,
                child: FloatingActionButton.extended(
                  heroTag: "createRoomFab",
                  onPressed: () => _showCreateRoomDialog(context, user.uid),
                  backgroundColor:
                      _isDark ? Colors.black : const Color(0xE6FFFFFF),
                  foregroundColor: _isDark ? Colors.white : _textPrimary,
                  elevation: 1,
                  extendedPadding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: _isDark
                        ? const BorderSide(color: Color(0xFF46545B))
                        : BorderSide.none,
                  ),
                  icon: Icon(Icons.add_home,
                      size: 15, color: _isDark ? Colors.white : _textPrimary),
                  label: Text(
                    "Create Room",
                    style: TextStyle(
                      fontSize: 11,
                      color: _isDark ? Colors.white : _textPrimary,
                    ),
                  ),
                ),
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
            child: SizedBox(
              width: 42,
              height: 42,
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
              return (data["status"] ?? "pending").toString().toLowerCase() ==
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

                // Mga bagong message mula sa tenants (hindi pa nababasa).
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("chats")
                      .where("ownerId", isEqualTo: ownerId)
                      .snapshots(),
                  builder: (context, chatsSnapshot) {
                    final List<Map<String, dynamic>> messageChats = [];

                    for (final doc in chatsSnapshot.data?.docs ?? []) {
                      final data = doc.data() as Map<String, dynamic>;
                      final int unread =
                          (data["unreadOwner"] as num?)?.toInt() ?? 0;

                      if (unread <= 0) continue;

                      final lastAt = data["lastMessageAt"];

                      messageChats.add({
                        "tenantId": (data["tenantId"] ?? "").toString(),
                        "unread": unread,
                        "lastMessage": (data["lastMessage"] ?? "").toString(),
                        "time": lastAt is Timestamp
                            ? lastAt.millisecondsSinceEpoch
                            : DateTime.now().millisecondsSinceEpoch,
                      });
                    }

                    // Pinakabagong message muna
                    messageChats.sort(
                      (a, b) => (b["time"] as int).compareTo(a["time"] as int),
                    );

                    final int count = pendingCount +
                        overdueRooms.length +
                        waitingContracts.length +
                        signedContracts.length +
                        messageChats.length;

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
                                        messageChats: messageChats,
                                      );
                                    }
                                  },
                                  child: SizedBox(
                                    width: 42,
                                    height: 42,
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
      },
    );
  }

  // Notification panel na lumalabas sa ilalim ng bell (hindi na sa ibaba ng screen).
  // - Bagong message mula sa tenant -> bubukas ang chat nila
  // - Contract na napirmahan ng tenant -> Contracts screen (mula sa More) (minamarkahang "seen")
  // - Payment na hinihintay ang approval -> Payments screen (mula sa More)
  // - Overdue na room -> Contracts screen (mula sa More)
  // - Contract na hinihintay pirmahan ng tenant -> Contracts screen (mula sa More)
  void _showNotificationPanel({
    required String ownerId,
    required int pendingCount,
    required List<Map<String, String>> overdueRooms,
    required List<Map<String, String>> waitingContracts,
    required List<Map<String, String>> signedContracts,
    required List<Map<String, dynamic>> messageChats,
  }) {
    final Stream<QuerySnapshot> tenantsStream =
        FirestoreService().getOwnerTenants(ownerId);

    final int total = pendingCount +
        overdueRooms.length +
        waitingContracts.length +
        signedContracts.length +
        messageChats.length;
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
                              final Map<String, String> tenantImages = {};
                              final Map<String, String> tenantRooms = {};

                              for (final tenant
                                  in tenantSnapshot.data?.docs ?? []) {
                                final tenantData =
                                    tenant.data() as Map<String, dynamic>;
                                tenantNames[tenant.id] =
                                    (tenantData["name"] ?? "")
                                        .toString()
                                        .trim();
                                tenantImages[tenant.id] =
                                    (tenantData["profileImageUrl"] ?? "")
                                        .toString();
                                tenantRooms[tenant.id] =
                                    (tenantData["room"] ?? "").toString();
                              }

                              String messageSender(String tenantId) {
                                final name = tenantNames[tenantId];
                                return (name == null || name.isEmpty)
                                    ? "your tenant"
                                    : name;
                              }

                              String messagePreview(Map<String, dynamic> chat) {
                                final int unread = chat["unread"] as int;
                                final String last =
                                    (chat["lastMessage"] ?? "").toString();

                                if (unread > 1) return "$unread new messages";
                                if (last.isEmpty) return "Tap to open the chat";

                                return last.length > 60
                                    ? "${last.substring(0, 60)}..."
                                    : last;
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
                                  // NEW MESSAGES (lila)
                                  for (final chat in messageChats)
                                    _buildNotificationTile(
                                      icon: Icons.chat_bubble,
                                      color: const Color(0xFF8B5CF6),
                                      title:
                                          "New message from ${messageSender(chat["tenantId"] as String)}",
                                      subtitle: messagePreview(chat),
                                      onTap: () {
                                        final String tenantId =
                                            chat["tenantId"] as String;
                                        final navigator =
                                            Navigator.of(this.context);
                                        Navigator.pop(dialogContext);
                                        navigator.push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                OwnerTenantChatScreen(
                                              ownerId: ownerId,
                                              tenantId: tenantId,
                                              tenantName:
                                                  tenantNames[tenantId] ?? "",
                                              tenantImageUrl:
                                                  tenantImages[tenantId],
                                              room: tenantRooms[tenantId],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

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
                                        // Nasa More na ang Contracts, kaya
                                        // bubuksan ang Contracts screen.
                                        final navigator =
                                            Navigator.of(this.context);
                                        Navigator.pop(dialogContext);
                                        navigator.push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ContractListScreen(),
                                          ),
                                        );

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
                                        // Wala na ang Payments sa bottom nav,
                                        // kaya bubuksan ang Payments screen.
                                        final navigator =
                                            Navigator.of(this.context);
                                        Navigator.pop(dialogContext);
                                        navigator.push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const PaymentRequestsScreen(),
                                          ),
                                        );
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
                                        final navigator =
                                            Navigator.of(this.context);
                                        Navigator.pop(dialogContext);
                                        navigator.push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ContractListScreen(),
                                          ),
                                        );
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
                                        final navigator =
                                            Navigator.of(this.context);
                                        Navigator.pop(dialogContext);
                                        navigator.push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ContractListScreen(),
                                          ),
                                        );
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

  Widget _buildOwnerHeader(
      String name, String ownerCode, String? profileImageUrl) {
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
                    // Dark mode: itim ang fill (hindi ang light na
                    // _textPrimary) para makita ang puting camera icon sa
                    // itaas nito. Light mode: mananatili ang dating dark navy.
                    color: _isDark ? Colors.black : _textPrimary,
                    shape: BoxShape.circle,
                    // Border na tumutugma sa background ng screen sa halip
                    // na laging puti, para blend ito sa dark mode.
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 17, color: Colors.white),
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
        Text("Owner Code",
            style: TextStyle(color: _textSecondary, fontSize: 11)),
      ],
    );
  }

  // Theme-aware bottom sheet for choosing a profile photo source.
  Future<void> _chooseOwnerImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _isDark ? const Color(0xFF1B2124) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            Divider(color: _panelBorder, height: 1),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: _textPrimary),
              title: Text(
                "Take a photo",
                style: TextStyle(color: _textPrimary),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: _textPrimary),
              title: Text(
                "Choose from gallery",
                style: TextStyle(color: _textPrimary),
              ),
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

    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 78);

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
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final imageUrl = await uploadToCloudinary(File(croppedFile.path));
      if (imageUrl == null) {
        throw Exception("Unable to upload profile image");
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
          _buildOverviewMetric(Icons.home_work_outlined, totalRooms,
              "Total Rooms", const Color(0xFFE88916)),
          _buildOverviewMetric(Icons.person, occupiedRooms, "Total Tenants",
              const Color(0xFF2BB98A)),
          _buildOverviewMetric(Icons.person_pin, occupiedRooms, "Occupied",
              const Color(0xFF3E8BEA)),
          _buildOverviewMetric(Icons.radio_button_unchecked, availableRooms,
              "Available", const Color(0xFF9EA7AA)),
        ],
      ),
    );
  }

  Widget _buildOverviewMetric(
      IconData icon, int value, String label, Color color) {
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
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _textPrimary),
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
                backgroundColor: Color(0xFF111111),
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

  // =====================================================
  // COLLECTION HISTORY
  // Isang linya bawat na-verify na bayad, galing sa
  // "payments" collection (hindi sa running total ng room),
  // kaya kumpleto pa rin kahit nag-reset ang bill ng room.
  // =====================================================
  // =====================================================
  // COLLECTION HISTORY
  // Unang dialog: room list lang.
  // Kapag pinindot ang room, saka ipapakita ang payment records.
  // =====================================================
  void _showCollectionHistory(
    BuildContext context,
    String ownerId,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _isDark ? const Color(0xFF1B2124) : null,
          title: Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: _textPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Collection History",
                  style: TextStyle(
                    fontSize: 19,
                    color: _textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("payments")
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

                final Map<String, List<Map<String, dynamic>>> grouped = {};

                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;

                  final status = (data["status"] ?? "pending")
                      .toString()
                      .toLowerCase()
                      .trim();

                  if (status != "verified") continue;

                  final room = (data["room"] ?? "?").toString();

                  final payment = <String, dynamic>{
                    "room": room,
                    "amount": (data["amount"] as num?)?.toDouble() ?? 0.0,
                    "isPartial": data["isPartial"] == true,
                    "submittedAt": data["date"] is Timestamp
                        ? (data["date"] as Timestamp).toDate()
                        : null,
                    "verifiedAt": data["verifiedAt"] is Timestamp
                        ? (data["verifiedAt"] as Timestamp).toDate()
                        : null,
                  };

                  grouped.putIfAbsent(room, () => []).add(payment);
                }

                if (grouped.isEmpty) {
                  return Center(
                    child: Text(
                      "No collection history yet",
                      style: TextStyle(color: _textPrimary),
                    ),
                  );
                }

                final rooms = grouped.keys.toList()
                  ..sort((a, b) {
                    final roomA = int.tryParse(
                          RegExp(r'\d+').firstMatch(a)?.group(0) ?? "",
                        ) ??
                        0;
                    final roomB = int.tryParse(
                          RegExp(r'\d+').firstMatch(b)?.group(0) ?? "",
                        ) ??
                        0;

                    final numberResult = roomA.compareTo(roomB);
                    return numberResult != 0 ? numberResult : a.compareTo(b);
                  });

                return ListView.separated(
                  itemCount: rooms.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: _panelBorder,
                  ),
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final roomPayments = grouped[room]!;

                    final total = roomPayments.fold<double>(
                      0.0,
                      (sum, payment) {
                        final amount = payment["amount"];
                        final double paymentAmount = amount is num
                            ? amount.toDouble()
                            : double.tryParse(amount?.toString() ?? "0") ?? 0.0;
                        return sum + paymentAmount;
                      },
                    );

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      leading: CircleAvatar(
                        radius: 19,
                        backgroundColor: _isDark
                            ? const Color(0x33E88916)
                            : const Color(0x1AE88916),
                        child: Icon(
                          Icons.meeting_room_rounded,
                          color: const Color(0xFFE88916),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        "Room $room",
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        "${roomPayments.length} payment record(s)",
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₱${total.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: _textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: () {
                        _showRoomCollectionHistory(
                          context,
                          room,
                          roomPayments,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Close",
                style: TextStyle(color: _textPrimary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRoomCollectionHistory(
    BuildContext context,
    String room,
    List<Map<String, dynamic>> payments,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy  h:mm a');

    payments.sort((a, b) {
      final DateTime? dateA =
          (a["verifiedAt"] ?? a["submittedAt"]) as DateTime?;
      final DateTime? dateB =
          (b["verifiedAt"] ?? b["submittedAt"]) as DateTime?;

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateB.compareTo(dateA);
    });

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _isDark ? const Color(0xFF1B2124) : null,
          title: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: _textPrimary,
                ),
                tooltip: "Back to Collection History",
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.meeting_room_rounded,
                color: _textPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Room $room History",
                  style: TextStyle(
                    fontSize: 18,
                    color: _textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: ListView.separated(
              itemCount: payments.length,
              separatorBuilder: (_, __) => Divider(
                height: 16,
                color: _panelBorder,
              ),
              itemBuilder: (context, index) {
                final payment = payments[index];

                final rawAmount = payment["amount"];
                final double amount = rawAmount is num
                    ? rawAmount.toDouble()
                    : double.tryParse(rawAmount?.toString() ?? "0") ?? 0.0;

                final bool isPartial = payment["isPartial"] == true;
                final DateTime? submittedAt =
                    payment["submittedAt"] as DateTime?;
                final DateTime? verifiedAt = payment["verifiedAt"] as DateTime?;

                final badgeColor = isPartial ? Colors.blue : Colors.green;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Payment ${index + 1}",
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          "₱${amount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPartial ? "PARTIAL" : "PAID",
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (verifiedAt != null)
                      Text(
                        "Approved: ${dateFormat.format(verifiedAt)}",
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    if (submittedAt != null)
                      Text(
                        "Submitted: ${dateFormat.format(submittedAt)}",
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Close",
                style: TextStyle(color: _textPrimary),
              ),
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
              child: Image.asset('assets/images/juggernaut_logo.png',
                  fit: BoxFit.contain),
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
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary),
                ),
                SizedBox(height: 1),
                Text(
                  "AI Receipt Slasher",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _textSecondary),
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
                    backgroundColor: const Color(0xFF111111),
                    child: Icon(icon, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary),
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
        return const MessagesScreen();
      case 3:
        return const UploadQrScreen();
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
                Text(
                  "Owner tools",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.payments_outlined, color: _textPrimary),
                  title:
                      Text("Payments", style: TextStyle(color: _textPrimary)),
                  subtitle: Text("Review payment requests",
                      style: TextStyle(color: _textSecondary)),
                  trailing: Icon(Icons.chevron_right, color: _textSecondary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PaymentRequestsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.description_outlined, color: _textPrimary),
                  title:
                      Text("Contracts", style: TextStyle(color: _textPrimary)),
                  subtitle: Text("Manage tenant contracts",
                      style: TextStyle(color: _textSecondary)),
                  trailing: Icon(Icons.chevron_right, color: _textSecondary),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContractListScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.verified_user_outlined, color: _textPrimary),
                  title: Text("Tenant Verification",
                      style: TextStyle(color: _textPrimary)),
                  subtitle: Text("Review uploaded tenant IDs",
                      style: TextStyle(color: _textSecondary)),
                  trailing: Icon(Icons.chevron_right, color: _textSecondary),
                  onTap: () => _showTenantsDialog(context, ownerId),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.dark_mode_outlined, color: _textPrimary),
                  title: Text(
                    "Dark Mode",
                    style: TextStyle(color: _textPrimary),
                  ),
                  subtitle: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, currentMode, _) {
                      return Text(
                        currentMode == ThemeMode.dark
                            ? "Currently enabled"
                            : "Currently disabled",
                        style: TextStyle(color: _textSecondary),
                      );
                    },
                  ),
                  trailing: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, currentMode, _) {
                      final isDark = currentMode == ThemeMode.dark;

                      return Switch(
                        value: isDark,
                        activeColor: Colors.white,
                        activeTrackColor: Colors.grey,
                        inactiveThumbColor: Colors.black,
                        inactiveTrackColor: Colors.grey,
                        onChanged: (value) {
                          themeNotifier.value =
                              value ? ThemeMode.dark : ThemeMode.light;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              icon: Icon(Icons.logout, color: _textPrimary),
              label: Text("Log out", style: TextStyle(color: _textPrimary)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textPrimary,
                side: BorderSide(color: _panelBorder),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
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
          backgroundColor: _isDark ? const Color(0xFF1B2124) : null,
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
                      color: _isDark ? const Color(0xFF232A2E) : null,
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _panelBorder),
                      ),
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
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                            child: Text(
                                                "Unable to load Work ID image"),
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
                                  border: Border.all(color: _panelBorder),
                                  image: image.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(image),
                                          fit: BoxFit.cover)
                                      : null,
                                ),
                                child: image.isEmpty
                                    ? Center(
                                        child: Icon(Icons.image,
                                            size: 38, color: _textSecondary))
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: _textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text("Job: $job",
                                style: TextStyle(
                                    fontSize: 12, color: _textSecondary)),
                            Text("Phone: $phone",
                                style: TextStyle(
                                    fontSize: 12, color: _textSecondary)),
                            Text("Room: $room",
                                style: TextStyle(
                                    fontSize: 12, color: _textSecondary)),
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
              child: Text("Close",
                  style: TextStyle(fontSize: 12, color: _textPrimary)),
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

  // Theme-aware InputDecoration used by the Create Room dialog fields.
  InputDecoration _themedInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _textSecondary),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _inputBorder),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _textPrimary, width: 1.6),
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
        backgroundColor: _isDark ? Colors.black : null,
        title: Text(
          "Create Room",
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomController,
                style: TextStyle(color: _textPrimary),
                cursorColor: _textPrimary,
                decoration: _themedInputDecoration("Room Number"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rentController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _textPrimary),
                cursorColor: _textPrimary,
                decoration: _themedInputDecoration("Monthly Rent"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: electricRateController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _textPrimary),
                cursorColor: _textPrimary,
                decoration: _themedInputDecoration("Electric Rate per kWh"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: waterRateController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _textPrimary),
                cursorColor: _textPrimary,
                decoration: _themedInputDecoration("Water Rate per m³"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: _textSecondary)),
          ),
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
                "monthlyRent": double.tryParse(rentController.text.trim()) ?? 0,
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
            child: Text("Create",
                style: TextStyle(
                    color: _textPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
