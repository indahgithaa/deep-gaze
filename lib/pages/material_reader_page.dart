// File: lib/pages/material_reader_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/subject.dart';
import '../models/topic.dart';
import '../services/global_seeso_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';

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

class _MaterialReaderPageState extends State<MaterialReaderPage> {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration
  static const int _navigationDwellTimeMs = 800; // 800ms for scroll navigation
  static const int _buttonDwellTimeMs = 1500; // 1.5s for buttons
  static const int _dwellUpdateIntervalMs = 50;

  // Button boundaries for automatic detection
  final Map<String, Rect> _buttonBounds = {};

  // Reading state
  final ScrollController _scrollController = ScrollController();
  bool _isDarkMode = false;
  double _fontSize = 16.0;
  bool _isAutoScrolling = false;

  // Auto-scroll configuration
  Timer? _autoScrollTimer;
  static const Duration _autoScrollSpeed = Duration(milliseconds: 50);
  static const double _scrollIncrement = 2.0;

  // Navigation zones - REDUCED SIZE
  final double _navigationZoneHeight = 60.0; // Reduced from 100 to 60

  @override
  void initState() {
    super.initState();
    print("DEBUG: MaterialReaderPage initState");
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.addListener(_onEyeTrackingUpdate);
    _initializeEyeTracking();

    // Initialize button bounds after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeButtonBounds();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _scrollController.dispose();
    if (_eyeTrackingService.hasListeners) {
      _eyeTrackingService.removeListener(_onEyeTrackingUpdate);
    }
    print("DEBUG: MaterialReaderPage disposed");
    super.dispose();
  }

  void _initializeButtonBounds() {
    if (!mounted) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Back button boundary
    _buttonBounds['back_button'] = const Rect.fromLTWH(20, 50, 50, 50);

    // Dark mode toggle boundary
    _buttonBounds['dark_mode_button'] =
        Rect.fromLTWH(screenWidth - 70, 50, 50, 50);

    // Font size controls
    _buttonBounds['font_increase'] =
        Rect.fromLTWH(screenWidth - 120, 110, 40, 40);
    _buttonBounds['font_decrease'] =
        Rect.fromLTWH(screenWidth - 70, 110, 40, 40);

    // Navigation zones - FIXED POSITIONING
    _buttonBounds['scroll_up_zone'] =
        Rect.fromLTWH(0, 120, screenWidth, _navigationZoneHeight);
    _buttonBounds['scroll_down_zone'] = Rect.fromLTWH(
        0,
        screenHeight - _navigationZoneHeight,
        screenWidth,
        _navigationZoneHeight);

    print(
        "DEBUG: Initialized ${_buttonBounds.length} button bounds for MaterialReader");
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    // Quick bounds check
    if (currentGazePoint.dx < 0 ||
        currentGazePoint.dy < 0 ||
        currentGazePoint.dx > MediaQuery.of(context).size.width ||
        currentGazePoint.dy > MediaQuery.of(context).size.height) {
      return;
    }

    String? hoveredElement;

    // Check which element is being gazed at
    for (final entry in _buttonBounds.entries) {
      if (entry.value.contains(currentGazePoint)) {
        hoveredElement = entry.key;
        break;
      }
    }

    // Only process if hover state changed
    if (hoveredElement != _currentDwellingElement) {
      if (hoveredElement != null) {
        _handleElementHover(hoveredElement);
      } else if (_currentDwellingElement != null) {
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
        break;
      case 'scroll_down_zone':
        action = () => _startAutoScroll(isUp: false);
        dwellTime = _navigationDwellTimeMs;
        break;
      default:
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
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _isAutoScrolling = false;
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

    if (_isAutoScrolling) return;

    setState(() {
      _isAutoScrolling = true;
    });

    // Show feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-scrolling ${isUp ? 'up' : 'down'}...'),
        duration: const Duration(seconds: 2),
        backgroundColor: isUp ? Colors.purple : Colors.teal,
      ),
    );

    // Start auto-scroll
    _autoScrollTimer = Timer.periodic(_autoScrollSpeed, (timer) {
      if (_isDisposed || !mounted || !_scrollController.hasClients) {
        timer.cancel();
        return;
      }

      final currentOffset = _scrollController.offset;
      final maxOffset = _scrollController.position.maxScrollExtent;

      double newOffset;
      if (isUp) {
        newOffset = (currentOffset - _scrollIncrement).clamp(0.0, maxOffset);
        if (newOffset <= 0) {
          timer.cancel();
          _isAutoScrolling = false;
        }
      } else {
        newOffset = (currentOffset + _scrollIncrement).clamp(0.0, maxOffset);
        if (newOffset >= maxOffset) {
          timer.cancel();
          _isAutoScrolling = false;
        }
      }

      _scrollController.jumpTo(newOffset);
    });

    // Auto-stop after 3 seconds
    Timer(const Duration(seconds: 3), () {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      if (mounted) {
        setState(() {
          _isAutoScrolling = false;
        });
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

    return Container(
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
    // Sample material content - replace with actual content from your data source
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

          // Chapter 3
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

          const SizedBox(height: 50), // Extra space at the bottom
        ],
      ),
    );
  }

  String _getSampleContent() {
    return '''Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit.

At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident.

Similique sunt in culpa qui officia deserunt mollitia animi, id est laborum et dolorum fuga. Et harum quidem rerum facilis est et expedita distinctio nam libero tempore.''';
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
                height: 120,
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

              // Scroll up zone - TRANSPARENT OVERLAY
              Container(
                height: _navigationZoneHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (_currentDwellingElement == 'scroll_up_zone'
                          ? Colors.purple.withOpacity(0.3)
                          : Colors.purple.withOpacity(0.1)),
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
                            ? Colors.purple
                            : Colors.purple.withOpacity(0.5),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Look here to scroll up',
                        style: TextStyle(
                          color: _currentDwellingElement == 'scroll_up_zone'
                              ? Colors.purple
                              : Colors.purple.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // SCROLLABLE CONTENT AREA - FIXED
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

              // Scroll down zone - TRANSPARENT OVERLAY
              Container(
                height: _navigationZoneHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      (_currentDwellingElement == 'scroll_down_zone'
                          ? Colors.teal.withOpacity(0.3)
                          : Colors.teal.withOpacity(0.1)),
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
                            ? Colors.teal
                            : Colors.teal.withOpacity(0.5),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Look here to scroll down',
                        style: TextStyle(
                          color: _currentDwellingElement == 'scroll_down_zone'
                              ? Colors.teal
                              : Colors.teal.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
              top: MediaQuery.of(context).size.height / 2 - 50,
              left: MediaQuery.of(context).size.width / 2 - 50,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'Scrolling...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
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
