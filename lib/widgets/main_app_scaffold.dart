// File: lib/widgets/main_app_scaffold.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/global_seeso_service.dart';
import '../pages/ruang_kelas.dart';
import '../pages/lecture_recorder_page.dart';
import '../pages/profile_page.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';

class MainAppScaffold extends StatefulWidget {
  final int initialIndex;

  const MainAppScaffold({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends State<MainAppScaffold> {
  late int _currentIndex;
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell time selection state for navigation
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration
  static const int _dwellTimeMs = 1500;
  static const int _dwellUpdateIntervalMs = 50;

  // Navigation bar boundaries
  final Map<String, Rect> _navBounds = {};

  // CRITICAL: Track if this scaffold should handle navigation
  bool _shouldHandleNavigation = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _eyeTrackingService = GlobalSeesoService();

    // IMPORTANT: Only listen when this scaffold is the active page manager
    _setAsActiveNavigationHandler();

    _initializeEyeTracking();

    // Calculate navigation bounds after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateNavigationBounds();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();

    // CRITICAL: Remove this scaffold as the navigation handler
    _removeAsNavigationHandler();

    super.dispose();
  }

  void _setAsActiveNavigationHandler() {
    // Set this scaffold as the navigation handler
    _eyeTrackingService.setActivePage(
        'main_app_scaffold', _onEyeTrackingUpdate);
    _shouldHandleNavigation = true;
    print("DEBUG: MainAppScaffold set as active navigation handler");
  }

  void _removeAsNavigationHandler() {
    // Remove this scaffold as the navigation handler
    _eyeTrackingService.removePage('main_app_scaffold');
    _shouldHandleNavigation = false;
    print("DEBUG: MainAppScaffold removed as navigation handler");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we're returning from a sub-page
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && !_shouldHandleNavigation) {
      // We're back to being the current route, re-enable navigation handling
      print(
          "DEBUG: MainAppScaffold became current route, re-enabling navigation");
      _setAsActiveNavigationHandler();
      _calculateNavigationBounds(); // Recalculate bounds
    }
  }

  void _calculateNavigationBounds() {
    if (_isDisposed || !mounted || !_shouldHandleNavigation) return;

    final screenSize = MediaQuery.of(context).size;
    final navBarHeight = 80.0;
    final navBarTop = screenSize.height -
        navBarHeight -
        MediaQuery.of(context).padding.bottom;
    final itemWidth = screenSize.width / 3;

    // Home navigation item
    _navBounds['nav_home'] = Rect.fromLTWH(
      0,
      navBarTop,
      itemWidth,
      navBarHeight,
    );

    // Recorder navigation item
    _navBounds['nav_recorder'] = Rect.fromLTWH(
      itemWidth,
      navBarTop,
      itemWidth,
      navBarHeight,
    );

    // Profile navigation item
    _navBounds['nav_profile'] = Rect.fromLTWH(
      itemWidth * 2,
      navBarTop,
      itemWidth,
      navBarHeight,
    );

    print("DEBUG: MainAppScaffold navigation bounds calculated: $_navBounds");
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted || !_shouldHandleNavigation) return;
    if (!_eyeTrackingService.isTracking) return;

    // CRITICAL: Only handle navigation if we're the active navigation handler
    if (_eyeTrackingService.activePageId != 'main_app_scaffold') {
      print(
          "DEBUG: MainAppScaffold ignoring gaze - not active page (active: ${_eyeTrackingService.activePageId})");
      return;
    }

    final currentGazePoint = Offset(
      _eyeTrackingService.gazeX,
      _eyeTrackingService.gazeY,
    );

    String? hoveredElement;

    // Check navigation area gaze
    for (final entry in _navBounds.entries) {
      if (entry.value.contains(currentGazePoint)) {
        hoveredElement = entry.key;
        print("DEBUG: MainAppScaffold detected gaze on $hoveredElement");
        break;
      }
    }

    if (hoveredElement != null) {
      if (_currentDwellingElement != hoveredElement) {
        _handleNavigationHover(hoveredElement);
      }
    } else {
      if (_currentDwellingElement != null) {
        _stopDwellTimer();
      }
    }

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  void _handleNavigationHover(String elementId) {
    VoidCallback action;

    switch (elementId) {
      case 'nav_home':
        if (_currentIndex != 0) {
          action = () => _navigateToPage(0);
        } else {
          return; // Don't start dwell if already on the page
        }
        break;
      case 'nav_recorder':
        if (_currentIndex != 1) {
          action = () => _navigateToPage(1);
        } else {
          return;
        }
        break;
      case 'nav_profile':
        if (_currentIndex != 2) {
          action = () => _navigateToPage(2);
        } else {
          return;
        }
        break;
      default:
        return;
    }

    _startDwellTimer(elementId, action);
  }

  void _navigateToPage(int index) {
    if (_isDisposed || !mounted || _currentIndex == index) return;
    if (!_shouldHandleNavigation) return;

    _stopDwellTimer();
    setState(() {
      _currentIndex = index;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigated to ${_getPageName(index)}'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.blue,
      ),
    );

    print("DEBUG: MainAppScaffold navigated to page $index");
  }

  String _getPageName(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Recorder';
      case 2:
        return 'Profile';
      default:
        return 'Unknown';
    }
  }

  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;

