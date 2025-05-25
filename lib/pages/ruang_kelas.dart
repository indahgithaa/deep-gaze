// File: lib/pages/ruang_kelas.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/page_data.dart';
import '../models/selectable_button.dart';
import '../services/global_seeso_service.dart'; // Import service global
import '../widgets/gaze_point_widget.dart'; // Gunakan widget yang sudah ada
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
  // Gunakan service global yang sama
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration - 1.5 seconds untuk button
  static const int _dwellTimeMs = 1500; // 1.5 detik
  static const int _dwellUpdateIntervalMs = 50; // Update setiap 50ms

  // Button boundaries untuk deteksi otomatis
  final Map<String, Rect> _buttonBounds = {};

  @override
  void initState() {
    super.initState();

    print("DEBUG: RuangKelas initState - mengambil service global");

    // Ambil service global yang sudah diinisialisasi
    _eyeTrackingService = GlobalSeesoService();

    // Add listener untuk update gaze
    _eyeTrackingService.addListener(_onEyeTrackingUpdate);

    // Print status service
    _eyeTrackingService.debugPrintStatus();

    // Initialize eye tracking (akan menggunakan instance yang sudah ada)
    _initializeEyeTracking();

    // Initialize button bounds
    _initializeButtonBounds();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _dwellTimer = null;

    // Remove listener tapi JANGAN dispose service global
    if (_eyeTrackingService.hasListeners) {
      _eyeTrackingService.removeListener(_onEyeTrackingUpdate);
    }

    print("DEBUG: RuangKelas disposed, service tetap hidup");
    super.dispose();
  }

  void _initializeButtonBounds() {
    // Definisikan boundaries button untuk deteksi otomatis
    // Koordinat ini sesuai dengan posisi button di UI
    _buttonBounds['go_to_settings'] = const Rect.fromLTWH(50, 380, 300, 70);
    _buttonBounds['go_to_profile'] = const Rect.fromLTWH(50, 470, 300, 70);
    _buttonBounds['start_game'] = const Rect.fromLTWH(50, 560, 300, 70);
  }

  void _onEyeTrackingUpdate() {
    // Check kalau widget sudah disposed
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);
    String? hoveredButton;

    // Check button mana yang sedang di-hover oleh gaze
    for (final entry in _buttonBounds.entries) {
      if (entry.value.contains(currentGazePoint)) {
        hoveredButton = entry.key;
        break;
      }
    }

    if (hoveredButton != null) {
      // Gaze berada di dalam button boundary
      if (_currentDwellingElement != hoveredButton) {
        // Start dwell timer untuk button baru
        final pageData = _getPageData();
        final button =
            pageData.buttons.firstWhere((b) => b.id == hoveredButton);
        _startDwellTimer(hoveredButton, button.action as int Function());
      }
      // Jika button yang sama, timer terus berjalan
    } else {
      // Gaze tidak berada di button manapun, stop interaksi
      if (_currentDwellingElement != null) {
        // Cancel dwell timer saat ini
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
      print("DEBUG: Initializing eye tracking di RuangKelas");

      // Service sudah diinisialisasi di halaman kalibrasi
      // Hanya perlu memastikan tracking aktif
      await _eyeTrackingService.initialize(context);

      print("DEBUG: Eye tracking berhasil diinisialisasi di RuangKelas");
      _eyeTrackingService.debugPrintStatus();
    } catch (e) {
      print('Eye tracking initialization failed: $e');
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

  void _startDwellTimer(String elementId, int Function() action) {
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
        // Check kalau widget disposed atau unmounted
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

  void _onElementSelected(int Function() action) {
    if (_isDisposed || !mounted) return;

    _stopDwellTimer();
    final result = action();

    if (result >= 0) {
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

    // Clean up sebelum navigasi
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
                Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero),
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

  // Method untuk update button bounds secara dinamis jika diperlukan
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
                        .map((button) => _buildGazeSelectableButton(button)),
                  ],
                ),
              ),
            ),
          ),

          // PENTING: Gaze point indicator menggunakan widget yang sudah ada
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

  Widget _buildGazeSelectableButton(SelectableButton button) {
    final isCurrentlyDwelling = _currentDwellingElement == button.id;

    return GestureDetector(
      onTap: () {
        if (isCurrentlyDwelling) {
          // Jalankan aksi hanya jika sedang di-dwell
          final pageData = _getPageData();
          final buttonAction = pageData.buttons
              .firstWhere((b) => b.id == button.id)
              .action as int Function();
          _onElementSelected(buttonAction);
        }
      },
      child: Container(
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
                // Progress indicator untuk dwell time
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
