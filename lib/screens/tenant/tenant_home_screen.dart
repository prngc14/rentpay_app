import 'package:flutter/material.dart';

class TenantHomeScreen extends StatelessWidget {
  const TenantHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tenant Dashboard"),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Welcome Tenant 👋",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
