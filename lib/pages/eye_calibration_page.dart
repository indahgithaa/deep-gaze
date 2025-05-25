import 'package:deep_gaze/pages/ruang_kelas.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/eye_tracking_service.dart';
import '../services/eye_tracking_extensions.dart';
import '../widgets/gaze_point_widget.dart';

class EyeCalibrationPage extends StatefulWidget {
  const EyeCalibrationPage({super.key});

  @override
  State<EyeCalibrationPage> createState() => _EyeCalibrationPageState();
}

class _EyeCalibrationPageState extends State<EyeCalibrationPage>
    with TickerProviderStateMixin {
  late EyeTrackingService _eyeTrackingService;
  bool _isDisposed = false;

  // Calibration state
  int _currentCalibrationPoint = 0;
  bool _isCalibrating = false;
  bool _calibrationComplete = false;
  Timer? _calibrationTimer;
  int _calibrationCountdown = 0;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  // Calibration points (9-point calibration)
  final List<CalibrationPoint> _calibrationPoints = [
    CalibrationPoint(0.1, 0.1, "Top Left"), // Top-left
    CalibrationPoint(0.5, 0.1, "Top Center"), // Top-center
    CalibrationPoint(0.9, 0.1, "Top Right"), // Top-right
    CalibrationPoint(0.1, 0.5, "Middle Left"), // Middle-left
    CalibrationPoint(0.5, 0.5, "Center"), // Center
    CalibrationPoint(0.9, 0.5, "Middle Right"), // Middle-right
    CalibrationPoint(0.1, 0.9, "Bottom Left"), // Bottom-left
    CalibrationPoint(0.5, 0.9, "Bottom Center"), // Bottom-center
    CalibrationPoint(0.9, 0.9, "Bottom Right"), // Bottom-right
  ];

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = EyeTrackingService();
    _eyeTrackingService.addListener(_onEyeTrackingUpdate);

    // Initialize animation controllers
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _initializeEyeTracking();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _calibrationTimer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();

    if (_eyeTrackingService.hasListeners) {
      _eyeTrackingService.removeListener(_onEyeTrackingUpdate);
    }

    super.dispose();
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;

    try {
      await _eyeTrackingService.initialize(context);
      if (mounted && !_isDisposed) {
        setState(() {});
      }
    } catch (e) {
      print('Eye tracking initialization failed: $e');
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Eye tracking initialization failed: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _startCalibration() {
    if (_isDisposed || !mounted) return;

    setState(() {
      _isCalibrating = true;
      _currentCalibrationPoint = 0;
      _calibrationComplete = false;
    });

    _pulseController.repeat(reverse: true);
    _startCalibrationPoint();
  }

  void _startCalibrationPoint() {
    if (_isDisposed || !mounted) return;

    setState(() {
      _calibrationCountdown = 3; // 3 second countdown
    });

    _calibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _calibrationCountdown--;
      });

      if (_calibrationCountdown <= 0) {
        timer.cancel();
        _completeCalibrationPoint();
      }
    });
  }

  void _completeCalibrationPoint() {
    if (_isDisposed || !mounted) return;

    final currentPoint = _calibrationPoints[_currentCalibrationPoint];

    // Simulate calibration data collection
    // In real implementation, this would collect gaze data
    _eyeTrackingService.addCalibrationPoint(currentPoint.x, currentPoint.y);

    _progressController.forward().then((_) {
      if (_isDisposed || !mounted) return;

      _progressController.reset();

      setState(() {
        _currentCalibrationPoint++;
      });

      if (_currentCalibrationPoint >= _calibrationPoints.length) {
        _completeCalibration();
      } else {
        _startCalibrationPoint();
      }
    });
  }

  void _completeCalibration() {
    if (_isDisposed || !mounted) return;

    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _isCalibrating = false;
      _calibrationComplete = true;
    });

    // Validate calibration quality
    final accuracy = _eyeTrackingService.getCalibrationAccuracy();
    final status = _eyeTrackingService.getCalibrationStatus();

    print(
        'Calibration completed with ${accuracy.toStringAsFixed(1)}% accuracy ($status)');

    // Show calibration results
    if (mounted && !_isDisposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Calibration Complete: ${accuracy.toStringAsFixed(1)}% accuracy ($status)',
          ),
          backgroundColor: accuracy >= 70 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Show completion message and navigate
    Future.delayed(const Duration(seconds: 2), () {
      if (_isDisposed || !mounted) return;
      _navigateToMainApp();
    });
  }

  void _navigateToMainApp() {
    if (_isDisposed || !mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RuangKelas(), // atau RuangKelas()
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

  void _skipCalibration() {
    if (_isDisposed || !mounted) return;

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
                _navigateToMainApp();
              },
              child: const Text('Skip'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

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
            // Main content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Header
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

                    // Instructions
                    Expanded(
                      child: Center(
                        child: _buildInstructions(),
                      ),
                    ),

                    // Progress indicator
                    if (_isCalibrating) _buildProgressIndicator(),

                    const SizedBox(height: 40),

                    // Action buttons
                    if (!_isCalibrating) _buildActionButtons(),
                  ],
                ),
              ),
            ),

            // Calibration points
            if (_isCalibrating) _buildCalibrationPoints(screenSize),

            // Gaze point indicator
            if (_eyeTrackingService.isTracking)
              GazePointWidget(
                gazeX: _eyeTrackingService.gazeX,
                gazeY: _eyeTrackingService.gazeY,
                isVisible: true,
              ),

            // Status overlay
            _buildStatusOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    if (_calibrationComplete) {
      final accuracy = _eyeTrackingService.getCalibrationAccuracy();
      final status = _eyeTrackingService.getCalibrationStatus();

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            accuracy >= 70 ? Icons.check_circle : Icons.warning,
            size: 80,
            color:
                accuracy >= 70 ? Colors.green.shade400 : Colors.orange.shade400,
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
          Text(
            'Accuracy: ${accuracy.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            'Status: $status',
            style: TextStyle(
              fontSize: 16,
              color: accuracy >= 70
                  ? Colors.green.shade300
                  : Colors.orange.shade300,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            'Redirecting to main application...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          if (accuracy < 70) ...[
            const SizedBox(height: 15),
            const Text(
              '⚠️ Low accuracy detected. Consider recalibrating later.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
    }

    if (_isCalibrating) {
      final currentPoint = _calibrationPoints[_currentCalibrationPoint];
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Look at the ${currentPoint.name} point',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          if (_calibrationCountdown > 0)
            Text(
              '$_calibrationCountdown',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Point ${_currentCalibrationPoint + 1} of ${_calibrationPoints.length}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Eye Tracking Calibration',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'To ensure accurate eye tracking, we need to calibrate your gaze.\n\n'
            '• Look directly at each calibration point\n'
            '• Keep your head still during calibration\n'
            '• Follow the points as they appear\n'
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
    );
  }

  Widget _buildActionButtons() {
    if (_calibrationComplete) {
      final accuracy = _eyeTrackingService.getCalibrationAccuracy();

      return Column(
        children: [
          if (accuracy < 70)
            ElevatedButton(
              onPressed: () {
                _eyeTrackingService.resetCalibration();
                setState(() {
                  _calibrationComplete = false;
                  _currentCalibrationPoint = 0;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('Recalibrate'),
            ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _navigateToMainApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text('Continue to App'),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: _skipCalibration,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _startCalibration,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: const Text('Start Calibration'),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _currentCalibrationPoint / _calibrationPoints.length;

    return Column(
      children: [
        Text(
          'Progress: ${(_currentCalibrationPoint)}/${_calibrationPoints.length}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
        ),
      ],
    );
  }

  Widget _buildCalibrationPoints(Size screenSize) {
    return Stack(
      children: _calibrationPoints.asMap().entries.map((entry) {
        final index = entry.key;
        final point = entry.value;
        final isActive = index == _currentCalibrationPoint;
        final isCompleted = index < _currentCalibrationPoint;

        return Positioned(
          left: point.x * screenSize.width - 25,
          top: point.y * screenSize.height - 25,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isActive ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.green.shade400
                        : isActive
                            ? Colors.red.shade400
                            : Colors.white.withOpacity(0.3),
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
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          )
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
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
              'Eye Tracking: ${_eyeTrackingService.isTracking ? "Active" : "Inactive"}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
            if (_eyeTrackingService.isTracking)
              Text(
                'Gaze: (${_eyeTrackingService.gazeX.toInt()}, ${_eyeTrackingService.gazeY.toInt()})',
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

class CalibrationPoint {
  final double x;
  final double y;
  final String name;

  CalibrationPoint(this.x, this.y, this.name);
}
