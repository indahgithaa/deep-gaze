import 'package:flutter/material.dart';
import 'pages/eye_calibration_page.dart';
import 'pages/ruang_kelas.dart';
import 'pages/lecture_recorder_page.dart';
import 'pages/profile_page.dart';
import 'widgets/main_app_scaffold.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepGaze',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const EyeCalibrationPage(),
        '/home': (context) =>
            const MainAppScaffold(initialIndex: 0), // Home with navbar
        '/recorder': (context) =>
            const MainAppScaffold(initialIndex: 1), // Recorder with navbar
        '/profile': (context) =>
            const MainAppScaffold(initialIndex: 2), // Profile with navbar
        // Direct routes (without navbar) for navigation from other pages
        '/ruang_kelas_direct': (context) => const RuangKelas(),
        '/recorder_direct': (context) => const LectureRecorderPage(),
        '/profile_direct': (context) => const ProfilePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
