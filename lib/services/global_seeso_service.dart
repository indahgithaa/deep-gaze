// File: lib/services/global_seeso_service.dart
import 'package:deep_gaze/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:seeso_flutter/event/gaze_info.dart';
import 'package:seeso_flutter/event/status_info.dart';
import 'package:seeso_flutter/event/calibration_info.dart';
import 'package:seeso_flutter/seeso.dart';
import 'package:seeso_flutter/seeso_initialized_result.dart';
import 'package:seeso_flutter/seeso_plugin_constants.dart';

/// Global Singleton SeeSo Service with Page Focus Management
/// Ensures only the current active page responds to eye tracking
class GlobalSeesoService extends ChangeNotifier {
  // Singleton instance
  static GlobalSeesoService? _instance;

  // Factory constructor untuk singleton
  factory GlobalSeesoService() {
    _instance ??= GlobalSeesoService._internal();
    return _instance!;
  }

  // Private constructor
  GlobalSeesoService._internal() {
    print("DEBUG: GlobalSeesoService singleton created");
  }

  // SeeSo instance
  SeeSo? _seesoPlugin;
  static const String _licenseKey = AppConstants.seesoLicenseKey;

  // Current gaze position - KUNCI untuk gaze point
  double _gazeX = 0.0;
  double _gazeY = 0.0;

  // Tracking state
  bool _isTracking = false;
  bool _isInitialized = false;
  bool _hasCameraPermission = false;
  String _statusMessage = "Idle";

  // Gaze tracking quality
  TrackingState _trackingState = TrackingState.FACE_MISSING;

  // PAGE FOCUS MANAGEMENT - CRITICAL FIX
  String? _activePageId;
  final Map<String, VoidCallback> _pageListeners = {};
  final Map<String, bool> _pageActiveStatus = {};

  // Calibration state
  bool _isCalibrating = false;
  bool _calibrationComplete = false;

  // === GETTERS ===
  double get gazeX => _gazeX;
  double get gazeY => _gazeY;
  bool get isTracking => _isTracking && _trackingState == TrackingState.SUCCESS;
  String get statusMessage => _statusMessage;
  bool get isInitialized => _isInitialized;
  bool get hasCameraPermission => _hasCameraPermission;
  TrackingState get trackingQuality => _trackingState;
  bool get isCalibrating => _isCalibrating;
  bool get calibrationComplete => _calibrationComplete;
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

  // === PAGE FOCUS MANAGEMENT METHODS ===

  /// Register a page as the active listener
  void setActivePage(String pageId, VoidCallback listener) {
    print("DEBUG: Setting active page: $pageId (previous: $_activePageId)");

    // Deactivate previous page
    if (_activePageId != null && _activePageId != pageId) {
      _pageActiveStatus[_activePageId!] = false;
      print("DEBUG: Deactivated previous page: $_activePageId");
    }

    // Set new active page
    _activePageId = pageId;
    _pageListeners[pageId] = listener;
    _pageActiveStatus[pageId] = true;

    print("DEBUG: Active page set to: $pageId");
    debugPageStatus();
  }

  /// Remove a page from active listening
  void removePage(String pageId) {
    print("DEBUG: Removing page: $pageId");

    _pageListeners.remove(pageId);
    _pageActiveStatus.remove(pageId);

    // If this was the active page, clear it
    if (_activePageId == pageId) {
      _activePageId = null;
      print("DEBUG: Cleared active page (was $pageId)");
    }

    debugPageStatus();
  }

  /// Check if a specific page is currently active
  bool isPageActive(String pageId) {
    return _activePageId == pageId && (_pageActiveStatus[pageId] ?? false);
  }

  /// Get the current active page ID
  String? get activePageId => _activePageId;

  /// Debug method to show page status
  void debugPageStatus() {
    print("""
=== Page Focus Status ===
Active Page: $_activePageId
Registered Pages: ${_pageListeners.keys.toList()}
Page Status: $_pageActiveStatus
========================
    """);
  }

