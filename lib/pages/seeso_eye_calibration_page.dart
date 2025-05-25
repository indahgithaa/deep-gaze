import 'package:deep_gaze/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:seeso_flutter/event/calibration_info.dart';
import 'package:seeso_flutter/event/gaze_info.dart';
import 'package:seeso_flutter/event/status_info.dart';
import 'package:seeso_flutter/seeso.dart';
import 'package:seeso_flutter/seeso_initialized_result.dart';
import 'package:seeso_flutter/seeso_plugin_constants.dart';
import 'ruang_kelas.dart';

class SeesoEyeCalibrationPage extends StatefulWidget {
  const SeesoEyeCalibrationPage({super.key});

  @override
  State<SeesoEyeCalibrationPage> createState() =>
      _SeesoEyeCalibrationPageState();
}

class _SeesoEyeCalibrationPageState extends State<SeesoEyeCalibrationPage>
    with TickerProviderStateMixin {
  // SeeSo Plugin
  final _seesoPlugin = SeeSo();
  static const String _licenseKey = AppConstants.seesoLicenseKey;

  // State variables
  String _version = "Unknown";
  String _hasCameraPermissionString = "NOT_GRANTED";
  String _stateString = "IDLE";
  bool _hasCameraPermission = false;
  bool _isInitialized = false;
  bool _isTracking = false;
  bool _isCalibrating = false;
  bool _calibrationComplete = false;
  bool _isDisposed = false;

  // Gaze tracking
  double _gazeX = 0.0, _gazeY = 0.0;
  MaterialColor _gazeColor = Colors.red;

  // Calibration
  double _nextX = 0, _nextY = 0, _calibrationProgress = 0.0;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // App stage
  AppStage _currentStage = AppStage.checkingPermission;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _initializeSeeSo();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pulseController.dispose();
    _fadeController.dispose();

    // Clean up SeeSo resources
    if (_isInitialized) {
      try {
        _seesoPlugin.stopTracking();
        _seesoPlugin.deinitGazeTracker();
      } catch (e) {
        print('Error disposing SeeSo: $e');
      }
    }

    super.dispose();
  }

  Future<void> _initializeSeeSo() async {
    if (_isDisposed) return;

    try {
      // Get SeeSo version
      await _getSeeSoVersion();

      // Check camera permission
      await _checkCameraPermission();

      if (_hasCameraPermission) {
        setState(() {
          _currentStage = AppStage.initializing;
        });

        await _initGazeTracker();
      } else {
        setState(() {
          _currentStage = AppStage.permissionDenied;
        });
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _stateString = "Initialization failed: ${e.toString()}";
          _currentStage = AppStage.error;
        });
      }
    }
  }

  Future<void> _getSeeSoVersion() async {
    if (_isDisposed) return;

    try {
      String? seesoVersion = await _seesoPlugin.getSeeSoVersion();
      if (mounted && !_isDisposed) {
        setState(() {
          _version = seesoVersion ?? "Unknown";
        });
      }
    } catch (e) {
      print('Failed to get SeeSo version: $e');
    }
  }

  Future<void> _checkCameraPermission() async {
    if (_isDisposed) return;

    try {
      _hasCameraPermission = await _seesoPlugin.checkCameraPermission();

      if (!_hasCameraPermission) {
        _hasCameraPermission = await _seesoPlugin.requestCameraPermission();
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _hasCameraPermissionString =
              _hasCameraPermission ? "GRANTED" : "DENIED";
        });
      }
    } catch (e) {
      print('Camera permission error: $e');
    }
  }

  Future<void> _initGazeTracker() async {
    if (_isDisposed) return;

    try {
      InitializedResult? result =
          await _seesoPlugin.initGazeTracker(licenseKey: _licenseKey);

      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialized = result?.result ?? false;
          _stateString = result?.message ?? "Unknown error";
        });

        if (_isInitialized) {
          _listenToSeesoEvents();
          await _startTracking();
          setState(() {
            _currentStage = AppStage.initialized;
          });
        } else {
          setState(() {
            _currentStage = AppStage.error;
          });
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _stateString = "Init failed: ${e.toString()}";
          _currentStage = AppStage.error;
        });
      }
    }
  }

  Future<void> _startTracking() async {
    if (_isDisposed || !_isInitialized) return;

    try {
      await _seesoPlugin.startTracking();
      if (mounted && !_isDisposed) {
        setState(() {
          _isTracking = true;
        });
      }
    } catch (e) {
      print('Start tracking error: $e');
    }
  }

  void _listenToSeesoEvents() {
    if (_isDisposed) return;

    // Listen to gaze events
    _seesoPlugin.getGazeEvent().listen((event) {
      if (_isDisposed || !mounted) return;

      GazeInfo info = GazeInfo(event);
      if (info.trackingState == TrackingState.SUCCESS) {
        setState(() {
          _gazeX = info.x;
          _gazeY = info.y;
          _gazeColor = Colors.green;
        });
      } else {
        setState(() {
          _gazeColor = Colors.red;
        });
      }
    });

    // Listen to status events
    _seesoPlugin.getStatusEvent().listen((event) {
      if (_isDisposed || !mounted) return;

      StatusInfo statusInfo = StatusInfo(event);
      if (statusInfo.type == StatusType.START) {
        setState(() {
          _stateString = "Tracking Started";
          _isTracking = true;
        });
      } else {
        setState(() {
          _stateString = "Tracking Stopped: ${statusInfo.stateErrorType}";
          _isTracking = false;
        });
      }
    });

    // Listen to calibration events
    _seesoPlugin.getCalibrationEvent().listen((event) {
      if (_isDisposed || !mounted) return;

      CalibrationInfo caliInfo = CalibrationInfo(event);

      if (caliInfo.type == CalibrationType.CALIBRATION_NEXT_XY) {
        setState(() {
          _nextX = caliInfo.nextX!;
          _nextY = caliInfo.nextY!;
          _calibrationProgress = 0.0;
        });

        // Start collecting samples after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isDisposed && _isCalibrating) {
            _seesoPlugin.startCollectSamples();
          }
        });
      } else if (caliInfo.type == CalibrationType.CALIBRATION_PROGRESS) {
        setState(() {
          _calibrationProgress = caliInfo.progress!;
        });
      } else if (caliInfo.type == CalibrationType.CALIBRATION_FINISHED) {
        setState(() {
          _isCalibrating = false;
          _calibrationComplete = true;
          _currentStage = AppStage.calibrationComplete;
        });

        _pulseController.stop();
        _fadeController.forward();

        // Navigate to classroom after showing completion
        Future.delayed(const Duration(seconds: 2), () {
          if (!_isDisposed && mounted) {
            _navigateToClassroom();
          }
        });
      }
    });
  }

  void _startCalibration() {
    if (_isDisposed || !_isInitialized || !_isTracking) return;

    try {
      _seesoPlugin.startCalibration(CalibrationMode.FIVE);
      setState(() {
        _isCalibrating = true;
        _currentStage = AppStage.calibrating;
      });

      _pulseController.repeat(reverse: true);
    } catch (e) {
      print('Calibration start error: $e');
      setState(() {
        _stateString = "Calibration failed: ${e.toString()}";
      });
    }
  }

  void _skipCalibration() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Skip Calibration?'),
          content: const Text(
            'Skipping calibration may reduce eye tracking accuracy. Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToClassroom();
              },
              child: const Text('Skip'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToClassroom() {
    if (_isDisposed || !mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RuangKelas(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade900,
              Colors.indigo.shade600,
              Colors.blue.shade400,
            ],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildMainContent(),
              ),
            ),

            // Gaze point indicator
            if (_isTracking && !_isCalibrating)
              Positioned(
                left: _gazeX - 5,
                top: _gazeY - 5,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _gazeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _gazeColor.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

            // Calibration point
            if (_isCalibrating)
              Positioned(
                left: _nextX - 20,
                top: _nextY - 20,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.shade400,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: _calibrationProgress,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Status overlay
            _buildStatusOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentStage) {
      case AppStage.checkingPermission:
        return _buildLoadingWidget("Checking camera permission...");

      case AppStage.permissionDenied:
        return _buildPermissionWidget();

      case AppStage.initializing:
        return _buildLoadingWidget("Initializing eye tracking...");

      case AppStage.error:
        return _buildErrorWidget();

      case AppStage.initialized:
        return _buildReadyWidget();

      case AppStage.calibrating:
        return _buildCalibratingWidget();

      case AppStage.calibrationComplete:
        return _buildCompletionWidget();

      default:
        return _buildLoadingWidget("Loading...");
    }
  }

  Widget _buildLoadingWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt,
            size: 80,
            color: Colors.white70,
          ),
          const SizedBox(height: 20),
          const Text(
            'Camera Permission Required',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Eye tracking requires camera access to function properly.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _checkCameraPermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 20),
          const Text(
            'Initialization Failed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _stateString,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _initializeSeeSo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyWidget() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.visibility,
          size: 80,
          color: Colors.white.withOpacity(0.9),
        ),
        const SizedBox(height: 20),
        const Text(
          'Eye Calibration',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Eye Tracking Ready',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'To improve accuracy, we recommend calibrating your eye tracking.\n\n'
                    '• Look directly at each calibration point\n'
                    '• Keep your head still during calibration\n'
                    '• The process takes about 30 seconds',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _skipCalibration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: _startCalibration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('Start Calibration'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalibratingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Look at the red circle',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            '${(_calibrationProgress * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Keep your head still and focus on the circle',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionWidget() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green.shade400,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Calibration Complete!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Redirecting to classroom...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusOverlay() {
    return Positioned(
      top: 50,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SeeSo v$_version',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
            Text(
              'Camera: $_hasCameraPermissionString',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
            Text(
              'Status: $_stateString',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
            if (_isTracking)
              Text(
                'Gaze: (${_gazeX.toInt()}, ${_gazeY.toInt()})',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum AppStage {
  checkingPermission,
  permissionDenied,
  initializing,
  initialized,
  calibrating,
  calibrationComplete,
  error,
}
