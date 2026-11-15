import 'package:flutter/material.dart';
import 'screens/splash_screen.dart'; // ← ganti dari home_page ke splash_screen

class MyStoreApp extends StatelessWidget {
  const MyStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HeadNote',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5BB8E8)),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // ← ganti dari HomeScreen ke SplashScreen
    );
  }
}