  // === INITIALIZATION ===
  Future<bool> initializeSeeSo() async {
    print(
        "DEBUG: initializeSeeSo() called. Already initialized: $_isInitialized");
    if (_isInitialized && _seesoPlugin != null) {
      print("DEBUG: SeeSo already initialized, ensuring tracking is active");
      await _ensureTrackingActive();
      return true;
    }

    try {
      print("DEBUG: Starting SeeSo initialization...");
      // Create SeeSo instance
      if (_seesoPlugin == null) {
        _seesoPlugin = SeeSo();
        print("DEBUG: SeeSo instance created");
      }

      // Check camera permission
      _hasCameraPermission = await _seesoPlugin!.checkCameraPermission();
      if (!_hasCameraPermission) {
        print("DEBUG: Requesting camera permission...");
        _hasCameraPermission = await _seesoPlugin!.requestCameraPermission();
      }

      if (!_hasCameraPermission) {
        throw Exception("Camera permission denied");
      }
      print("DEBUG: Camera permission granted");

      // Initialize SeeSo
      _statusMessage = "Initializing SeeSo...";
      notifyListeners();

      InitializedResult? result =
          await _seesoPlugin!.initGazeTracker(licenseKey: _licenseKey);
      _isInitialized = result?.result ?? false;
      _statusMessage = result?.message ?? "Unknown initialization result";

      print("DEBUG: SeeSo initialization result: $_isInitialized");
      print("DEBUG: SeeSo message: $_statusMessage");

      if (_isInitialized) {
        // Setup event listeners SEBELUM start tracking
        _setupEventListeners();
        // Start tracking
        await _startTracking();
        _statusMessage = "SeeSo initialized successfully";
      } else {
        throw Exception(_statusMessage);
      }

      notifyListeners();
      return _isInitialized;
    } catch (e) {
      print("DEBUG: SeeSo initialization error: ${e.toString()}");
      _statusMessage = "Initialization failed: ${e.toString()}";
      _isInitialized = false;
      notifyListeners();
      return false;
    }
  }

  void _setupEventListeners() {
    if (_seesoPlugin == null) return;
    print("DEBUG: Setting up SeeSo event listeners");

    try {
      // PENTING: Gaze events - ini yang mengupdate gaze point
      _seesoPlugin!.getGazeEvent().listen((event) {
        GazeInfo info = GazeInfo(event);
        // Update gaze position - KUNCI untuk gaze point
        _gazeX = info.x;
        _gazeY = info.y;
        _trackingState = info.trackingState;

        if (info.trackingState == TrackingState.SUCCESS) {
          _statusMessage = "Tracking: Excellent";
        } else {
          _statusMessage = "Tracking: ${info.trackingState.toString()}";
        }

        // CRITICAL: Only notify the ACTIVE page listener
        _notifyActivePageOnly();
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
        _notifyActivePageOnly();
      });

      // Calibration events
      _seesoPlugin!.getCalibrationEvent().listen((event) {
        CalibrationInfo caliInfo = CalibrationInfo(event);
        if (caliInfo.type == CalibrationType.CALIBRATION_NEXT_XY) {
          _isCalibrating = true;
          _calibrationComplete = false;
          print("DEBUG: Calibration next point");
        } else if (caliInfo.type == CalibrationType.CALIBRATION_FINISHED) {
          _isCalibrating = false;
          _calibrationComplete = true;
          _statusMessage = "Calibration Complete";
          print("DEBUG: Calibration finished");
          _notifyActivePageOnly();
        }
      });

      print("DEBUG: Event listeners setup complete");
    } catch (e) {
      print("DEBUG: Error setting up listeners: ${e.toString()}");
    }
  }

  void _notifyActivePageOnly() {
    // CRITICAL FIX: Only notify the currently active page
    if (_activePageId != null && _pageActiveStatus[_activePageId] == true) {
      final activeListener = _pageListeners[_activePageId];
      if (activeListener != null) {
        try {
          activeListener();
        } catch (e) {
          print(
              "DEBUG: Error calling active page listener ($_activePageId): $e");
        }
      }
    }

    // Also notify ChangeNotifier listeners (for widgets that use Provider/setState)
    notifyListeners();
  }

  Future<void> _startTracking() async {
    if (_seesoPlugin == null || !_isInitialized) return;

    try {
      print("DEBUG: Starting tracking...");
      await _seesoPlugin!.startTracking();
      _statusMessage = "Starting tracking...";
      notifyListeners();
    } catch (e) {
      print("DEBUG: Start tracking error: ${e.toString()}");
      _statusMessage = "Start tracking failed: ${e.toString()}";
      notifyListeners();
    }
  }

