// File: lib/pages/material_reader_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/subject.dart';
import '../models/topic.dart';
import '../services/global_seeso_service.dart';
import '../mixins/responsive_bounds_mixin.dart';
import '../widgets/gaze_overlay_manager.dart';

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

  // ===== Dwell state =====
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // ===== Dwell config =====
  static const int _navZoneDwellMs = 800; // scroll zones
  static const int _buttonDwellMs = 1500; // common buttons
  static const int _backDwellMs = 1000; // back button
  static const int _dwellUpdateIntervalMs = 50;

  // ===== Anti-jitter back button =====
  static const int _hoverGraceMs = 120;
  static const double _backInflatePx = 12.0;
  Timer? _hoverGraceTimer;

  // ===== Reading state =====
  final ScrollController _scrollController = ScrollController();
  bool _isDarkMode = false;
  double _fontSize = 16.0;

  // Auto-scroll
  bool _isAutoScrolling = false;
  Timer? _autoScrollTimer;

  // Layout constants
  final double _navigationZoneHeight = 60.0;
  final double _headerHeight = 120.0;

  // Bounds ready flag
  bool _boundsReady = false;

  // ResponsiveBoundsMixin config
  @override
  double get boundsUpdateDelay => 150.0;
  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.setActivePage('material_reader', _onEyeTrackingUpdate);

    _registerAllKeys();

    // Attach HUD overlay + seed state (insert is post-frame safe inside manager)
    GazeOverlayManager.instance.attach(context);
    GazeOverlayManager.instance.update(
      cursor: const Offset(-10000, -10000),
      visible: false,
      highlight: null,
      progress: null,
    );

    _initializeEyeTracking();

    // First bounds calc after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      updateBoundsAfterBuild();
      _boundsReady = true;
    });
  }

  void _registerAllKeys() {
    // Zones + buttons
    generateKeyForElement('scroll_up_zone');
    generateKeyForElement('scroll_down_zone');
    generateKeyForElement('back_button');
    generateKeyForElement('dark_mode_button');
    generateKeyForElement('font_increase');
    generateKeyForElement('font_decrease');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hoverGraceTimer?.cancel();
    _dwellTimer?.cancel();
    _autoScrollTimer?.cancel();
    _scrollController.dispose();

    _eyeTrackingService.removePage('material_reader');
    clearBounds();
    GazeOverlayManager.instance.hide();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateBoundsAfterBuild();
  }

  Future<void> _initializeEyeTracking() async {
    if (_isDisposed) return;
    try {
      await _eyeTrackingService.initialize(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Eye tracking initialization failed: $e"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ================== Eye Tracking ==================
  void _onEyeTrackingUpdate() {
    if (!mounted || _isDisposed || !_boundsReady) return;

    final gaze = Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    // Update HUD
    GazeOverlayManager.instance.update(
      cursor: gaze,
      visible: _eyeTrackingService.isTracking,
      progress: _currentDwellingElement != null ? _dwellProgress : null,
    );

    // Hit-test via mixin
    String? hovered = getElementAtPoint(gaze);

    // Sticky back button area
    final backRect = getBoundsForElement('back_button');
    if (backRect != null && backRect.inflate(_backInflatePx).contains(gaze)) {
      hovered = 'back_button';
    }

    // Stop auto-scroll if gaze left zones
    if (_isAutoScrolling &&
        (hovered == null ||
            !(hovered == 'scroll_up_zone' || hovered == 'scroll_down_zone'))) {
      _stopAutoScroll();
    }

    if (hovered != null) {
      _hoverGraceTimer?.cancel();
      if (_currentDwellingElement != hovered) {
        _handleHover(hovered);
      }
    } else if (_currentDwellingElement != null) {
      // back button uses grace
      if (_currentDwellingElement == 'back_button') {
        _hoverGraceTimer?.cancel();
        _hoverGraceTimer =
            Timer(Duration(milliseconds: _hoverGraceMs), _stopDwellTimer);
      } else {
        _stopDwellTimer();
      }
    }
  }

  void _handleHover(String id) {
    VoidCallback? action;
    int dwell = _buttonDwellMs;

    switch (id) {
      case 'back_button':
        dwell = _backDwellMs;
        action = _goBack;
        break;
      case 'dark_mode_button':
        action = _toggleDarkMode;
        break;
      case 'font_increase':
        action = _increaseFont;
        break;
      case 'font_decrease':
        action = _decreaseFont;
        break;
      case 'scroll_up_zone':
        dwell = _navZoneDwellMs;
        action = () => _startAutoScroll(isUp: true);
        break;
      case 'scroll_down_zone':
        dwell = _navZoneDwellMs;
        action = () => _startAutoScroll(isUp: false);
        break;
    }

    if (action != null) {
      _startDwellTimer(id, action, dwell);
    }
  }

  void _startDwellTimer(String id, VoidCallback action, int dwellMs) {
    _stopDwellTimer();
    setState(() {
      _currentDwellingElement = id;
      _dwellProgress = 0.0;
    });

    _dwellStartTime = DateTime.now();
    _dwellTimer =
        Timer.periodic(Duration(milliseconds: _dwellUpdateIntervalMs), (t) {
      if (!mounted || _isDisposed || _currentDwellingElement != id) {
        t.cancel();
        return;
      }
      final elapsed =
          DateTime.now().difference(_dwellStartTime!).inMilliseconds;
      final p = (elapsed / dwellMs).clamp(0.0, 1.0);
      setState(() => _dwellProgress = p);

      if (p >= 1.0) {
        t.cancel();
        action();
      }
    });
  }

  void _stopDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    if (mounted) {
      setState(() {
        _currentDwellingElement = null;
        _dwellProgress = 0.0;
      });
    }
  }

  // ================== Actions ==================
  void _goBack() {
    _stopDwellTimer();
    Navigator.of(context).pop();
  }

  void _toggleDarkMode() {
    _stopDwellTimer();
    setState(() => _isDarkMode = !_isDarkMode);
  }

  void _increaseFont() {
    _stopDwellTimer();
    setState(() => _fontSize = (_fontSize + 2).clamp(12.0, 28.0));
  }

  void _decreaseFont() {
    _stopDwellTimer();
    setState(() => _fontSize = (_fontSize - 2).clamp(12.0, 28.0));
  }

  void _startAutoScroll({required bool isUp}) {
    if (_isAutoScrolling) return;
    if (!_scrollController.hasClients) return;

    _stopDwellTimer();
    setState(() => _isAutoScrolling = true);

    const double step = 3.0; // px per frame
    const frame = Duration(milliseconds: 16); // ~60 FPS

    _autoScrollTimer = Timer.periodic(frame, (timer) {
      if (!mounted || !_scrollController.hasClients) {
        _stopAutoScroll();
        return;
      }

      final cur = _scrollController.offset;
      final max = _scrollController.position.maxScrollExtent;
      double next = cur + (isUp ? -step : step);

      if (next <= 0) {
        next = 0;
        _stopAutoScroll();
      } else if (next >= max) {
        next = max;
        _stopAutoScroll();
      }

      try {
        _scrollController.jumpTo(next);
      } catch (_) {
        _stopAutoScroll();
      }
    });

    // Fail-safe stop after 8s
    Timer(const Duration(seconds: 8), () {
      if (_isAutoScrolling) _stopAutoScroll();
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (mounted) setState(() => _isAutoScrolling = false);
  }

  // ================== UI ==================
  Widget _header() {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(int.parse('0xFF${widget.subject.colors[0].substring(1)}')),
            Color(int.parse('0xFF${widget.subject.colors[1].substring(1)}')),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Container(
                  key: generateKeyForElement('back_button'),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                      if (_currentDwellingElement == 'back_button')
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _dwellProgress,
                            child: Container(height: 3, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  widget.topic.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlsFloating() {
    return Positioned(
      top: 50,
      right: 20,
      child: Column(
        children: [
          _controlButton(
            id: 'dark_mode_button',
            icon: _isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: _isDarkMode ? Colors.yellow : Colors.indigo,
          ),
          const SizedBox(height: 10),
          _controlButton(
              id: 'font_increase', icon: Icons.add, color: Colors.green),
          const SizedBox(height: 5),
          _controlButton(
              id: 'font_decrease', icon: Icons.remove, color: Colors.orange),
        ],
      ),
    );
  }

  Widget _controlButton({
    required String id,
    required IconData icon,
    required Color color,
  }) {
    final dwell = _currentDwellingElement == id;
    return Container(
      key: generateKeyForElement(id),
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: dwell ? color.withOpacity(0.85) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
            color: dwell ? color : color.withOpacity(0.35), width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: dwell ? Colors.white : color, size: 22),
          if (dwell)
            Positioned.fill(
              child: CircularProgressIndicator(
                value: _dwellProgress,
                strokeWidth: 3,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: _isDarkMode ? Colors.grey.shade900 : Colors.white,
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
          _chapter('Chapter 1: Introduction', Colors.blue),
          const SizedBox(height: 16),
          _para(_sample()),
          const SizedBox(height: 24),
          _chapter('Chapter 2: Key Concepts', Colors.green),
          const SizedBox(height: 16),
          _para(_sample()),
          const SizedBox(height: 24),
          _notes(),
          const SizedBox(height: 24),
          _chapter('Chapter 3: Examples and Practice', Colors.purple),
          const SizedBox(height: 16),
          _para(_sample()),
          const SizedBox(height: 24),
          _chapter('Chapter 4: Advanced Topics', Colors.red),
          const SizedBox(height: 16),
          _para(_sample()),
          const SizedBox(height: 24),
          _chapter('Chapter 5: Conclusion', Colors.cyan),
          const SizedBox(height: 16),
          _para(_sample()),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _chapter(String t, MaterialColor c) {
    return Text(
      t,
      style: TextStyle(
        fontSize: _fontSize + 4,
        fontWeight: FontWeight.w600,
        color: _isDarkMode ? c.shade300 : c.shade700,
      ),
    );
  }

  Widget _para(String t) {
    return Text(
      t,
      style: TextStyle(
        fontSize: _fontSize,
        height: 1.6,
        color: _isDarkMode ? Colors.white70 : Colors.black87,
      ),
    );
  }

  Widget _notes() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.yellow.shade900.withOpacity(0.3)
            : Colors.yellow.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade600, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb,
              color:
                  _isDarkMode ? Colors.yellow.shade300 : Colors.yellow.shade700,
              size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Remember these key points when studying this material. Practice regularly and don\'t hesitate to ask questions if you need clarification.',
              style: TextStyle(
                fontSize: _fontSize,
                color: _isDarkMode
                    ? Colors.yellow.shade200
                    : Colors.yellow.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sample() {
    return '''
The simple past tense is used to describe actions that were completed in the past. It tells us about events that happened at a specific time that has already finished.

We form the simple past tense by adding -ed to regular verbs, but many common verbs are irregular and have special past tense forms that you need to memorize.

For example:
• Regular verbs: walk → walked, play → played, study → studied
• Irregular verbs: go → went, eat → ate, see → saw, have → had

The simple past tense is very important in English because we use it constantly when telling stories, describing past experiences, or talking about completed actions.
''';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.grey.shade900 : Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              _header(),

              // ===== Scroll Up Zone =====
              Container(
                key: generateKeyForElement('scroll_up_zone'),
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
                      Icon(Icons.keyboard_arrow_up,
                          size: 26,
                          color: _currentDwellingElement == 'scroll_up_zone'
                              ? Colors.purple.shade700
                              : Colors.purple.withOpacity(0.8)),
                      const SizedBox(width: 8),
                      Text(
                        'Look here to scroll up',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _currentDwellingElement == 'scroll_up_zone'
                              ? Colors.purple.shade700
                              : Colors.purple.withOpacity(0.85),
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

              // ===== Scrollable Content =====
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: _isDarkMode ? Colors.grey.shade900 : Colors.white,
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: _content(),
                    ),
                  ),
                ),
              ),

              // ===== Scroll Down Zone =====
              Container(
                key: generateKeyForElement('scroll_down_zone'),
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
                      Icon(Icons.keyboard_arrow_down,
                          size: 26,
                          color: _currentDwellingElement == 'scroll_down_zone'
                              ? Colors.teal.shade700
                              : Colors.teal.withOpacity(0.8)),
                      const SizedBox(width: 8),
                      Text(
                        'Look here to scroll down',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _currentDwellingElement == 'scroll_down_zone'
                              ? Colors.teal.shade700
                              : Colors.teal.withOpacity(0.85),
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

          // Floating control buttons
          _controlsFloating(),

          // Auto-scroll overlay hint
          if (_isAutoScrolling)
            Positioned(
              top: size.height / 2 - 60,
              left: size.width / 2 - 60,
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
                  children: const [
                    CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                    SizedBox(height: 12),
                    Text('Auto-scrolling...',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Look away to stop',
                        style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
