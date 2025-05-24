import 'package:flutter/material.dart';
import 'dart:async';
import '../models/page_data.dart';
import '../models/selectable_button.dart';
import '../services/eye_tracking_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import '../widgets/selectable_button_widget.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'game_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late EyeTrackingService _eyeTrackingService;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration - changed to 1.5 seconds
  static const int _dwellTimeMs = 1500; // 1.5 seconds
  static const int _dwellUpdateIntervalMs = 50; // Update every 50ms

  // Button boundaries for automatic detection
  final Map<String, Rect> _buttonBounds = {};

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = EyeTrackingService();
    _eyeTrackingService.addListener(_onEyeTrackingUpdate);
    _initializeEyeTracking();
    _initializeButtonBounds();
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _eyeTrackingService.removeListener(_onEyeTrackingUpdate);
    _eyeTrackingService.dispose();
    super.dispose();
  }

  void _initializeButtonBounds() {
    // Define button boundaries for automatic detection
    // You may need to adjust these coordinates based on your actual button positions
    _buttonBounds['go_to_settings'] = const Rect.fromLTWH(50, 380, 300, 70);
    _buttonBounds['go_to_profile'] = const Rect.fromLTWH(50, 470, 300, 70);
    _buttonBounds['start_game'] = const Rect.fromLTWH(50, 560, 300, 70);
  }

  void _onEyeTrackingUpdate() {
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

    setState(() {});
  }

  Future<void> _initializeEyeTracking() async {
    await _eyeTrackingService.initialize(context);
  }

  void _startDwellTimer(String elementId, int? Function() action) {
    if (_currentDwellingElement == elementId) return;

    _stopDwellTimer();

    setState(() {
      _currentDwellingElement = elementId;
      _dwellProgress = 0.0;
    });

    _dwellStartTime = DateTime.now();

    _dwellTimer = Timer.periodic(
      Duration(milliseconds: _dwellUpdateIntervalMs),
      (timer) {
        if (_currentDwellingElement != elementId) {
          timer.cancel();
          return;
        }

        final elapsed =
            DateTime.now().difference(_dwellStartTime!).inMilliseconds;
        final progress = (elapsed / _dwellTimeMs).clamp(0.0, 1.0);

        setState(() {
          _dwellProgress = progress;
        });

        if (progress >= 1.0) {
          timer.cancel();
          _onElementSelected(action);
        }
      },
    );
  }

  void _stopDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    setState(() {
      _currentDwellingElement = null;
      _dwellProgress = 0.0;
    });
  }

  void _onElementSelected(int? Function() action) {
    _stopDwellTimer();

    final result = action();
    if (result != null && result >= 0) {
      _navigateToPage(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Action executed!"),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _navigateToPage(int pageIndex) {
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
        nextPage = const HomePage();
    }

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

  PageData _getPageData() {
    return PageData(
      title: "Welcome to Eye Tracking",
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
    _buttonBounds[buttonId] = bounds;
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

          // Gaze point indicator
          GazePointWidget(
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            isVisible: _eyeTrackingService.isTracking,
          ),

          // Status information
          StatusInfoWidget(
            statusMessage: _eyeTrackingService.statusMessage,
            currentPage: 1,
            totalPages: 4,
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            currentDwellingElement: _currentDwellingElement,
            dwellProgress: _dwellProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableButton(SelectableButton button) {
    final isCurrentlyDwelling = _currentDwellingElement == button.id;

    return SelectableButtonWidget(
      button: button,
      isCurrentlyDwelling: isCurrentlyDwelling,
      dwellProgress: _dwellProgress,
      onDwellStart: () =>
          _startDwellTimer(button.id, button.action as int? Function()),
      onDwellStop: _stopDwellTimer,
    );
  }
}
