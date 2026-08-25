import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import 'tenant_home_screen.dart';
import 'payment_screen.dart';
import 'tenant_profile_screen.dart';
import 'tenant_connect_screen.dart';
import 'tenant_contracts_screen.dart';
import 'pending_payment_screen.dart';

class TenantDashboard extends StatefulWidget {
  const TenantDashboard({super.key});

  @override
  State<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  int _currentIndex = 0;

  final FirestoreService firestore = FirestoreService();

  void logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
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

    return Scaffold(
      appBar: _currentIndex == 1
          ? null
          : AppBar(
              title: Text(
                _currentIndex == 0
                    ? "Home"
                    : _currentIndex == 1
                        ? "Payments"
                        : _currentIndex == 2
                            ? "Contracts"
                            : "Profile",
              ),
              backgroundColor: Colors.deepOrange,
              actions: [
                // CONNECT TO OWNER BUTTON
                IconButton(
                  icon: const Icon(Icons.link),
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

                // LOGOUT BUTTON
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: "Logout",
                  onPressed: logout,
                ),
              ],
            ),
      body: _buildBody(user.uid),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: "Payments",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: "Contracts",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }

  // ===============================
  // MAIN BODY (per tab)
  // Home / Contracts / Profile = normal, walang lock.
  // Payments tab lang ang naka-gate: kung may
  // activePaymentId, PendingPaymentScreen ang lalabas
  // imbes na ang normal na PaymentScreen (upload form).
  // ===============================
  Widget _buildBody(String uid) {
    switch (_currentIndex) {
      case 0:
        return const TenantHomeScreen();
      case 1:
        return _buildPaymentsTab(uid);
      case 2:
        return const TenantContractsScreen();
      case 3:
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