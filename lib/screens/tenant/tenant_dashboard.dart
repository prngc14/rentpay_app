import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'tenant_home_screen.dart';
import 'payment_screen.dart';
import 'tenant_profile_screen.dart';

class TenantDashboard extends StatefulWidget {
  const TenantDashboard({super.key});

  @override
  State<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TenantHomeScreen(),
    const PaymentScreen(),
    const TenantProfileScreen(),
  ];

  void logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ✅ FIX: Wait for user before loading UI
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _currentIndex == 1
          ? null
          : AppBar(
              title: Text(
                _currentIndex == 0
                    ? "Home"
                    : _currentIndex == 2
                        ? "Profile"
                        : "Tenant",
              ),
              backgroundColor: Colors.deepOrange,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: logout,
                ),
              ],
            ),
      body: _screens[_currentIndex],
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
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
