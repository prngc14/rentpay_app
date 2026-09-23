import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String text = "";

  final String fullText = "Rentpay";

  static const Color _brandText = Colors.black;

  // ============================================================
  // INIT STATE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _animateText();

    // Total = (letters × interval) + small hold after completion
    // 7 letters × 320ms = 2240ms, + 300ms hold = 2540ms
    Future.delayed(
      const Duration(milliseconds: 2540),
      () {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      },
    );
  }

  // ============================================================
  // TEXT ANIMATION (letter-by-letter reveal)
  // ============================================================

  void _animateText() {
    int index = 0;

    Timer.periodic(
      const Duration(milliseconds: 320),
      (timer) {
        if (index < fullText.length) {
          setState(() {
            text += fullText[index];
          });

          index++;
        } else {
          timer.cancel();
        }
      },
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          text,
          style: GoogleFonts.lobster(
            fontSize: 56,
            color: _brandText,
          ),
        ),
      ),
    );
  }
}
