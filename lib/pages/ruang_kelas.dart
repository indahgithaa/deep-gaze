import 'package:flutter/material.dart';
import 'dart:async';
import '../models/page_data.dart';
import '../models/selectable_button.dart';
import '../services/seeso_integration_service.dart'; // Use SeeSo integration instead
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import '../widgets/selectable_button_widget.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'game_page.dart';

class RuangKelas extends StatefulWidget {
  const RuangKelas({super.key});

  @override
  State<RuangKelas> createState() => _RuangKelasState();
}

class _RuangKelasState extends State<RuangKelas> {
  late SeesoIntegrationService _eyeTrackingService; // Use SeeSo integration
  bool _isDisposed = false;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration - 1.5 seconds for buttons
  static const int _dwellTimeMs = 1500; // 1.5 seconds
  static const int _dwellUpdateIntervalMs = 50; // Update every 50ms

  // Button boundaries for automatic detection
  final Map<String, Rect> _buttonBounds = {};

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = SeesoIntegrationService(); // Use SeeSo integration
    _eyeTrackingService.addListener(_onEyeTrackingUpdate);
    _initializeEyeTracking();
    _initializeButtonBounds();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _dwellTimer = null;

    // Remove listener first, then dispose
    if (_eyeTrackingService.hasListeners) {
      _eyeTrackingService.removeListener(_onEyeTrackingUpdate);
    }

    // Don't dispose the service here as SeeSo should remain active
    // The main app or calibration page should handle SeeSo disposal