    try {
      print("DEBUG: Initializing eye tracking in MainAppScaffold");
      await _eyeTrackingService.initialize(context);
      print("DEBUG: Eye tracking successfully initialized in MainAppScaffold");
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

  void _startDwellTimer(String elementId, VoidCallback action) {
    if (_isDisposed || !mounted || !_shouldHandleNavigation) return;
    if (_currentDwellingElement == elementId) return;

    _stopDwellTimer();

    if (mounted && !_isDisposed) {
      setState(() {
        _currentDwellingElement = elementId;
        _dwellProgress = 0.0;
      });
    }

    print("DEBUG: MainAppScaffold starting dwell timer for: $elementId");
    _dwellStartTime = DateTime.now();
    _dwellTimer = Timer.periodic(
      Duration(milliseconds: _dwellUpdateIntervalMs),
      (timer) {
        if (_isDisposed ||
            !mounted ||
            _currentDwellingElement != elementId ||
            !_shouldHandleNavigation) {
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
            action();
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

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return const RuangKelas();
      case 1:
        return const LectureRecorderPage();
      case 2:
        return const ProfilePage();
      default:
        return const RuangKelas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main page content
          _getCurrentPage(),

          // Only show gaze point and status if we're the active handler
          if (_shouldHandleNavigation &&
              _eyeTrackingService.activePageId == 'main_app_scaffold') ...[
            // Gaze point indicator
            GazePointWidget(
              gazeX: _eyeTrackingService.gazeX,
              gazeY: _eyeTrackingService.gazeY,
              isVisible: _eyeTrackingService.isTracking,
            ),

            // Status information
            // StatusInfoWidget(
            //   statusMessage: _eyeTrackingService.statusMessage,
            //   currentPage: _currentIndex + 1,
            //   totalPages: 3,
            //   gazeX: _eyeTrackingService.gazeX,
            //   gazeY: _eyeTrackingService.gazeY,
            //   currentDwellingElement: _currentDwellingElement,
            //   dwellProgress: _dwellProgress,
            // ),
          ],
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            _buildNavItem(0, Icons.home, 'Home', 'nav_home'),
            _buildNavItem(1, Icons.mic, 'Recorder', 'nav_recorder'),
            _buildNavItem(2, Icons.person, 'Profile', 'nav_profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, String label, String elementId) {
    final isActive = _currentIndex == index;
    final isCurrentlyDwelling =
        _currentDwellingElement == elementId && _shouldHandleNavigation;

    return Expanded(
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Material(
          elevation: isCurrentlyDwelling ? 4 : 0,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isActive
                  ? Colors.blue.shade50
                  : (isCurrentlyDwelling
                      ? Colors.grey.shade100
                      : Colors.transparent),
              border: isCurrentlyDwelling
                  ? Border.all(color: Colors.blue.shade300, width: 2)
                  : null,
            ),
            child: Stack(
              children: [
                // Dwell progress indicator
                if (isCurrentlyDwelling)
                  Positioned(
                    bottom: 4,
                    left: 8,
                    right: 8,
                    child: Container(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: _dwellProgress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade600,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                // Navigation item content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: isActive
                            ? Colors.blue.shade600
                            : (isCurrentlyDwelling
                                ? Colors.blue.shade400
                                : Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isActive
                              ? Colors.blue.shade600
                              : (isCurrentlyDwelling
                                  ? Colors.blue.shade400
                                  : Colors.grey.shade600),
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
}
