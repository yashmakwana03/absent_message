import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'screens/splash_screen.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, 
  ));

  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance Tracker',
      
      // --- THEME CONFIGURATION ---
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        
        // Global AppBar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
        ),
        
        // REMOVED: cardTheme block to fix the "CardThemeData" error.
        // The default Material 3 card style is already very good.
      ),
      
      // Start with the Splash Screen
      home: const SplashScreen(), 
    );
  }
}