    super.dispose();
  }

  void _initializeButtonBounds() {
    // Define button boundaries for automatic detection
    // Adjust these coordinates based on your actual button positions
    _buttonBounds['go_to_settings'] = const Rect.fromLTWH(50, 380, 300, 70);
    _buttonBounds['go_to_profile'] = const Rect.fromLTWH(50, 470, 300, 70);
    _buttonBounds['start_game'] = const Rect.fromLTWH(50, 560, 300, 70);
  }

  void _onEyeTrackingUpdate() {
    // Check if widget is disposed
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);
    String? hoveredButton;

    // Check which button (if any) the gaze is currently hovering over
    for (final entry in _buttonBounds.entries) {
      if (entry.value.contains(currentGazePoint)) {
        hoveredButton = entry.key;
        break;
      }
    }

    if (hoveredButton != null) {
      // Gaze is within a button boundary
      if (_currentDwellingElement != hoveredButton) {
        // Start dwell timer for new button
        final pageData = _getPageData();
        final button =
            pageData.buttons.firstWhere((b) => b.id == hoveredButton);
        _startDwellTimer(hoveredButton, button.action as int? Function());
      }
      // If it's the same button, the timer continues running
    } else {
      // Gaze is not within any button boundary
      if (_currentDwellingElement != null) {
        // Cancel current dwell timer
        _stopDwellTimer();
      }
    }

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;

    try {
      // SeeSo should already be initialized from calibration page
      await _eyeTrackingService.initialize(context);

      // Ensure tracking is started
      await _eyeTrackingService.startTracking();
    } catch (e) {
      print('Eye tracking initialization failed: $e');
      // Don't throw the error, just log it
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Eye tracking initialization failed: ${e.toString()}"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _startDwellTimer(String elementId, int? Function() action) {
    if (_isDisposed || !mounted) return;
    if (_currentDwellingElement == elementId) return;

    _stopDwellTimer();

    if (mounted && !_isDisposed) {
      setState(() {
        _currentDwellingElement = elementId;
        _dwellProgress = 0.0;
      });
    }

    _dwellStartTime = DateTime.now();

    _dwellTimer = Timer.periodic(
      Duration(milliseconds: _dwellUpdateIntervalMs),
      (timer) {
        // Check if widget is disposed or unmounted
        if (_isDisposed || !mounted || _currentDwellingElement != elementId) {
          timer.cancel();
          return;
        }

        final elapsed =
            DateTime.now().difference(_dwellStartTime!).inMilliseconds;
        final progress = (elapsed / _dwellTimeMs).clamp(0.0, 1.0);

        if (mounted && !_isDisposed) {
          setState(() {
            _dwellProgress = progress;
          });
        }

        if (progress >= 1.0) {
          timer.cancel();
          if (mounted && !_isDisposed) {
            _onElementSelected(action);
          }
        }
      },
    );
  }

  void _stopDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = null;

    if (mounted && !_isDisposed) {
      setState(() {
        _currentDwellingElement = null;
        _dwellProgress = 0.0;
      });
    }
  }

  void _onElementSelected(int? Function() action) {
    if (_isDisposed || !mounted) return;

    _stopDwellTimer();

    final result = action();
    if (result != null && result >= 0) {
      _navigateToPage(result);
    } else {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Action executed!"),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _navigateToPage(int pageIndex) {
    if (_isDisposed || !mounted) return;

    // Clean up before navigation
    _stopDwellTimer();

    Widget nextPage;
    switch (pageIndex) {
      case 1:
        nextPage = const SettingsPage();
        break;
      case 2:
        nextPage = const ProfilePage();
        break;
      case 3:
        nextPage = const GamePage();
        break;
      default:
        nextPage = const RuangKelas();
    }

    if (mounted && !_isDisposed) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  PageData _getPageData() {
    return PageData(
      title: "Welcome to Ruang Kelas",
      subtitle: "Look at a button for 1.5 seconds to navigate",
      buttons: [
        SelectableButton(
          id: "go_to_settings",
          text: "Settings",
          icon: "settings",
          action: () => 1,
        ),
        SelectableButton(
          id: "go_to_profile",
          text: "Profile",
          icon: "person",
          action: () => 2,
        ),
        SelectableButton(
          id: "start_game",
          text: "Game Arena",
          icon: "gamepad",
          action: () => 3,
        ),
      ],
    );
  }

  // Method to update button bounds dynamically if needed
  void updateButtonBounds(String buttonId, Rect bounds) {
    if (!_isDisposed && mounted) {
      _buttonBounds[buttonId] = bounds;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageData = _getPageData();

    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade400, Colors.purple.shade600],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pageData.title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      pageData.subtitle,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    ...pageData.buttons
                        .map((button) => _buildSelectableButton(button)),
                  ],
                ),
              ),
            ),
          ),

          // Gaze point indicator - only show if tracking is active and stable
          if (_eyeTrackingService.isTracking &&
              _eyeTrackingService.isTrackingStable)
            Positioned(
              left: _eyeTrackingService.gazeX - 5,
              top: _eyeTrackingService.gazeY - 5,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green, // Green for SeeSo successful tracking
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),

          // Status information with SeeSo integration
          Positioned(
            top: 50,
            left: 20,
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
                    'SeeSo Eye Tracking',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Status: ${_eyeTrackingService.trackingStatusString}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Accuracy: ${(_eyeTrackingService.getGazeAccuracy() * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
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
                  if (_currentDwellingElement != null)
                    Text(
                      'Dwelling: ${(_dwellProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableButton(SelectableButton button) {
    final isCurrentlyDwelling = _currentDwellingElement == button.id;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        elevation: isCurrentlyDwelling ? 8 : 4,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: double.infinity,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: isCurrentlyDwelling
                  ? [Colors.orange.shade400, Colors.red.shade400]
                  : [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05)
                    ],
            ),
            border: Border.all(
              color: isCurrentlyDwelling
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              // Progress indicator for dwell time
              if (isCurrentlyDwelling)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    height: 4,
                    width: (MediaQuery.of(context).size.width - 40) *
                        _dwellProgress,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

              // Button content
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIconData(button.icon ?? ''),
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      button.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'settings':
        return Icons.settings;
      case 'person':
        return Icons.person;
      case 'gamepad':
        return Icons.games;
      default:
        return Icons.circle;
    }
  }
}
