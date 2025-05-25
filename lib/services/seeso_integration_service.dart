// File: lib/services/seeso_integration_service.dart

import 'package:flutter/material.dart';
import 'package:seeso_flutter/event/gaze_info.dart';
import 'package:seeso_flutter/event/status_info.dart';
import 'package:seeso_flutter/event/calibration_info.dart';
import 'package:seeso_flutter/seeso.dart';
import 'package:seeso_flutter/seeso_plugin_constants.dart';

/// Service that integrates SeeSo SDK with your existing eye tracking system
/// This allows you to use SeeSo data in your existing widgets and pages
class SeesoIntegrationService extends ChangeNotifier {
  // SeeSo instance
  final SeeSo _seesoPlugin = SeeSo();

  // Current gaze position
  double _gazeX = 0.0;
  double _gazeY = 0.0;

  // Tracking state
  bool _isTracking = false;
  bool _isInitialized = false;
  String _statusMessage = "Idle";

  // Gaze tracking quality
  TrackingState _trackingState = TrackingState.FACE_MISSING;

  // Listeners for gaze updates
  final List<VoidCallback> _listeners = [];

  // Getters to match your existing EyeTrackingService interface
  double get gazeX => _gazeX;
  double get gazeY => _gazeY;
  bool get isTracking => _isTracking && _trackingState == TrackingState.SUCCESS;
  String get statusMessage => _statusMessage;
  bool get isInitialized => _isInitialized;
  TrackingState get trackingQuality => _trackingState;

  // Constructor
  SeesoIntegrationService() {
    _initializeListeners();
  }

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
      for (var listener in _listeners) {
        try {
          listener();
        } catch (e) {
          print('Error calling gaze listener: $e');
        }
      }

      notifyListeners();
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
      for (var listener in _listeners) {
        try {
          listener();
        } catch (e) {
          print('Error calling status listener: $e');
        }
      }

