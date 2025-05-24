import 'package:deep_gaze/pages/home_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const EyeTrackingApp());
}

class EyeTrackingApp extends StatelessWidget {
  const EyeTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eye Tracking Multi-Page App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
