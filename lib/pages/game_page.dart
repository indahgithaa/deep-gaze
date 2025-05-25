import 'package:deep_gaze/pages/ruang_kelas.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/page_data.dart';
import '../models/selectable_button.dart';
import '../services/global_seeso_service.dart'; // Gunakan service global
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import '../widgets/selectable_button_widget.dart';
import 'settings_page.dart';
import 'profile_page.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late GlobalSeesoService _eyeTrackingService;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration
  static const int _dwellTimeMs = 2000;
  static const int _dwellUpdateIntervalMs = 50;

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.addListener(_onEyeTrackingUpdate);
    _initializeEyeTracking();
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _eyeTrackingService.removeListener(_onEyeTrackingUpdate);
    // JANGAN dispose service global
    super.dispose();
  }

  void _onEyeTrackingUpdate() {
    setState(() {});
  }

  Future<void> _initializeEyeTracking() async {
    await _eyeTrackingService.initialize(context);
  }

  void _startDwellTimer(String elementId, VoidCallback action) {
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

  void _onElementSelected(VoidCallback action) {
    _stopDwellTimer();
    action();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Game action executed!"),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _navigateToPage(int pageIndex) {
    Widget nextPage;
    switch (pageIndex) {
      case 0:
        nextPage = const RuangKelas();
        break;
      case 1:
        nextPage = const SettingsPage();
        break;
      case 2:
        nextPage = const ProfilePage();
        break;
      default:
        nextPage = const RuangKelas();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero),
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
      title: "Game Arena",
      subtitle: "Ready to play?",
      buttons: [
        SelectableButton(
          id: "easy_mode",
          text: "Easy Mode",
          icon: "easy",
          action: () => -1,
        ),
        SelectableButton(
          id: "hard_mode",
          text: "Hard Mode",
          icon: "hard",
          action: () => -1,
        ),
        SelectableButton(
          id: "multiplayer_mode",
          text: "Multiplayer",
          icon: "gamepad",
          action: () => -1,
        ),
        SelectableButton(
          id: "back_to_menu",
          text: "Back to Menu",
          icon: "home",
          action: () => 0,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageData = _getPageData();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.indigo.shade400, Colors.purple.shade700],
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
          GazePointWidget(
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            isVisible: _eyeTrackingService.isTracking,
          ),
          StatusInfoWidget(
            statusMessage: _eyeTrackingService.statusMessage,
            currentPage: 4,
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
      onDwellStart: () => _startDwellTimer(button.id, button.action),
      onDwellStop: _stopDwellTimer,
    );
  }
}
