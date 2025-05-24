import 'package:flutter/services.dart';
import 'package:seeso_flutter/event/gaze_info.dart';
import 'package:seeso_flutter/seeso.dart';
import 'package:seeso_flutter/seeso_initialized_result.dart';

class SeeSoService {
  static final SeeSoService _instance = SeeSoService._internal();

  factory SeeSoService() => _instance;

  final SeeSo _seeso = SeeSo();
  static const String _licenseKey =
      "dev_d4rilp973uxfvzofi0ky4mwkqp4qf9w19vodfe70";

  double gazeX = 0;
  double gazeY = 0;
  bool isInitialized = false;

  SeeSoService._internal();

  Future<bool> initialize() async {
    final permission = await _seeso.checkCameraPermission();
    if (!permission) {
      await _seeso.requestCameraPermission();
    }

    try {
      InitializedResult? result =
          await _seeso.initGazeTracker(licenseKey: _licenseKey);
      isInitialized = result?.result ?? false;

      if (isInitialized) {
        _seeso.getGazeEvent().listen((event) {
          final info = GazeInfo(event);
          if (info.trackingState == TrackingState.SUCCESS) {
            gazeX = info.x;
            gazeY = info.y;
          }
        });
        await _seeso.startTracking();
      }
    } on PlatformException catch (e) {
      print("SeeSo Init Error: ${e.message}");
      isInitialized = false;
    }

    return isInitialized;
  }

  double getX() => gazeX;
  double getY() => gazeY;
}
