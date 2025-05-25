// File: lib/services/seeso_singleton_service.dart

import 'package:deep_gaze/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:seeso_flutter/event/gaze_info.dart';
import 'package:seeso_flutter/event/status_info.dart';
import 'package:seeso_flutter/event/calibration_info.dart';
import 'package:seeso_flutter/seeso.dart';
import 'package:seeso_flutter/seeso_initialized_result.dart';
import 'package:seeso_flutter/seeso_plugin_constants.dart';

/// Singleton SeeSo Service to prevent re-initialization issues
/// This service should be initialized once and shared across all pages
class SeesoSingletonService extends ChangeNotifier {
  // Singleton instance
  static SeesoSingletonService? _instance;
  static SeesoSingletonService get instance {
    _instance ??= SeesoSingletonService._internal();
    return _instance!;
  }

  // Private constructor
  SeesoSingletonService._internal() {
    _initializeListeners();
  }

  // SeeSo instance
  final SeeSo _seesoPlugin = SeeSo();
  static const String _licenseKey = AppConstants.seesoLicenseKey;

  // Current gaze position
  double _gazeX = 0.0;
  double _gazeY = 0.0;

  // Tracking state
  bool _isTracking = false;
  bool _isInitialized = false;
  bool _hasCameraPermission = false;
  String _statusMessage = "Idle";

  // Gaze tracking quality
  TrackingState _trackingState = TrackingState.FACE_MISSING;

  // Listeners for gaze updates
  final List<VoidCallback> _listeners = [];

  // Calibration state
  bool _isCalibrating = false;
  bool _calibrationComplete = false;

  // Getters to match your existing EyeTrackingService interface
  double get gazeX => _gazeX;
  double get gazeY => _gazeY;
  bool get isTracking => _isTracking && _trackingState == TrackingState.SUCCESS;
  String get statusMessage => _statusMessage;
  bool get isInitialized => _isInitialized;
  bool get hasCameraPermission => _hasCameraPermission;
  TrackingState get trackingQuality => _trackingState;
  bool get isCalibrating => _isCalibrating;
  bool get calibrationComplete => _calibrationComplete;

  void _initializeListeners() {
    // Listen to gaze events
    _seesoPlugin.getGazeEvent().listen((event) {
      GazeInfo info = GazeInfo(event);
      _gazeX = info.x;
      _gazeY = info.y;
      _trackingState = info.trackingState;

      // Update status based on tracking quality
      if (info.trackingState == TrackingState.SUCCESS) {
        _statusMessage = "Tracking: Good";
      } else {
        _statusMessage = "Tracking: ${info.trackingState.toString()}";
      }

      // Notify all listeners
      _notifyAllListeners();
    });

    // Listen to status events
    _seesoPlugin.getStatusEvent().listen((event) {
      StatusInfo statusInfo = StatusInfo(event);

      if (statusInfo.type == StatusType.START) {
        _isTracking = true;
        _statusMessage = "Tracking Started";
      } else {
        _isTracking = false;
        _statusMessage = "Tracking Stopped: ${statusInfo.stateErrorType}";
      }

      // Notify all listeners
      _notifyAllListeners();
    });

    // Listen to calibration events
    _seesoPlugin.getCalibrationEvent().listen((event) {
      CalibrationInfo caliInfo = CalibrationInfo(event);

      if (caliInfo.type == CalibrationType.CALIBRATION_NEXT_XY) {
        _isCalibrating = true;
        _calibrationComplete = false;
      } else if (caliInfo.type == CalibrationType.CALIBRATION_FINISHED) {
        _isCalibrating = false;
        _calibrationComplete = true;
        _statusMessage = "Calibration Complete";

        // Notify all listeners
        _notifyAllListeners();
      }
    });
  }

  void _notifyAllListeners() {
    // Notify custom listeners
    for (var listener in _listeners) {
      try {
        listener();
      } catch (e) {
        print('Error calling listener: $e');
      }
    }

    // Notify ChangeNotifier listeners
    notifyListeners();
  }

  // Initialize SeeSo (should only be called once from calibration page)
  Future<bool> initializeSeeSo() async {
    if (_isInitialized) {
      print('SeeSo already initialized');
      return true;
    }

    try {
      // Check camera permission first
      _hasCameraPermission = await _seesoPlugin.checkCameraPermission();
      if (!_hasCameraPermission) {
        _hasCameraPermission = await _seesoPlugin.requestCameraPermission();
      }

      if (!_hasCameraPermission) {
        _statusMessage = "Camera permission denied";
        return false;
      }

      // Initialize SeeSo
      _statusMessage = "Initializing SeeSo...";
      _notifyAllListeners();

      InitializedResult? result =
          await _seesoPlugin.initGazeTracker(licenseKey: _licenseKey);

      _isInitialized = result?.result ?? false;
      _statusMessage = result?.message ?? "Unknown initialization result";

      if (_isInitialized) {
        // Start tracking automatically
        await startTracking();
      }

      _notifyAllListeners();
      return _isInitialized;
    } catch (e) {
      _statusMessage = "SeeSo initialization failed: ${e.toString()}";
      _isInitialized = false;
      _notifyAllListeners();
      return false;
    }
  }

