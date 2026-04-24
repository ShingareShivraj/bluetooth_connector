import 'package:flutter/material.dart';
import 'dart:async';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  Timer? _timer; // ✅ store timer

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return; // ✅ prevent crash

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // ✅ cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF07B5AF),
              Color(0xFF0AADA8),
              Color(0xFF13C4BC),
              Color(0xFF7DD8D6),
            ],
          ),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            const SizedBox(height: 60),

            // 🔝 CENTER CONTENT
            Expanded( // ✅ IMPORTANT: proper centering
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // ✅ avoid stretching
                  children: [
                    Image.network(
                      "https://cdn-icons-png.flaticon.com/512/3135/3135715.png",
                      height: 160,
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity, // 🔥 IMPORTANT
                      child: const Text(
                        "Smart Bluetooth Connector",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Invent. Improve. Inspire...",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🔻 FOOTER
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                children: const [
                  Text(
                    "Powered by",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Sanpra Software Solutions",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}