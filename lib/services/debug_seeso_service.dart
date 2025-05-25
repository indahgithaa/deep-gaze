// File: lib/services/debug_seeso_service.dart

import 'package:deep_gaze/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:seeso_flutter/event/gaze_info.dart';
import 'package:seeso_flutter/event/status_info.dart';
import 'package:seeso_flutter/event/calibration_info.dart';
import 'package:seeso_flutter/seeso.dart';
import 'package:seeso_flutter/seeso_initialized_result.dart';
import 'package:seeso_flutter/seeso_plugin_constants.dart';

/// Simple Debug Service to identify the exact error
class DebugSeesoService extends ChangeNotifier {
  // SeeSo instance
  static SeeSo? _seesoPlugin;
  static const String _licenseKey = AppConstants.seesoLicenseKey;

  // State tracking
  static bool _isInitialized = false;
  static bool _isTracking = false;
  static bool _hasPermission = false;
  static String _lastError = "";
  static int _initAttempts = 0;

  // Current gaze position
  double _gazeX = 0.0;
  double _gazeY = 0.0;
  TrackingState _trackingState = TrackingState.FACE_MISSING;
  String _statusMessage = "Idle";

  // Listeners
  final List<VoidCallback> _listeners = [];

  // Getters
  double get gazeX => _gazeX;
  double get gazeY => _gazeY;
  bool get isTracking => _isTracking;
  bool get isInitialized => _isInitialized;
  String get statusMessage => _statusMessage;
  bool get hasPermission => _hasPermission;
  String get lastError => _lastError;
  TrackingState get trackingQuality => _trackingState;
  bool get isTrackingStable => _trackingState == TrackingState.SUCCESS;

  // Initialize (call this ONCE from calibration page)
  static Future<bool> initializeOnce() async {
    _initAttempts++;
    print("=== DEBUG: Initialize attempt #$_initAttempts ===");

    try {
      // Check if already initialized
      if (_isInitialized && _seesoPlugin != null) {
        print("DEBUG: Already initialized, skipping...");
        return true;
      }

      // Create SeeSo instance if not exists
      if (_seesoPlugin == null) {
        print("DEBUG: Creating new SeeSo instance...");
        _seesoPlugin = SeeSo();
      }

      // Check camera permission
      print("DEBUG: Checking camera permission...");
      _hasPermission = await _seesoPlugin!.checkCameraPermission();
      if (!_hasPermission) {
        print("DEBUG: Requesting camera permission...");
        _hasPermission = await _seesoPlugin!.requestCameraPermission();
      }

      if (!_hasPermission) {
        _lastError = "Camera permission denied";
        print("DEBUG: Error - $_lastError");
        return false;
      }

      print("DEBUG: Camera permission granted");

      // Initialize SeeSo
      print("DEBUG: Initializing SeeSo with license key...");
      InitializedResult? result =
          await _seesoPlugin!.initGazeTracker(licenseKey: _licenseKey);

      _isInitialized = result?.result ?? false;
      _lastError = result?.message ?? "Unknown result";

      print("DEBUG: Initialization result: $_isInitialized");
      print("DEBUG: Initialization message: $_lastError");

      if (_isInitialized) {
        // Start tracking
        print("DEBUG: Starting tracking...");
        await _seesoPlugin!.startTracking();
        _isTracking = true;
        print("DEBUG: Tracking started successfully");
      }

      return _isInitialized;
    } catch (e) {
      _lastError = "Init exception: ${e.toString()}";
      print("DEBUG: Exception during initialization: $_lastError");
      _isInitialized = false;
      return false;
    }
  }

  // Get existing instance (call this from other pages)
  static DebugSeesoService? getInstance() {
    if (!_isInitialized || _seesoPlugin == null) {
      print("DEBUG: getInstance() called but SeeSo not initialized!");
      return null;
    }

    print("DEBUG: Returning existing SeeSo instance");
    return DebugSeesoService._internal();
  }

  // Private constructor
  DebugSeesoService._internal() {
    print("DEBUG: Setting up event listeners...");
    _setupListeners();
  }

