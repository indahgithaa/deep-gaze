import 'dart:async';
import 'package:deep_gaze/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:seeso_flutter/event/status_info.dart';

// Import your SeeSo SDK packages when available
import 'package:seeso_flutter/seeso.dart';
import 'package:seeso_flutter/event/gaze_info.dart';
import 'package:seeso_flutter/seeso_initialized_result.dart';

class EyeTrackingService extends ChangeNotifier {
  // SeeSo SDK instance (uncomment when using actual SDK)
  final _seesoPlugin = SeeSo();

  // License key
  static const String _licenseKey = AppConstants.seesoLicenseKey;

  // Gaze tracking state
  double _gazeX = 0.0;
  double _gazeY = 0.0;
  bool _isTracking = false;
  bool _isInitialized = false;
  String _statusMessage = "Initializing...";

  // Getters
  double get gazeX => _gazeX;
  double get gazeY => _gazeY;
  bool get isTracking => _isTracking;
  bool get isInitialized => _isInitialized;
  String get statusMessage => _statusMessage;

  // Initialize eye tracking
  Future<void> initialize(BuildContext context) async {
    try {
      // Initialize SeeSo SDK (uncomment when using actual SDK)

      bool hasCameraPermission = await _seesoPlugin.checkCameraPermission();
      if (!hasCameraPermission) {
        hasCameraPermission = await _seesoPlugin.requestCameraPermission();
      }

      if (hasCameraPermission) {
        InitializedResult? result =
            await _seesoPlugin.initGazeTracker(licenseKey: _licenseKey);

        if (result != null && result.result) {
          _isInitialized = true;
          _statusMessage = "Eye tracking initialized";
          notifyListeners();

          startTracking();
          _listenToGazeEvents();
        } else {
          _statusMessage = "Failed to initialize: ${result?.message}";
          notifyListeners();
        }
      } else {
        _statusMessage = "Camera permission denied";
        notifyListeners();
      }
    } catch (e) {
      _statusMessage = "Error: $e";
      notifyListeners();
    }
  }

  void startTracking() {
    _seesoPlugin.startTracking(); // Uncomment when using actual SDK
    _isTracking = true;
    notifyListeners();
  }

  void stopTracking() {
    _seesoPlugin.stopTracking(); // Uncomment when using actual SDK
    _isTracking = false;
    notifyListeners();
  }

  void _listenToGazeEvents() {
    // Uncomment when using actual SeeSo SDK
    _seesoPlugin.getGazeEvent().listen((event) {
      GazeInfo info = GazeInfo(event);
      if (info.trackingState == TrackingState.SUCCESS) {
        _gazeX = info.x;
        _gazeY = info.y;
        notifyListeners();
      }
    });

    _seesoPlugin.getStatusEvent().listen((event) {
      StatusInfo statusInfo = StatusInfo(event);
      if (statusInfo.type == StatusType.START) {
        _statusMessage = "Tracking started";
        _isTracking = true;
      } else {
        _statusMessage = "Tracking stopped: ${statusInfo.stateErrorType}";
        _isTracking = false;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _seesoPlugin.stopTracking(); // Uncomment when using actual SDK
    super.dispose();
  }
}