      notifyListeners();
    });

    // Listen to calibration events (optional - for additional calibration data logging)
    _seesoPlugin.getCalibrationEvent().listen((event) {
      CalibrationInfo caliInfo = CalibrationInfo(event);

      if (caliInfo.type == CalibrationType.CALIBRATION_NEXT_XY) {
        // Log calibration point when SeeSo moves to next calibration point
        if (caliInfo.nextX != null && caliInfo.nextY != null) {
          addCalibrationPoint(caliInfo.nextX!, caliInfo.nextY!);
        }
      } else if (caliInfo.type == CalibrationType.CALIBRATION_FINISHED) {
        _statusMessage = "Calibration Complete - ${getCalibrationStatus()}";

        // Notify all listeners
        for (var listener in _listeners) {
          try {
            listener();
          } catch (e) {
            print('Error calling calibration listener: $e');
          }
        }

        notifyListeners();
      }
    });
  }

  // Initialize the service (to be called after SeeSo calibration is complete)
  Future<void> initialize(BuildContext context) async {
    try {
      // SeeSo should already be initialized from the calibration page
      _isInitialized = true;
      _statusMessage = "SeeSo Integration Ready";
      notifyListeners();
    } catch (e) {
      _statusMessage = "Integration Error: ${e.toString()}";
      _isInitialized = false;
      notifyListeners();
      rethrow;
    }
  }

  // Add listener (to match your existing EyeTrackingService interface)
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  // Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  // Check if has listeners
  bool get hasListeners => _listeners.isNotEmpty;

  // Start tracking (if not already started)
  Future<void> startTracking() async {
    try {
      if (_isInitialized && !_isTracking) {
        await _seesoPlugin.startTracking();
      }
    } catch (e) {
      _statusMessage = "Start Tracking Error: ${e.toString()}";
      notifyListeners();
    }
  }

  // Stop tracking
  Future<void> stopTracking() async {
    try {
      if (_isInitialized && _isTracking) {
        await _seesoPlugin.stopTracking();
      }
    } catch (e) {
      _statusMessage = "Stop Tracking Error: ${e.toString()}";
      notifyListeners();
    }
  }

  // Get calibrated gaze position (same as current gaze since SeeSo handles calibration)
  Offset getCalibratedGaze() {
    return Offset(_gazeX, _gazeY);
  }

  // Check if gaze is within a rectangle (helper method for dwell time detection)
  bool isGazeWithinRect(Rect rect) {
    if (!isTracking) return false;
    return rect.contains(Offset(_gazeX, _gazeY));
  }

  // Get gaze accuracy (SeeSo provides this internally, so we estimate based on tracking state)
  double getGazeAccuracy() {
    switch (_trackingState) {
      case TrackingState.SUCCESS:
        return 0.95; // 95% accuracy for successful tracking
      case TrackingState.LOW_CONFIDENCE:
        return 0.7; // 70% accuracy for low confidence
      case TrackingState.UNSUPPORTED:
      case TrackingState.FACE_MISSING:
      default:
        return 0.0; // 0% accuracy for failed tracking
    }
  }

  // Dispose method
  @override
  void dispose() {
    _listeners.clear();

    // Don't dispose SeeSo here as it might be used by other parts of the app
    // The calibration page should handle SeeSo disposal when the app closes

    super.dispose();
  }

  // Additional helper methods for compatibility

  // Check if face is detected
  bool get isFaceDetected => _trackingState != TrackingState.FACE_MISSING;

  // Check if tracking is stable
  bool get isTrackingStable => _trackingState == TrackingState.SUCCESS;

  // Get tracking status as string
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

  // Get distance from center of screen (for UI feedback)
  double getDistanceFromCenter(Size screenSize) {
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;
    final dx = _gazeX - centerX;
    final dy = _gazeY - centerY;
    return (dx * dx + dy * dy);
  }

  // Check if gaze is near screen edges (for boundary detection)
  bool isGazeNearEdge(Size screenSize, {double threshold = 50.0}) {
    return _gazeX < threshold ||
        _gazeY < threshold ||
        _gazeX > screenSize.width - threshold ||
        _gazeY > screenSize.height - threshold;
  }

  // Advanced dwell time detection methods

  // Check if gaze has been within a rect for a specified duration
  bool isGazeDwellingInRect(Rect rect, Duration dwellTime) {
    if (!isGazeWithinRect(rect)) return false;

    // This would require tracking dwell history - implement in the UI layer
    // Return true for now if gaze is within rect
    return true;
  }

  // Get gaze velocity (useful for detecting intentional vs accidental gaze)
  double getGazeVelocity() {
    // This would require storing previous gaze positions and calculating velocity
    // For now, return 0 - implement in UI layer with position history
    return 0.0;
  }

  // Smooth gaze coordinates (reduce jitter)
  static final List<Offset> _gazeHistory = [];
  static const int _smoothingWindow = 5;

  Offset getSmoothedGaze() {
    // Add current gaze to history
    _gazeHistory.add(Offset(_gazeX, _gazeY));

    // Keep only recent history
    if (_gazeHistory.length > _smoothingWindow) {
      _gazeHistory.removeAt(0);
    }

    // Calculate average position
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

  // Calibration data management (for compatibility with existing calibration extensions)

  static final List<CalibrationDataPoint> _calibrationData = [];
  static bool _hasCalibrationData = false;

  // Add calibration point (SeeSo handles this internally, but we can store for reference)
  void addCalibrationPoint(double screenX, double screenY) {
    final calibrationPoint = CalibrationDataPoint(
      screenX: screenX,
      screenY: screenY,
      gazeX: _gazeX,
      gazeY: _gazeY,
      timestamp: DateTime.now(),
      quality: _trackingState,
    );

    _calibrationData.add(calibrationPoint);
    _hasCalibrationData = true;

    print(
        'SeeSo calibration point logged: Screen($screenX, $screenY) -> Gaze($_gazeX, $_gazeY)');
  }

  // Get calibration data
  List<CalibrationDataPoint> get calibrationPoints =>
      List.unmodifiable(_calibrationData);

  // Check if has calibration data
  bool get hasCalibrationData => _hasCalibrationData;

  // Reset calibration data
  void resetCalibrationData() {
    _calibrationData.clear();
    _hasCalibrationData = false;
    print('SeeSo calibration data reset');
  }

  // Get calibration accuracy based on stored calibration points
  double getCalibrationAccuracy() {
    if (_calibrationData.isEmpty) return 0.0;

    double totalAccuracy = 0.0;
    int validPoints = 0;

    for (final point in _calibrationData) {
      if (point.quality == TrackingState.SUCCESS) {
        // Calculate accuracy based on distance between expected and actual gaze
        final dx = point.screenX - point.gazeX;
        final dy = point.screenY - point.gazeY;
        final distance = (dx * dx + dy * dy);

        // Convert distance to accuracy percentage (lower distance = higher accuracy)
        final accuracy = (100 - (distance / 100)).clamp(0.0, 100.0);
        totalAccuracy += accuracy;
        validPoints++;
      }
    }

    return validPoints > 0 ? totalAccuracy / validPoints : 0.0;
  }

  // Get calibration status string
  String getCalibrationStatus() {
    if (!_hasCalibrationData) return 'Not Calibrated';

    final accuracy = getCalibrationAccuracy();
    if (accuracy >= 90) return 'Excellent';
    if (accuracy >= 80) return 'Good';
    if (accuracy >= 70) return 'Fair';
    return 'Poor';
  }

  // Export calibration and tracking data for analysis
  Map<String, dynamic> exportTrackingData() {
    return {
      'seesoIntegration': true,
      'isInitialized': _isInitialized,
      'isTracking': _isTracking,
      'trackingState': _trackingState.toString(),
      'currentGaze': {
        'x': _gazeX,
        'y': _gazeY,
      },
      'gazeAccuracy': getGazeAccuracy(),
      'trackingStatus': trackingStatusString,
      'calibrationData': {
        'hasData': _hasCalibrationData,
        'pointCount': _calibrationData.length,
        'accuracy': getCalibrationAccuracy(),
        'status': getCalibrationStatus(),
        'points': _calibrationData.map((point) => point.toMap()).toList(),
      },
      'gazeHistory': _gazeHistory
          .map((point) => {
                'x': point.dx,
                'y': point.dy,
              })
          .toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Debug methods

  // Print current tracking status
  void debugPrintStatus() {
    print('''
=== SeeSo Integration Service Status ===
Initialized: $_isInitialized
Tracking: $_isTracking
Tracking State: $_trackingState
Current Gaze: ($_gazeX, $_gazeY)
Gaze Accuracy: ${(getGazeAccuracy() * 100).toInt()}%
Face Detected: $isFaceDetected
Tracking Stable: $isTrackingStable
Status Message: $_statusMessage
Calibration Points: ${_calibrationData.length}
Has Calibration Data: $_hasCalibrationData
Calibration Accuracy: ${getCalibrationAccuracy().toStringAsFixed(1)}%
Calibration Status: ${getCalibrationStatus()}
=========================================
    ''');
  }

  // Get comprehensive status for UI display
  Map<String, dynamic> getComprehensiveStatus() {
    return {
      'tracking': {
        'isActive': _isTracking,
        'state': _trackingState.toString(),
        'quality': trackingStatusString,
        'accuracy': (getGazeAccuracy() * 100).toInt(),
      },
      'gaze': {
        'x': _gazeX.toInt(),
        'y': _gazeY.toInt(),
        'smoothed': getSmoothedGaze(),
      },
      'face': {
        'detected': isFaceDetected,
        'stable': isTrackingStable,
      },
      'calibration': {
        'hasData': _hasCalibrationData,
        'points': _calibrationData.length,
        'accuracy': getCalibrationAccuracy().toStringAsFixed(1),
        'status': getCalibrationStatus(),
      },
      'system': {
        'initialized': _isInitialized,
        'statusMessage': _statusMessage,
        'listeners': _listeners.length,
      }
    };
  }
}

// Data class for storing calibration points with SeeSo integration
class CalibrationDataPoint {
  final double screenX;
  final double screenY;
  final double gazeX;
  final double gazeY;
  final DateTime timestamp;
  final TrackingState quality;

  CalibrationDataPoint({
    required this.screenX,
    required this.screenY,
    required this.gazeX,
    required this.gazeY,
    required this.timestamp,
    required this.quality,
  });

  // Calculate error distance
  double get errorDistance {
    final dx = screenX - gazeX;
    final dy = screenY - gazeY;
    return (dx * dx + dy * dy);
  }

  // Get accuracy percentage for this point
  double get accuracy {
    final distance = errorDistance;
    return (100 - (distance / 100)).clamp(0.0, 100.0);
  }

  // Check if this calibration point is valid
  bool get isValid => quality == TrackingState.SUCCESS;

  // Convert to map for export
  Map<String, dynamic> toMap() {
    return {
      'screenX': screenX,
      'screenY': screenY,
      'gazeX': gazeX,
      'gazeY': gazeY,
      'timestamp': timestamp.toIso8601String(),
      'quality': quality.toString(),
      'errorDistance': errorDistance,
      'accuracy': accuracy,
      'isValid': isValid,
    };
  }

  @override
  String toString() {
    return 'CalibrationDataPoint('
        'screen: ($screenX, $screenY), '
        'gaze: ($gazeX, $gazeY), '
        'quality: $quality, '
        'accuracy: ${accuracy.toStringAsFixed(1)}%, '
        'error: ${errorDistance.toStringAsFixed(2)}'
        ')';
  }
}