  // Start calibration (5-point by default)
  Future<void> startCalibration(
      {CalibrationMode mode = CalibrationMode.FIVE}) async {
    if (!_isInitialized) {
      throw Exception('SeeSo not initialized');
    }

    try {
      await _seesoPlugin.startCalibration(mode);
      _isCalibrating = true;
      _calibrationComplete = false;
      _statusMessage = "Calibration started";
      _notifyAllListeners();
    } catch (e) {
      _statusMessage = "Calibration start failed: ${e.toString()}";
      _notifyAllListeners();
      rethrow;
    }
  }

  // Start collecting samples (called during calibration)
  Future<void> startCollectSamples() async {
    try {
      await _seesoPlugin.startCollectSamples();
    } catch (e) {
      print('Error starting collect samples: $e');
    }
  }

  // Start tracking
  Future<void> startTracking() async {
    if (!_isInitialized) {
      print('Cannot start tracking: SeeSo not initialized');
      return;
    }

    try {
      await _seesoPlugin.startTracking();
      _statusMessage = "Starting tracking...";
      _notifyAllListeners();
    } catch (e) {
      _statusMessage = "Start tracking failed: ${e.toString()}";
      _notifyAllListeners();
    }
  }

  // Stop tracking
  Future<void> stopTracking() async {
    if (!_isInitialized) return;

    try {
      await _seesoPlugin.stopTracking();
      _isTracking = false;
      _statusMessage = "Tracking stopped";
      _notifyAllListeners();
    } catch (e) {
      _statusMessage = "Stop tracking failed: ${e.toString()}";
      _notifyAllListeners();
    }
  }

  // Add listener (for UI components)
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  // Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  // Check if has listeners
  bool get hasListeners => _listeners.isNotEmpty;

  // Compatibility methods for existing EyeTrackingService interface

  Future<void> initialize(BuildContext context) async {
    // This method is called from RuangKelas
    // SeeSo should already be initialized, so we just ensure tracking is active
    if (_isInitialized) {
      await startTracking();
    } else {
      throw Exception(
          'SeeSo not initialized. Please complete calibration first.');
    }
  }

  Offset getCalibratedGaze() {
    return Offset(_gazeX, _gazeY);
  }

  bool isGazeWithinRect(Rect rect) {
    if (!isTracking) return false;
    return rect.contains(Offset(_gazeX, _gazeY));
  }

  double getGazeAccuracy() {
    switch (_trackingState) {
      case TrackingState.SUCCESS:
        return 0.95;
      case TrackingState.LOW_CONFIDENCE:
        return 0.7;
      case TrackingState.UNSUPPORTED:
      case TrackingState.FACE_MISSING:
      default:
        return 0.0;
    }
  }

  bool get isFaceDetected => _trackingState != TrackingState.FACE_MISSING;
  bool get isTrackingStable => _trackingState == TrackingState.SUCCESS;

  String get trackingStatusString {
    switch (_trackingState) {
      case TrackingState.SUCCESS:
        return "Excellent";
      case TrackingState.LOW_CONFIDENCE:
        return "Fair";
      case TrackingState.UNSUPPORTED:
        return "Unsupported";
      case TrackingState.FACE_MISSING:
        return "Face Missing";
    }
  }

  // Gaze smoothing
  static final List<Offset> _gazeHistory = [];
  static const int _smoothingWindow = 5;

  Offset getSmoothedGaze() {
    _gazeHistory.add(Offset(_gazeX, _gazeY));

    if (_gazeHistory.length > _smoothingWindow) {
      _gazeHistory.removeAt(0);
    }

    if (_gazeHistory.isEmpty) return Offset(_gazeX, _gazeY);

    double avgX = 0;
    double avgY = 0;
    for (final point in _gazeHistory) {
      avgX += point.dx;
      avgY += point.dy;
    }

    return Offset(
      avgX / _gazeHistory.length,
      avgY / _gazeHistory.length,
    );
  }

  // Debug method
  void debugPrintStatus() {
    print('''
=== SeeSo Singleton Service Status ===
Initialized: $_isInitialized
Camera Permission: $_hasCameraPermission
Tracking: $_isTracking
Tracking State: $_trackingState
Tracking Quality: $trackingStatusString
Current Gaze: ($_gazeX, $_gazeY)
Status Message: $_statusMessage
Calibrating: $_isCalibrating
Calibration Complete: $_calibrationComplete
Listeners: ${_listeners.length}
=====================================
    ''');
  }

  // Dispose (should only be called when app closes)
  void disposeSeeSo() {
    try {
      if (_isTracking) {
        _seesoPlugin.stopTracking();
      }
      if (_isInitialized) {
        _seesoPlugin.deinitGazeTracker();
      }

      _listeners.clear();
      _isInitialized = false;
      _isTracking = false;
      _statusMessage = "SeeSo disposed";

      print('SeeSo disposed successfully');
    } catch (e) {
      print('Error disposing SeeSo: $e');
    }
  }

  @override
  void dispose() {
    // Don't dispose SeeSo automatically - it should persist across pages
    // Only dispose when explicitly called or app closes
    super.dispose();
  }
}
