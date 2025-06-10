// File: lib/pages/eye_calibration_page.dart
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
import '../services/global_seeso_service.dart'; // Import service global
import '../widgets/main_app_scaffold.dart'; // CHANGED: Import MainAppScaffold instead of RuangKelas

class EyeCalibrationPage extends StatefulWidget {
  const EyeCalibrationPage({super.key});

  @override
  State<EyeCalibrationPage> createState() => _EyeCalibrationPageState();
}

class _EyeCalibrationPageState extends State<EyeCalibrationPage>
    with TickerProviderStateMixin {
  // Gunakan service global
  late GlobalSeesoService _seesoService;

  // SeeSo Plugin untuk kalibrasi
  final _seesoPlugin = SeeSo();
  static const String _licenseKey = AppConstants.seesoLicenseKey;

  // State variables
  String _version = "Unknown";
  bool _isDisposed = false;

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
    // Initialize service global
    _seesoService = GlobalSeesoService();

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
    // JANGAN dispose service global di sini!
    // Service harus tetap hidup untuk halaman berikutnya
    super.dispose();
  }

  Future<void> _initializeSeeSo() async {
    if (_isDisposed) return;

    try {
      // Get SeeSo version
      await _getSeeSoVersion();

      setState(() {
        _currentStage = AppStage.initializing;
      });

      // Initialize service global
      bool success = await _seesoService.initializeSeeSo();

      if (success) {
        _listenToSeesoEvents();
        setState(() {
          _currentStage = AppStage.initialized;
        });
      } else {
        setState(() {
          _currentStage = AppStage.error;
        });
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
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

  void _listenToSeesoEvents() {
    if (_isDisposed) return;

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
          if (!_isDisposed && _seesoService.isCalibrating) {
            _seesoService.startCollectSamples();
          }
        });
      } else if (caliInfo.type == CalibrationType.CALIBRATION_PROGRESS) {
        setState(() {
          _calibrationProgress = caliInfo.progress!;
        });
      } else if (caliInfo.type == CalibrationType.CALIBRATION_FINISHED) {
        setState(() {
          _currentStage = AppStage.calibrationComplete;
        });

        _pulseController.stop();
        _fadeController.forward();

        // Navigate to main app after showing completion
        Future.delayed(const Duration(seconds: 2), () {
          if (!_isDisposed && mounted) {
            _navigateToMainApp(); // CHANGED: Navigate to MainAppScaffold
          }
        });
      }
    });
  }

  void _startCalibration() {
    if (_isDisposed || !_seesoService.isInitialized) return;

    try {
      _seesoService.startCalibration(mode: CalibrationMode.FIVE);
      setState(() {
        _currentStage = AppStage.calibrating;
      });
      _pulseController.repeat(reverse: true);
    } catch (e) {
      print('Calibration start error: $e');
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
                _navigateToMainApp(); // CHANGED: Navigate to MainAppScaffold
              },
              child: const Text('Skip'),
            ),
          ],
        );
      },
    );
  }

  // CHANGED: Navigate to MainAppScaffold instead of RuangKelas
  void _navigateToMainApp() {
    if (_isDisposed || !mounted) return;

    print("DEBUG: Navigating to MainAppScaffold with navigation bar");
    _seesoService.debugPrintStatus();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainAppScaffold(
                initialIndex: 1), // Start with Home (RuangKelas)
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
        color: Colors.white,
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildMainContent(),
              ),
            ),
            // Calibration point
            if (_seesoService.isCalibrating)
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
            // _buildStatusOverlay(),
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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: Colors.black,
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
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          const Text(
            'Camera Permission Required',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Eye tracking requires camera access to function properly.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
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
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _seesoService.statusMessage,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
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
          color: Color(0xFF4040D9),
        ),
        const SizedBox(height: 20),
        const Text(
          'Eye Calibration',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black,
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
                    color: Colors.black,
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
                      color: Colors.black,
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
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            '${(_calibrationProgress * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Keep your head still and focus on the circle',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
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
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Redirecting to classroom...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
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
              'Camera: ${_seesoService.hasCameraPermission ? "GRANTED" : "DENIED"}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
            Text(
              'Status: ${_seesoService.statusMessage}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
            if (_seesoService.isTracking)
              Text(
                'Gaze: (${_seesoService.gazeX.toInt()}, ${_seesoService.gazeY.toInt()})',
                style: const TextStyle(
                  color: Colors.white,
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
