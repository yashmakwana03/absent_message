import 'package:flutter/material.dart';
import 'dart:async'; 
import '../database/database_helper.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Slightly faster for snappier feel
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final minDelay = Future.delayed(const Duration(seconds: 3));

    try {
      await DatabaseHelper.instance.database;
      debugPrint("Database initialized successfully");
    } catch (e) {
      debugPrint("Database init error: $e");
    }

    await minDelay;

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // --- 1. PROFESSIONAL GRADIENT BACKGROUND ---
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade400, // Lighter purple at top
              Colors.deepPurple.shade900, // Darker purple at bottom
            ],
          ),
        ),
        child: Stack(
          children: [
            // --- 2. CENTER CONTENT ---
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- LOGO ANIMATION ---
                  ScaleTransition(
                    scale: _scale,
                    child: FadeTransition(
                      opacity: _opacity,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.white, // Clean white circle makes logo POP
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Image.asset(
                              'assets/AbsentMsgLogo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 50),

                  // --- TEXT ANIMATION ---
                  FadeTransition(
                    opacity: _opacity,
                    child: Column(
                      children: [
                        const Text(
                          "Attendance Manager",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, 
                            letterSpacing: 1.0,
                            fontFamily: 'Roboto', // Default flutter font, but specifying helps
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Smart • Fast • Reliable",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),

                  // --- LOADER ---
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // --- 3. FOOTER (Optional Branding) ---
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _opacity,
                child: Center(
                  child: Text(
                    "v1.0.0",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}