import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const CampusStreetViewApp());
}

class CampusStreetViewApp extends StatelessWidget {
  const CampusStreetViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus View',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff54dcaa),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
