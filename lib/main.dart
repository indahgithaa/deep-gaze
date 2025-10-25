import 'package:flutter/material.dart';
import 'pages/eye_calibration_page.dart';
import 'pages/ruang_kelas.dart';
import 'pages/lecture_recorder_page.dart';
import 'pages/profile_page.dart';
import 'widgets/main_app_scaffold.dart';
import 'widgets/gaze_overlay_manager.dart'; // <-- manager overlay global

final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavKey, // <- penting! agar bisa ambil root overlay
      title: 'DeepGaze',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      builder: (context, child) {
        // Pasang overlay global PALING ATAS.
        // (JANGAN taruh indikator di sini; manager yang akan insert ke root overlay)
        // Hanya kembalikan child apa adanya.
        return child ?? const SizedBox.shrink();
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const EyeCalibrationPage(),
        '/home': (context) => const MainAppScaffold(startIndex: 0),
        '/recorder': (context) => const MainAppScaffold(startIndex: 1),
        '/profile': (context) => const MainAppScaffold(startIndex: 2),

        // direct pages (tanpa navbar)
        '/ruang_kelas_direct': (context) => const RuangKelas(),
        '/recorder_direct': (context) => const LectureRecorderPage(),
        '/profile_direct': (context) => const ProfilePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