  void _setupListeners() {
    if (_seesoPlugin == null) {
      print("DEBUG: Cannot setup listeners - SeeSo plugin is null");
      return;
    }

    try {
      // Gaze events
      _seesoPlugin!.getGazeEvent().listen((event) {
        GazeInfo info = GazeInfo(event);
        _gazeX = info.x;
        _gazeY = info.y;
        _trackingState = info.trackingState;

        if (info.trackingState == TrackingState.SUCCESS) {
          _statusMessage = "Tracking: Good";
        } else {
          _statusMessage = "Tracking: ${info.trackingState.toString()}";
        }

        _notifyListeners();
      });

      // Status events
      _seesoPlugin!.getStatusEvent().listen((event) {
        StatusInfo statusInfo = StatusInfo(event);

        if (statusInfo.type == StatusType.START) {
          _isTracking = true;
          _statusMessage = "Tracking Started";
          print("DEBUG: Tracking started via status event");
        } else {
          _isTracking = false;
          _statusMessage = "Tracking Stopped: ${statusInfo.stateErrorType}";
          print("DEBUG: Tracking stopped: ${statusInfo.stateErrorType}");
        }

        _notifyListeners();
      });

      print("DEBUG: Event listeners setup complete");
    } catch (e) {
      print("DEBUG: Error setting up listeners: ${e.toString()}");
    }
  }

  void _notifyListeners() {
    for (var listener in _listeners) {
      try {
        listener();
      } catch (e) {
        print("DEBUG: Error calling listener: $e");
      }
    }
    notifyListeners();
  }

  // Add listener
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    print("DEBUG: Listener added. Total listeners: ${_listeners.length}");
  }

  // Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    print("DEBUG: Listener removed. Total listeners: ${_listeners.length}");
  }

  bool get hasListeners => _listeners.isNotEmpty;

  // Helper methods for compatibility
  Future<void> initialize(BuildContext context) async {
    print("DEBUG: initialize() called from UI component");
    if (!_isInitialized) {
      throw Exception("SeeSo not initialized. Call initializeOnce() first.");
    }

    // Ensure tracking is active
    try {
      if (!_isTracking && _seesoPlugin != null) {
        print("DEBUG: Restarting tracking...");
        await _seesoPlugin!.startTracking();
      }
    } catch (e) {
      print("DEBUG: Error restarting tracking: ${e.toString()}");
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
      default:
        return 0.0;
    }
  }

  String get trackingStatusString {
    switch (_trackingState) {
      case TrackingState.SUCCESS:
        return "Excellent";
      case TrackingState.LOW_CONFIDENCE:
        return "Fair";
      case TrackingState.FACE_MISSING:
        return "Face Missing";
      default:
        return "Poor";
    }
  }

  // Start calibration
  Future<void> startCalibration() async {
    if (_seesoPlugin == null || !_isInitialized) {
      throw Exception("SeeSo not ready for calibration");
    }

    try {
      print("DEBUG: Starting calibration...");
      await _seesoPlugin!.startCalibration(CalibrationMode.FIVE);
      print("DEBUG: Calibration started successfully");
    } catch (e) {
      print("DEBUG: Calibration start error: ${e.toString()}");
      rethrow;
    }
  }

  // Debug info
  static void printDebugInfo() {
    print("""
=== SEESO DEBUG INFO ===
SeeSo Plugin: ${_seesoPlugin != null ? 'Created' : 'NULL'}
Initialized: $_isInitialized
Tracking: $_isTracking
Has Permission: $_hasPermission
Last Error: $_lastError
Init Attempts: $_initAttempts
========================
    """);
  }

  // Cleanup (call when app closes)
  static void cleanup() {
    try {
      print("DEBUG: Cleaning up SeeSo...");
      if (_isTracking && _seesoPlugin != null) {
        _seesoPlugin!.stopTracking();
      }
      if (_isInitialized && _seesoPlugin != null) {
        _seesoPlugin!.deinitGazeTracker();
      }

      _isInitialized = false;
      _isTracking = false;
      _seesoPlugin = null;
      print("DEBUG: Cleanup complete");
    } catch (e) {
      print("DEBUG: Cleanup error: ${e.toString()}");
    }
  }
}
