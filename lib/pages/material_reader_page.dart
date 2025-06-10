// File: lib/pages/material_reader_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/subject.dart';
import '../models/topic.dart';
import '../services/global_seeso_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import '../mixins/responsive_bounds_mixin.dart';

class MaterialReaderPage extends StatefulWidget {
  final Subject subject;
  final Topic topic;

  const MaterialReaderPage({
    super.key,
    required this.subject,
    required this.topic,
  });

  @override
  State<MaterialReaderPage> createState() => _MaterialReaderPageState();
}

class _MaterialReaderPageState extends State<MaterialReaderPage>
    with ResponsiveBoundsMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration
  static const int _navigationDwellTimeMs = 800;
  static const int _buttonDwellTimeMs = 1500;
  static const int _dwellUpdateIntervalMs = 50;

  // Reading state
  final ScrollController _scrollController = ScrollController();
  bool _isDarkMode = false;
  double _fontSize = 16.0;
  bool _isAutoScrolling = false;

  // Auto-scroll configuration
  Timer? _autoScrollTimer;
  static const Duration _autoScrollSpeed = Duration(milliseconds: 50);

  // FIXED: Proper navigation zone configuration
  final double _navigationZoneHeight =
      60.0; // Reduced height for better precision
  final double _headerHeight = 120.0; // Header height

  // Override mixin configuration
  @override
  double get boundsUpdateDelay =>
      150.0; // Slightly longer delay for complex layout

  @override
  bool get enableBoundsLogging => true; // Enable detailed logging

  @override
  void initState() {
    super.initState();
    print("DEBUG: MaterialReaderPage initState");
    _eyeTrackingService = GlobalSeesoService();

    // CRITICAL FIX: Use the new page focus system
    _eyeTrackingService.setActivePage('material_reader', _onEyeTrackingUpdate);

    _initializeEyeTracking();

    // Generate GlobalKeys for all interactive elements using the mixin
    _initializeElementKeys();

    // Calculate button bounds after the first frame using the mixin
    updateBoundsAfterBuild();
  }

  void _initializeElementKeys() {
    // Generate keys for all interactive elements using the mixin
    generateKeyForElement('scroll_up_zone');
    generateKeyForElement('scroll_down_zone');
    generateKeyForElement('back_button');
    generateKeyForElement('dark_mode_button');
    generateKeyForElement('font_increase');
    generateKeyForElement('font_decrease');

    print("DEBUG: Generated ${elementCount} element keys using mixin");
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _scrollController.dispose();

    // CRITICAL FIX: Remove this page from the focus system
    _eyeTrackingService.removePage('material_reader');

    // Clean up mixin resources
    clearBounds();

    print("DEBUG: MaterialReaderPage disposed");
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recalculate bounds when dependencies change (like screen rotation)
    updateBoundsAfterBuild();
  }

  void _stopAutoScrollIfNotInZone(String? hoveredElement) {
    // Stop auto-scroll if user looks away from scroll zones
    if (_isAutoScrolling &&
        (hoveredElement == null || !hoveredElement.contains('scroll'))) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      _isAutoScrolling = false;
      print("DEBUG: Auto-scroll stopped - gaze left scroll zones");

      if (mounted) {
        setState(() {
          _isAutoScrolling = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-scroll stopped'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    // Bounds validation using mixin helper
    final screenSize = MediaQuery.of(context).size;
    if (currentGazePoint.dx < 0 ||
        currentGazePoint.dy < 0 ||
        currentGazePoint.dx > screenSize.width ||
        currentGazePoint.dy > screenSize.height) {
      // IMPROVED: Stop auto-scroll when gaze goes off-screen
      _stopAutoScrollIfNotInZone(null);
      return;
    }

    // IMPROVED: Use mixin's precise hit detection
    String? hoveredElement = getElementAtPoint(currentGazePoint);

    // IMPROVED: Check if we should stop auto-scrolling
    _stopAutoScrollIfNotInZone(hoveredElement);

    // Debug logging for navigation zones
    if (hoveredElement != null && hoveredElement.contains('scroll')) {
      print(
          "DEBUG: Gaze detected on $hoveredElement at (${currentGazePoint.dx.toInt()}, ${currentGazePoint.dy.toInt()})");
      final bounds = getBoundsForElement(hoveredElement);
      print("DEBUG: Zone bounds: $bounds");
    }

    // Only process if hover state changed
    if (hoveredElement != _currentDwellingElement) {
      if (hoveredElement != null) {
        print("DEBUG: Started dwelling on: $hoveredElement");
        _handleElementHover(hoveredElement);
      } else if (_currentDwellingElement != null) {
        print("DEBUG: Stopped dwelling on: $_currentDwellingElement");
        _stopDwellTimer();
      }
    }

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  void _handleElementHover(String elementId) {
    VoidCallback action;
    int dwellTime = _buttonDwellTimeMs;

    switch (elementId) {
      case 'back_button':
        action = _goBack;
        break;
      case 'dark_mode_button':
        action = _toggleDarkMode;
        break;
      case 'font_increase':
        action = _increaseFontSize;
        break;
      case 'font_decrease':
        action = _decreaseFontSize;
        break;
      case 'scroll_up_zone':
        action = () => _startAutoScroll(isUp: true);
        dwellTime = _navigationDwellTimeMs;
        print("DEBUG: Scroll up action assigned");
        break;
      case 'scroll_down_zone':
        action = () => _startAutoScroll(isUp: false);
        dwellTime = _navigationDwellTimeMs;
        print("DEBUG: Scroll down action assigned");
        break;
      default:
        print("DEBUG: Unknown element: $elementId");
        return;
    }

    _startDwellTimer(elementId, action, dwellTime);
  }

  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;

    try {
      print("DEBUG: Initializing eye tracking in MaterialReaderPage");
      await _eyeTrackingService.initialize(context);
      print(
          "DEBUG: Eye tracking successfully initialized in MaterialReaderPage");
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

  void _startDwellTimer(
      String elementId, VoidCallback action, int dwellTimeMs) {
    if (_isDisposed || !mounted) return;
    if (_currentDwellingElement == elementId) return;

    _stopDwellTimer();

    if (mounted && !_isDisposed) {
      setState(() {
        _currentDwellingElement = elementId;
        _dwellProgress = 0.0;
      });
    }

    print("DEBUG: Starting dwell timer for: $elementId (${dwellTimeMs}ms)");
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
        final progress = (elapsed / dwellTimeMs).clamp(0.0, 1.0);

        if (mounted && !_isDisposed) {
          setState(() {
            _dwellProgress = progress;
          });
        }

        if (progress >= 1.0) {
          timer.cancel();
          print(
              "DEBUG: Dwell timer completed for: $elementId, executing action");
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

    // IMPROVED: Only stop auto-scroll if user looks away from scroll zones
    if (_isAutoScrolling &&
        _currentDwellingElement != null &&
        !_currentDwellingElement!.contains('scroll')) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      _isAutoScrolling = false;
      print("DEBUG: Auto-scroll stopped - user looked away from scroll zones");

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-scroll stopped'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }

    if (mounted && !_isDisposed) {
      setState(() {
        _currentDwellingElement = null;
        _dwellProgress = 0.0;
      });
    }
  }

  void _goBack() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    Navigator.of(context).pop();
  }

  void _toggleDarkMode() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_isDarkMode ? 'Dark' : 'Light'} mode enabled'),
        duration: const Duration(seconds: 1),
        backgroundColor: _isDarkMode ? Colors.grey.shade800 : Colors.blue,
      ),
    );
  }

  void _increaseFontSize() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    setState(() {
      _fontSize = (_fontSize + 2.0).clamp(12.0, 24.0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Font size increased: ${_fontSize.toInt()}px'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _decreaseFontSize() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    setState(() {
      _fontSize = (_fontSize - 2.0).clamp(12.0, 24.0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Font size decreased: ${_fontSize.toInt()}px'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _startAutoScroll({required bool isUp}) {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    if (_isAutoScrolling) {
      print("DEBUG: Already auto-scrolling, ignoring");
      return;
    }

    // Check if scrolling is possible
    if (!_scrollController.hasClients) {
      print("DEBUG: ScrollController has no clients");
      return;
    }

    final currentOffset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;

    if (isUp && currentOffset <= 0) {
      print("DEBUG: Already at top, cannot scroll up");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already at the top'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!isUp && currentOffset >= maxOffset) {
      print("DEBUG: Already at bottom, cannot scroll down");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already at the bottom'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAutoScrolling = true;
    });

    print("DEBUG: Starting smooth auto-scroll ${isUp ? 'UP' : 'DOWN'}");

    // Show feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-scrolling ${isUp ? 'up' : 'down'}...'),
        duration: const Duration(seconds: 4),
        backgroundColor: isUp ? Colors.purple : Colors.teal,
      ),
    );

    // IMPROVED: Smooth scrolling implementation with smaller increments
    const scrollIncrement = 3.0; // Much smaller increment for smoothness
    const frameDuration = Duration(milliseconds: 16); // ~60 FPS

    _autoScrollTimer = Timer.periodic(frameDuration, (timer) {
      if (_isDisposed || !mounted || !_scrollController.hasClients) {
        timer.cancel();
        _isAutoScrolling = false;
        print("DEBUG: Auto-scroll stopped - disposed or no clients");
        return;
      }

      final currentOffset = _scrollController.offset;
      final maxOffset = _scrollController.position.maxScrollExtent;

      // Calculate new offset with smooth increment
      final scrollAmount = isUp ? -scrollIncrement : scrollIncrement;
      double newOffset = currentOffset + scrollAmount;

      // Check boundaries and stop if reached
      if (isUp && newOffset <= 0) {
        newOffset = 0;
        timer.cancel();
        _isAutoScrolling = false;
        print("DEBUG: Reached top of content");
        if (mounted) {
          setState(() {
            _isAutoScrolling = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reached the top'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.purple,
            ),
          );
        }
      } else if (!isUp && newOffset >= maxOffset) {
        newOffset = maxOffset;
        timer.cancel();
        _isAutoScrolling = false;
        print("DEBUG: Reached bottom of content");
        if (mounted) {
          setState(() {
            _isAutoScrolling = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reached the bottom'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.teal,
            ),
          );
        }
      }

      // Perform smooth scroll without animation to avoid conflicts
      try {
        _scrollController.jumpTo(newOffset);
      } catch (e) {
        print("DEBUG: Error during scroll: $e");
        timer.cancel();
        _isAutoScrolling = false;
        if (mounted) {
          setState(() {
            _isAutoScrolling = false;
          });
        }
      }
    });

    // Auto-stop after 8 seconds to prevent infinite scrolling
    Timer(const Duration(seconds: 8), () {
      if (_autoScrollTimer?.isActive == true) {
        _autoScrollTimer?.cancel();
        _autoScrollTimer = null;
        if (mounted) {
          setState(() {
            _isAutoScrolling = false;
          });
          print("DEBUG: Auto-scroll timeout reached");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auto-scroll stopped'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.grey,
            ),
          );
        }
      }
    });
  }

  Widget _buildNavigationControls() {
    return Positioned(
      top: 50,
      right: 20,
      child: Column(
        children: [
          // Dark mode toggle
          _buildControlButton(
            'dark_mode_button',
            _isDarkMode ? Icons.light_mode : Icons.dark_mode,
            _isDarkMode ? Colors.yellow : Colors.indigo,
            'Toggle ${_isDarkMode ? 'Light' : 'Dark'} Mode',
          ),
          const SizedBox(height: 10),
          // Font size controls
          _buildControlButton(
            'font_increase',
            Icons.add,
            Colors.green,
            'Increase Font',
          ),
          const SizedBox(height: 5),
          _buildControlButton(
            'font_decrease',
            Icons.remove,
            Colors.orange,
            'Decrease Font',
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      String elementId, IconData icon, Color color, String tooltip) {
    final isCurrentlyDwelling = _currentDwellingElement == elementId;
    final key = generateKeyForElement(elementId); // Use mixin to get/create key

    return Container(
      key: key, // Assign the GlobalKey here
      width: 50,
      height: 50,
      child: Material(
        elevation: isCurrentlyDwelling ? 8 : 4,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: isCurrentlyDwelling
                ? color.withOpacity(0.8)
                : color.withOpacity(0.1),
            border: Border.all(
              color: isCurrentlyDwelling ? color : color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              if (isCurrentlyDwelling)
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: _dwellProgress,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              Center(
                child: Icon(
                  icon,
                  color: isCurrentlyDwelling ? Colors.white : color,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.topic.name,
            style: TextStyle(
              fontSize: _fontSize + 8,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          // Chapter 1
          Text(
            'Chapter 1: Introduction',
            style: TextStyle(
              fontSize: _fontSize + 4,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getSampleContent(),
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.6,
              color: _isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          // Chapter 2
          Text(
            'Chapter 2: Key Concepts',
            style: TextStyle(
              fontSize: _fontSize + 4,
              fontWeight: FontWeight.w600,
              color:
                  _isDarkMode ? Colors.green.shade300 : Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getSampleContent(),
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.6,
              color: _isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          // Important Notes Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.yellow.shade900.withOpacity(0.3)
                  : Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.yellow.shade600
                    : Colors.yellow.shade600,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: _isDarkMode
                          ? Colors.yellow.shade300
                          : Colors.yellow.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Important Notes',
                      style: TextStyle(
                        fontSize: _fontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode
                            ? Colors.yellow.shade300
                            : Colors.yellow.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Remember these key points when studying this material. Practice regularly and don\'t hesitate to ask questions if you need clarification.',
                  style: TextStyle(
                    fontSize: _fontSize,
                    color: _isDarkMode
                        ? Colors.yellow.shade200
                        : Colors.yellow.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // More chapters...
          Text(
            'Chapter 3: Examples and Practice',
            style: TextStyle(
              fontSize: _fontSize + 4,
              fontWeight: FontWeight.w600,
              color:
                  _isDarkMode ? Colors.purple.shade300 : Colors.purple.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getSampleContent(),
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.6,
              color: _isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chapter 4: Advanced Topics',
            style: TextStyle(
              fontSize: _fontSize + 4,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? Colors.red.shade300 : Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getSampleContent(),
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.6,
              color: _isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chapter 5: Conclusion',
            style: TextStyle(
              fontSize: _fontSize + 4,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? Colors.cyan.shade300 : Colors.cyan.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getSampleContent(),
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.6,
              color: _isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 100), // Extra space for scroll testing
        ],
      ),
    );
  }

  String _getSampleContent() {
    return '''Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit.''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.grey.shade900 : Colors.white,
      body: Stack(
        children: [
          // Main content with proper layout
          Column(
            children: [
              // Header
              Container(
                height: _headerHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(int.parse(
                          '0xFF${widget.subject.colors[0].substring(1)}')),
                      Color(int.parse(
                          '0xFF${widget.subject.colors[1].substring(1)}')),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _goBack,
                          child: Container(
                            key: generateKeyForElement(
                                'back_button'), // Use mixin
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Material Reader',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.visibility,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // FIXED: Scroll up zone with precise bounds using mixin
              Container(
                key: generateKeyForElement('scroll_up_zone'), // Use mixin
                height: _navigationZoneHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (_currentDwellingElement == 'scroll_up_zone'
                          ? Colors.purple.withOpacity(0.5)
                          : Colors.purple.withOpacity(0.2)),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: _currentDwellingElement == 'scroll_up_zone'
                            ? Colors.purple.shade700
                            : Colors.purple.withOpacity(0.7),
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Look here to scroll up',
                        style: TextStyle(
                          color: _currentDwellingElement == 'scroll_up_zone'
                              ? Colors.purple.shade700
                              : Colors.purple.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_currentDwellingElement == 'scroll_up_zone')
                        Container(
                          margin: const EdgeInsets.only(left: 12),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: _dwellProgress,
                            strokeWidth: 2,
                            backgroundColor: Colors.purple.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.purple.shade700),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // SCROLLABLE CONTENT AREA
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: _isDarkMode ? Colors.grey.shade900 : Colors.white,
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: _buildMaterialContent(),
                    ),
                  ),
                ),
              ),

              // FIXED: Scroll down zone with precise bounds and proper positioning using mixin
              Container(
                key: generateKeyForElement('scroll_down_zone'), // Use mixin
                height: _navigationZoneHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      (_currentDwellingElement == 'scroll_down_zone'
                          ? Colors.teal.withOpacity(0.5)
                          : Colors.teal.withOpacity(0.2)),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: _currentDwellingElement == 'scroll_down_zone'
                            ? Colors.teal.shade700
                            : Colors.teal.withOpacity(0.7),
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Look here to scroll down',
                        style: TextStyle(
                          color: _currentDwellingElement == 'scroll_down_zone'
                              ? Colors.teal.shade700
                              : Colors.teal.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_currentDwellingElement == 'scroll_down_zone')
                        Container(
                          margin: const EdgeInsets.only(left: 12),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: _dwellProgress,
                            strokeWidth: 2,
                            backgroundColor: Colors.teal.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.teal.shade700),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Control buttons - FLOATING OVERLAY
          _buildNavigationControls(),

          // Gaze point indicator
          GazePointWidget(
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            isVisible: _eyeTrackingService.isTracking,
          ),

          // Status information
          StatusInfoWidget(
            statusMessage: _eyeTrackingService.statusMessage,
            currentPage: 5,
            totalPages: 5,
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            currentDwellingElement: _currentDwellingElement,
            dwellProgress: _dwellProgress,
          ),

          // Auto-scroll indicator
          if (_isAutoScrolling)
            Positioned(
              top: MediaQuery.of(context).size.height / 2 - 60,
              left: MediaQuery.of(context).size.width / 2 - 60,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Auto-scrolling...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Look away to stop',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