  Future<void> _ensureTrackingActive() async {
    if (_seesoPlugin == null || !_isInitialized) return;

    try {
      if (!_isTracking) {
        print("DEBUG: Restarting tracking...");
        await _seesoPlugin!.startTracking();
      }
    } catch (e) {
      print("DEBUG: Error ensuring tracking active: ${e.toString()}");
    }
  }

  // === CALIBRATION METHODS ===
  Future<void> startCalibration(
      {CalibrationMode mode = CalibrationMode.FIVE}) async {
    if (_seesoPlugin == null || !_isInitialized) {
      throw Exception('SeeSo not initialized');
    }

    try {
      print("DEBUG: Starting calibration...");
      await _seesoPlugin!.startCalibration(mode);
      _isCalibrating = true;
      _calibrationComplete = false;
      _statusMessage = "Calibration started";
      notifyListeners();
    } catch (e) {
      print("DEBUG: Calibration start error: ${e.toString()}");
      _statusMessage = "Calibration start failed: ${e.toString()}";
      notifyListeners();
      rethrow;
    }
  }

  Future<void> startCollectSamples() async {
    if (_seesoPlugin == null) return;

    try {
      await _seesoPlugin!.startCollectSamples();
    } catch (e) {
      print("DEBUG: Error starting collect samples: ${e.toString()}");
    }
  }

  // === COMPATIBILITY METHODS ===
  // Method ini untuk kompatibilitas dengan existing code
  Future<void> initialize(BuildContext context) async {
    print("DEBUG: initialize() called from UI component");
    if (!_isInitialized) {
      bool success = await initializeSeeSo();
      if (!success) {
        throw Exception("SeeSo initialization failed");
      }
    }
    // Ensure tracking is active
    await _ensureTrackingActive();
  }

  // DEPRECATED: Use setActivePage instead
  void addListener(VoidCallback listener) {
    print("WARNING: addListener is deprecated. Use setActivePage instead.");
    super.addListener(listener);
  }

  // DEPRECATED: Use removePage instead
  void removeListener(VoidCallback listener) {
    print("WARNING: removeListener is deprecated. Use removePage instead.");
    try {
      super.removeListener(listener);
    } catch (e) {
      print("DEBUG: Error removing listener: $e");
    }
  }

  bool get hasListeners => _pageListeners.isNotEmpty || super.hasListeners;

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

  // === UTILITY METHODS ===
  Future<void> stopTracking() async {
    if (_seesoPlugin == null || !_isInitialized) return;

    try {
      await _seesoPlugin!.stopTracking();
      _isTracking = false;
      _statusMessage = "Tracking stopped";
      notifyListeners();
    } catch (e) {
      print("DEBUG: Stop tracking error: ${e.toString()}");
    }
  }

  // === DEBUG METHODS ===
  void debugPrintStatus() {
    print("""
=== GlobalSeesoService Status ===
SeeSo Plugin: ${_seesoPlugin != null ? 'Created' : 'NULL'}
Initialized: $_isInitialized
Tracking: $_isTracking
Camera Permission: $_hasCameraPermission
Tracking State: $_trackingState
Status Message: $_statusMessage
Calibrating: $_isCalibrating
Calibration Complete: $_calibrationComplete
Active Page: $_activePageId
Page Listeners: ${_pageListeners.length}
Gaze Position: ($_gazeX, $_gazeY)
=================================
    """);
  }

  // Emergency cleanup for debugging
  void clearAllPageListeners() {
    print("DEBUG: EMERGENCY - Clearing all page listeners");
    _pageListeners.clear();
    _pageActiveStatus.clear();
    _activePageId = null;
    debugPageStatus();
  }

  // === CLEANUP ===
  void cleanup() {
    try {
      print("DEBUG: Cleaning up GlobalSeesoService...");
      if (_isTracking && _seesoPlugin != null) {
        _seesoPlugin!.stopTracking();
      }
      if (_isInitialized && _seesoPlugin != null) {
        _seesoPlugin!.deinitGazeTracker();
      }

      // Clear page management
      _pageListeners.clear();
      _pageActiveStatus.clear();
      _activePageId = null;

      _isInitialized = false;
      _isTracking = false;
      _seesoPlugin = null;
      print("DEBUG: Cleanup complete");
    } catch (e) {
      print("DEBUG: Cleanup error: ${e.toString()}");
    }
  }

  @override
  void dispose() {
    // Jangan dispose otomatis - singleton harus persist
    print("DEBUG: dispose() called - but singleton will persist");
    super.dispose();
  }
}
