import 'package:deep_gaze/pages/ruang_kelas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/eye_calibration_page.dart';

void main() {
  runApp(const SeesoEyeTrackingApp());
}

class SeesoEyeTrackingApp extends StatelessWidget {
  const SeesoEyeTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'SeeSo Eye Tracking Application',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          dialogTheme: DialogTheme(
            backgroundColor: Colors.grey.shade800,
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            contentTextStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          // Custom button themes
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade400,
            ),
          ),
        ),
        home: const EyeCalibrationPage(),
        routes: {
          '/calibration': (context) => const EyeCalibrationPage(),
          '/ruang-kelas': (context) => const RuangKelas(),
        });
  }
}
