import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../main.dart';
import 'tenant_home_screen.dart';
import 'payment_screen.dart';
import 'tenant_profile_screen.dart';
import 'tenant_connect_screen.dart';
import 'tenant_contracts_screen.dart';
import 'pending_payment_screen.dart';
import '../shared/messages_screen.dart';
import '../../widgets/app_warning_banner.dart';
import '../../widgets/messenger_icon.dart';

class TenantDashboard extends StatefulWidget {
  final bool showConnectionSuccess;
  final int initialTabIndex;

  const TenantDashboard({
    super.key,
    this.showConnectionSuccess = false,
    this.initialTabIndex = 0,
  });

  @override
  State<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  late int _currentIndex;

  final FirestoreService firestore = FirestoreService();

  // ===== THEME-AWARE COLORS (kapareho ng owner dashboard) =====
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE8EEF0) : const Color(0xFF123E5A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFFA9B4B8) : const Color(0xFF587287);
  Color get _panelBorder =>
      _isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.82);
  Color get _navBg => _isDark
      ? const Color(0xFF15191B).withOpacity(0.92)
      : Colors.white.withOpacity(0.92);
  Color get _navIndicator =>
      _isDark ? const Color(0xFF26313A) : const Color(0xFFE5F1F3);

  // Ang Payments (1) at Messages (2) ay may sariling AppBar.
  bool get _hasOwnAppBar => _currentIndex == 1 || _currentIndex == 2;

  @override
  void initState() {
    super.initState();
    // Tabs: 0 Home, 1 Payments, 2 Messages, 3 Contracts, 4 Valid IDs
    _currentIndex = widget.initialTabIndex.clamp(0, 4);
    _refreshOverdue();
    if (widget.showConnectionSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showAppSuccessBanner(context, "Room connected successfully!");
        }
      });
    }
  }

  // Sinusuri kung overdue na ang room ng tenant at ina-update ang
  // isOverdue field, kapareho ng ginagawa sa Owner Dashboard.
  Future<void> _refreshOverdue() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      await FirestoreService().checkOverdueRooms();
    } catch (error) {
      debugPrint("OVERDUE CHECK ERROR (tenant): $error");
    }
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Wait for user before loading UI
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Ang buong Scaffold ay naka-wrap sa StreamBuilder ng sariling user doc
    // ng tenant para malaman kung naka-connect na siya sa isang room
    // (para itago ang "Connect Owner" icon).
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final String room = (userData?["room"] ?? "").toString();
        final bool isConnected = room.isNotEmpty;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _hasOwnAppBar
              ? null
              : AppBar(
                  title: _currentIndex == 3
                      ? Text(
                          "Contracts",
                          style: TextStyle(color: _textPrimary),
                        )
                      : Text(
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
                  leading: _buildNotificationButton(user.uid),
                  actions: [
                    // CONNECT TO OWNER BUTTON — Home tab lang at itinatago
                    // kapag naka-connect na ang tenant.
                    if (_currentIndex == 0 && !isConnected)
                      IconButton(
                        icon: Icon(Icons.link, color: _textPrimary),
                        tooltip: "Connect Owner",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TenantConnectScreen(),
                            ),
                          );
                        },
                      ),
                    // SETTINGS BUTTON — Valid IDs tab lang.
                    if (_currentIndex == 4) _buildSettingsButton(),
                  ],
                ),
          body: _buildScaffoldBody(user.uid),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            backgroundColor: _navBg,
            surfaceTintColor: Colors.transparent,
            indicatorColor: _navIndicator,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: "Home",
              ),
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments),
                label: "Payments",
              ),
              NavigationDestination(
                icon: MessengerIcon(filled: false),
                selectedIcon: MessengerIcon(),
                label: "Messages",
              ),
              NavigationDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: "Contracts",
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: "Valid IDs",
              ),
            ],
          ),
        );
      },
    );
  }

  // =====================================================
  // BODY
  // Ang Payments at Messages ay may sariling AppBar.
  // - Payments: inilalagay ang bell sa ibabaw nito, sa parehong pwesto
  //   ng bell sa AppBar ng ibang tabs (kapareho ng owner side).
  // - Messages: WALANG bell, dahil natatakpan nito ang profile ng owner
  //   sa AppBar ng Messages.
  // =====================================================
  Widget _buildScaffoldBody(String uid) {
    final body = _buildBody(uid);

    // Bell overlay sa Payments tab lang.
    if (_currentIndex != 1) return body;

    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        Positioned(
          left: 0,
          top: MediaQuery.of(context).padding.top,
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: 56,
              height: kToolbarHeight,
              child: _buildNotificationButton(uid),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // SETTINGS BUTTON
  // Dito makikita ang Dark Mode at Log out.
  // =====================================================
  Widget _buildSettingsButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton(
        tooltip: "Settings",
        icon: Icon(
          Icons.settings_outlined,
          color: _textPrimary,
          size: 23,
        ),
        onPressed: _showSettingsDialog,
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Icon(Icons.settings_outlined, color: _textPrimary),
              const SizedBox(width: 10),
              Text(
                "Settings",
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, currentMode, _) {
                  final bool isDark = currentMode == ThemeMode.dark;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: _textPrimary,
                    ),
                    title: Text(
                      "Dark Mode",
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isDark ? "Enabled" : "Disabled",
                      style: TextStyle(color: _textSecondary),
                    ),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (value) {
                        themeNotifier.value =
                            value ? ThemeMode.dark : ThemeMode.light;
                      },
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  "Log out",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  logout();
                },
              ),
            ],
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

  // =====================================================
  // NOTIFICATION BELL
  // Pinagsasama ang: bagong message mula sa owner, overdue
  // na bayad, at contract na hinihintay pirmahan ng tenant.
  // =====================================================
  Widget _buildNotificationButton(String tenantId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("chats")
          .where("tenantId", isEqualTo: tenantId)
          .snapshots(),
      builder: (context, chatsSnapshot) {
        final List<Map<String, dynamic>> messageChats = [];

        for (final doc in chatsSnapshot.data?.docs ?? []) {
          final data = doc.data() as Map<String, dynamic>;
          final int unread = (data["unreadTenant"] as num?)?.toInt() ?? 0;

          if (unread <= 0) continue;

          final lastAt = data["lastMessageAt"];

          messageChats.add({
            "unread": unread,
            "lastMessage": (data["lastMessage"] ?? "").toString(),
            "time": lastAt is Timestamp
                ? lastAt.millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch,
          });
        }

        messageChats.sort(
          (a, b) => (b["time"] as int).compareTo(a["time"] as int),
        );

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("rooms")
              .where("tenantId", isEqualTo: tenantId)
              .snapshots(),
          builder: (context, roomsSnapshot) {
            final List<String> overdueRooms = [];

            final List<Map<String, dynamic>> billNotifications = [];

            for (final room in roomsSnapshot.data?.docs ?? []) {
              final data = room.data() as Map<String, dynamic>;

              if (data["isOverdue"] == true) {
                overdueRooms.add((data["roomNumber"] ?? "?").toString());
              }

              if (data["billUpdated"] == true) {
                billNotifications.add({
                  "id": room.id,
                  "room": (data["roomNumber"] ?? "?").toString(),
                });
              }
            }

            overdueRooms.sort();

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("contracts")
                  .where("tenantId", isEqualTo: tenantId)
                  .snapshots(),
              builder: (context, contractsSnapshot) {
                const inactiveStatuses = [
                  "Expired",
                  "Cancelled",
                  "Terminated",
                  "Renewed",
                ];

                final List<String> waitingContracts = [];

                for (final doc in contractsSnapshot.data?.docs ?? []) {
                  final data = doc.data() as Map<String, dynamic>;

                  final String status =
                      (data["status"] ?? "Pending Signature").toString();

                  if (inactiveStatuses.contains(status)) continue;

                  final signature = data["tenantSignature"];
                  final bool hasSignature =
                      signature is List && signature.isNotEmpty;

                  if (!hasSignature && data["useDigitalContract"] != false) {
                    waitingContracts
                        .add((data["roomNumber"] ?? "?").toString());
                  }
                }

                waitingContracts.sort();

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("payments")
                      .where("tenantId", isEqualTo: tenantId)
                      .where("tenantSeen", isEqualTo: false)
                      .snapshots(),
                  builder: (context, paymentsSnapshot) {
                    final List<Map<String, dynamic>> paymentNotifications = [];

                    for (final doc in paymentsSnapshot.data?.docs ?? []) {
                      final data = doc.data() as Map<String, dynamic>;
                      final String status = (data["status"] ?? "").toString();

                      if (status != "verified" && status != "rejected") {
                        continue;
                      }

                      final String resultType =
                          (data["resultType"] ?? "").toString();
                      final String room = (data["room"] ?? "?").toString();

                      String pTitle;
                      Color pColor;
                      IconData pIcon;

                      if (resultType == "approved_full") {
                        pTitle = "Room $room - Your payment was accepted";
                        pColor = const Color(0xFF22C55E);
                        pIcon = Icons.check_circle;
                      } else if (resultType == "approved_partial") {
                        pTitle =
                            "Room $room - Your partial payment was accepted";
                        pColor = const Color(0xFF22C55E);
                        pIcon = Icons.check_circle;
                      } else {
                        pTitle = "Room $room - Your payment was rejected";
                        pColor = const Color(0xFFE93636);
                        pIcon = Icons.cancel;
                      }

                      paymentNotifications.add({
                        "id": doc.id,
                        "title": pTitle,
                        "color": pColor,
                        "icon": pIcon,
                      });
                    }

                    final int count = messageChats.length +
                        overdueRooms.length +
                        billNotifications.length +
                        waitingContracts.length +
                        paymentNotifications.length;

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
                                        messageChats: messageChats,
                                        overdueRooms: overdueRooms,
                                        billNotifications: billNotifications,
                                        waitingContracts: waitingContracts,
                                        paymentNotifications:
                                            paymentNotifications,
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

  String _messagePreview(Map<String, dynamic> chat) {
    final int unread = chat["unread"] as int;
    final String last = (chat["lastMessage"] ?? "").toString();

    if (unread > 1) return "$unread new messages";
    if (last.isEmpty) return "Tap to open the chat";

    return last.length > 60 ? "${last.substring(0, 60)}..." : last;
  }

  // Isasara ang panel at lilipat sa tab na tinutukoy ng notification.
  void _goToTab(BuildContext dialogContext, int index) {
    Navigator.pop(dialogContext);
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  // Notification panel na lumalabas sa ilalim ng bell (kapareho ng owner).
  // - Bagong message mula sa owner -> Messages tab
  // - Overdue na bayad -> Payments tab
  // - Contract na hinihintay pirmahan -> Contracts tab
  void _showNotificationPanel({
    required List<Map<String, dynamic>> messageChats,
    required List<String> overdueRooms,
    required List<Map<String, dynamic>> billNotifications,
    required List<String> waitingContracts,
    required List<Map<String, dynamic>> paymentNotifications,
  }) {
    final int total = messageChats.length +
        overdueRooms.length +
        billNotifications.length +
        waitingContracts.length +
        paymentNotifications.length;

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
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                            children: [
                              for (final payment in paymentNotifications)
                                _buildNotificationTile(
                                  icon: payment["icon"] as IconData,
                                  color: payment["color"] as Color,
                                  title: payment["title"] as String,
                                  subtitle: "Tap to view your payments",
                                  onTap: () {
                                    _markPaymentSeen(
                                      payment["id"] as String,
                                    );
                                    _goToTab(dialogContext, 1);
                                  },
                                ),
                              for (final chat in messageChats)
                                _buildNotificationTile(
                                  icon: Icons.chat_bubble,
                                  color: const Color(0xFF8B5CF6),
                                  title: "New message from your owner",
                                  subtitle: _messagePreview(chat),
                                  onTap: () => _goToTab(dialogContext, 2),
                                ),
                              for (final room in overdueRooms)
                                _buildNotificationTile(
                                  icon: Icons.error,
                                  color: const Color(0xFFE93636),
                                  title: "Room $room - Payment overdue",
                                  subtitle: "Please pay as soon as possible",
                                  onTap: () => _goToTab(dialogContext, 1),
                                ),
                              for (final bill in billNotifications)
                                _buildNotificationTile(
                                  icon: Icons.receipt_long,
                                  color: const Color(0xFF3B82F6),
                                  title:
                                      "Room ${bill["room"]} - New bill posted",
                                  subtitle: "Tap to view your payments",
                                  onTap: () {
                                    _markBillSeen(bill["id"] as String);
                                    _goToTab(dialogContext, 1);
                                  },
                                ),
                              for (final room in waitingContracts)
                                _buildNotificationTile(
                                  icon: Icons.hourglass_top,
                                  color: const Color(0xFF3E8BEA),
                                  title:
                                      "Room $room - Contract needs your signature",
                                  subtitle: "Tap to review and sign",
                                  onTap: () => _goToTab(dialogContext, 3),
                                ),
                            ],
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

  // Minamarkahan ang payment bilang nakita na ng tenant, para hindi na
  // ito ulit lumabas sa bell notifications.
  Future<void> _markPaymentSeen(String paymentId) async {
    try {
      await FirebaseFirestore.instance
          .collection("payments")
          .doc(paymentId)
          .update({"tenantSeen": true});
    } catch (error) {
      debugPrint("MARK PAYMENT SEEN ERROR: $error");
    }
  }

  Future<void> _markBillSeen(String roomId) async {
    try {
      await FirebaseFirestore.instance
          .collection("rooms")
          .doc(roomId)
          .update({"billUpdated": false});
    } catch (error) {
      debugPrint("MARK BILL SEEN ERROR: $error");
    }
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

  Widget _buildBody(String uid) {
    switch (_currentIndex) {
      case 0:
        return const TenantHomeScreen();
      case 1:
        return _buildPaymentsTab(uid);
      case 2:
        return const MessagesScreen();
      case 3:
        return const TenantContractsScreen();
      case 4:
        return const TenantProfileScreen();
      default:
        return const TenantHomeScreen();
    }
  }

  Widget _buildPaymentsTab(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.getCurrentUserData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;

        final String? activePaymentId = userData?["activePaymentId"];

        if (activePaymentId != null && activePaymentId.isNotEmpty) {
          return PendingPaymentScreen(
            paymentId: activePaymentId,
            tenantId: uid,
            onContinue: () async {
              await firestore.clearActivePayment(uid);

              if (!mounted) return;
              setState(() {
                _currentIndex = 0; // balik sa Home tab
              });
            },
            onSubmitNew: () async {
              await firestore.clearActivePayment(uid);
              // mananatili sa Payments tab — awtomatikong
              // magpapakita ng normal PaymentScreen (upload form)
              // sa sandaling ma-clear ang activePaymentId.
            },
          );
        }

        return const PaymentScreen();
      },
    );
  }
}
