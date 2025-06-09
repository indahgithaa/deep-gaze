// File: lib/widgets/main_navigation_widget.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/global_seeso_service.dart';

class MainNavigationWidget extends StatefulWidget {
  final int currentIndex;
  final Function(int) onNavigate;
  final String? currentDwellingElement;
  final double dwellProgress;

  const MainNavigationWidget({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.currentDwellingElement,
    this.dwellProgress = 0.0,
  });

  @override
  State<MainNavigationWidget> createState() => _MainNavigationWidgetState();
}

class _MainNavigationWidgetState extends State<MainNavigationWidget> {
  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      id: 'home',
      icon: Icons.home,
      label: 'Home',
      index: 0,
    ),
    NavigationItem(
      id: 'recorder',
      icon: Icons.mic,
      label: 'Recorder',
      index: 1,
    ),
    NavigationItem(
      id: 'profile',
      icon: Icons.person,
      label: 'Profile',
      index: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navigationItems.map((item) {
              return _buildNavigationItem(item);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem(NavigationItem item) {
    final isActive = widget.currentIndex == item.index;
    final isCurrentlyDwelling =
        widget.currentDwellingElement == 'nav_${item.id}';

    return Expanded(
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
                        value: widget.dwellProgress,
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
                        item.icon,
                        size: 24,
                        color: isActive
                            ? Colors.blue.shade600
                            : (isCurrentlyDwelling
                                ? Colors.blue.shade400
                                : Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
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

class NavigationItem {
  final String id;
  final IconData icon;
  final String label;
  final int index;

  NavigationItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.index,
  });
}

// Main wrapper widget that handles navigation logic
class MainNavigationWrapper extends StatefulWidget {
  final Widget child;
  final int currentIndex;

  const MainNavigationWrapper({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration
  static const int _dwellTimeMs = 800;
  static const int _dwellUpdateIntervalMs = 50;

  // Button boundaries for navigation
  final Map<String, Rect> _buttonBounds = {};

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.addListener(_onEyeTrackingUpdate);

    // Calculate bounds after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateNavigationBounds();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    if (_eyeTrackingService.hasListeners) {
      _eyeTrackingService.removeListener(_onEyeTrackingUpdate);
    }
    super.dispose();
  }

  void _calculateNavigationBounds() {
    if (_isDisposed || !mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Navigation bar is at bottom, 80px high
    final navBarTop = screenHeight - 80;
    final itemWidth = (screenWidth - 40) / 3; // 3 items, 20px padding each side

    // Calculate bounds for each navigation item
    _buttonBounds['nav_home'] = Rect.fromLTWH(20, navBarTop + 8, itemWidth, 64);

    _buttonBounds['nav_recorder'] =
        Rect.fromLTWH(20 + itemWidth, navBarTop + 8, itemWidth, 64);

    _buttonBounds['nav_profile'] =
        Rect.fromLTWH(20 + (itemWidth * 2), navBarTop + 8, itemWidth, 64);
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);
    String? hoveredElement;

    // Check which navigation element is being gazed at
    for (final entry in _buttonBounds.entries) {
      if (entry.value.contains(currentGazePoint)) {
        hoveredElement = entry.key;
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
        action = () => _navigateToPage(0);
        break;
      case 'nav_recorder':
        action = () => _navigateToPage(1);
        break;
      case 'nav_profile':
        action = () => _navigateToPage(2);
        break;
      default:
        return;
    }

    _startDwellTimer(elementId, action);
  }

  void _navigateToPage(int index) {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    // Don't navigate if already on the same page
    if (widget.currentIndex == index) return;

    switch (index) {
      case 0: // Home
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        break;
      case 1: // Recorder
        Navigator.of(context).pushNamed('/recorder');
        break;
      case 2: // Profile
        Navigator.of(context).pushNamed('/profile');
        break;
    }
  }

  void _startDwellTimer(String elementId, VoidCallback action) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: MainNavigationWidget(
        currentIndex: widget.currentIndex,
        onNavigate: _navigateToPage,
        currentDwellingElement: _currentDwellingElement,
        dwellProgress: _dwellProgress,
      ),
    );
  }
}
