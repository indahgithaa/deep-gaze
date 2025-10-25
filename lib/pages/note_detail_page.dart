// File: lib/pages/note_detail_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/global_seeso_service.dart';
import '../mixins/responsive_bounds_mixin.dart';
import '../widgets/gaze_overlay_manager.dart';
import '../models/lecture_note.dart';

class NoteDetailPage extends StatefulWidget {
  final LectureNote note;
  const NoteDetailPage({super.key, required this.note});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage>
    with ResponsiveBoundsMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStart;

  // Config dwell
  static const int _backDwellMs = 1000;
  static const int _buttonDwellMs = 1500;
  static const int _scrollDwellMs = 800;
  static const int _dwellUpdateMs = 50;

  // Reading state
  final ScrollController _scrollController = ScrollController();
  bool _isDark = false;
  double _fontSize = 16;
  bool _isAutoScrolling = false;
  bool _isFavorite = false;
  Timer? _autoScrollTimer;

  bool _boundsReady = false;

  @override
  double get boundsUpdateDelay => 150.0;
  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.setActivePage('note_detail', _onEyeUpdate);
    _registerKeys();

    GazeOverlayManager.instance.attach(context);
    GazeOverlayManager.instance.update(cursor: Offset.zero, visible: false);

    _initializeEyeTracking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      updateBoundsAfterBuild();
      _boundsReady = true;
    });
  }

  void _registerKeys() {
    generateKeyForElement('back_button');
    generateKeyForElement('scroll_up_zone');
    generateKeyForElement('scroll_down_zone');
    generateKeyForElement('dark_mode_button');
    generateKeyForElement('font_increase');
    generateKeyForElement('font_decrease');
    generateKeyForElement('favorite_button');
    generateKeyForElement('share_button');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    _eyeTrackingService.removePage('note_detail');
    clearBounds();
    GazeOverlayManager.instance.hide();
    super.dispose();
  }

  Future<void> _initializeEyeTracking() async {
    try {
      await _eyeTrackingService.initialize(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Eye tracking init failed: $e")),
      );
    }
  }

  // ===================== Eye Tracking =====================
  void _onEyeUpdate() {
    if (!mounted || _isDisposed || !_boundsReady) return;

    final gaze = Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);
    GazeOverlayManager.instance.update(
      cursor: gaze,
      visible: _eyeTrackingService.isTracking,
      progress: _currentDwellingElement != null ? _dwellProgress : null,
    );

    String? hovered = getElementAtPoint(gaze);
    final backRect = getBoundsForElement('back_button');
    if (backRect != null && backRect.inflate(10).contains(gaze)) {
      hovered = 'back_button';
    }

    if (hovered != null && hovered != _currentDwellingElement) {
      _handleHover(hovered);
    } else if (hovered == null && _currentDwellingElement != null) {
      _stopDwell();
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
      case 'scroll_up_zone':
        dwell = _scrollDwellMs;
        action = () => _startAutoScroll(true);
        break;
      case 'scroll_down_zone':
        dwell = _scrollDwellMs;
        action = () => _startAutoScroll(false);
        break;
      case 'dark_mode_button':
        action = _toggleDark;
        break;
      case 'font_increase':
        action = _incFont;
        break;
      case 'font_decrease':
        action = _decFont;
        break;
      case 'favorite_button':
        action = _toggleFav;
        break;
      case 'share_button':
        action = _share;
        break;
    }

    if (action != null) _startDwell(id, action, dwell);
  }

  void _startDwell(String id, VoidCallback action, int ms) {
    _stopDwell();
    setState(() {
      _currentDwellingElement = id;
      _dwellProgress = 0;
    });
    _dwellStart = DateTime.now();
    _dwellTimer = Timer.periodic(Duration(milliseconds: _dwellUpdateMs), (t) {
      if (!mounted || _isDisposed || _currentDwellingElement != id) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_dwellStart!).inMilliseconds;
      final p = (elapsed / ms).clamp(0.0, 1.0);
      setState(() => _dwellProgress = p);
      if (p >= 1.0) {
        t.cancel();
        action();
      }
    });
  }

  void _stopDwell() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    if (mounted) {
      setState(() {
        _currentDwellingElement = null;
        _dwellProgress = 0.0;
      });
    }
  }

  // ===================== Actions =====================
  void _goBack() {
    _stopDwell();
    Navigator.of(context).pop();
  }

  void _toggleDark() {
    _stopDwell();
    setState(() => _isDark = !_isDark);
  }

  void _incFont() {
    _stopDwell();
    setState(() => _fontSize = (_fontSize + 2).clamp(12, 28));
  }

  void _decFont() {
    _stopDwell();
    setState(() => _fontSize = (_fontSize - 2).clamp(12, 28));
  }

  void _toggleFav() {
    _stopDwell();
    setState(() => _isFavorite = !_isFavorite);
  }

  void _share() {
    _stopDwell();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note shared (mock)')),
    );
  }

  void _startAutoScroll(bool up) {
    if (_isAutoScrolling) return;
    _stopDwell();

    if (!_scrollController.hasClients) return;
    _isAutoScrolling = true;
    const step = 3.0;
    _autoScrollTimer =
        Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || !_scrollController.hasClients) {
        timer.cancel();
        _isAutoScrolling = false;
        return;
      }
      final pos = _scrollController.offset + (up ? -step : step);
      if (pos <= 0 || pos >= _scrollController.position.maxScrollExtent) {
        timer.cancel();
        _isAutoScrolling = false;
      } else {
        _scrollController.jumpTo(pos);
      }
    });
    Future.delayed(const Duration(seconds: 6), () {
      if (_autoScrollTimer?.isActive ?? false) {
        _autoScrollTimer?.cancel();
        _isAutoScrolling = false;
      }
    });
  }

  // ===================== UI =====================
  Widget _buildHeader() {
    return Container(
      height: 100,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                key: generateKeyForElement('back_button'),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    if (_currentDwellingElement == 'back_button')
                      Positioned(
                        bottom: 0,
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
              const Expanded(
                  child: Text('Note Detail',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600))),
              const Icon(Icons.visibility, color: Colors.blue, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlBtn(String id, IconData icon, Color c) {
    final dwell = _currentDwellingElement == id;
    return Container(
      key: generateKeyForElement(id),
      width: 48,
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        borderRadius: BorderRadius.circular(24),
        color: c.withOpacity(dwell ? 0.8 : 0.1),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: dwell ? Colors.white : c),
            if (dwell)
              CircularProgressIndicator(
                value: _dwellProgress,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(c),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    return Positioned(
      top: 60,
      right: 20,
      child: Column(
        children: [
          _controlBtn('dark_mode_button',
              _isDark ? Icons.light_mode : Icons.dark_mode, Colors.indigo),
          _controlBtn('font_increase', Icons.text_increase, Colors.green),
          _controlBtn('font_decrease', Icons.text_decrease, Colors.orange),
          _controlBtn(
              'favorite_button',
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              _isFavorite ? Colors.red : Colors.grey),
          _controlBtn('share_button', Icons.share, Colors.blue),
        ],
      ),
    );
  }

  Widget _scrollZone(String id, bool up) {
    final dwell = _currentDwellingElement == id;
    return Container(
      key: generateKeyForElement(id),
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: up ? Alignment.topCenter : Alignment.bottomCenter,
          end: up ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            (up ? Colors.purple : Colors.teal).withOpacity(dwell ? 0.5 : 0.2),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(up ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: (up ? Colors.purple : Colors.teal)
                    .withOpacity(dwell ? 1 : 0.7)),
            const SizedBox(width: 6),
            Text(
              up ? 'Look here to scroll up' : 'Look here to scroll down',
              style: TextStyle(
                  color: (up ? Colors.purple : Colors.teal)
                      .withOpacity(dwell ? 1 : 0.8),
                  fontWeight: FontWeight.w600),
            ),
            if (dwell)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    value: _dwellProgress,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        up ? Colors.purple : Colors.teal)),
              )
          ],
        ),
      ),
    );
  }

  Widget _noteBody() {
    return Expanded(
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          child: Text(widget.note.content,
              style: TextStyle(
                fontSize: _fontSize,
                color: _isDark ? Colors.white70 : Colors.black87,
                height: 1.6,
              )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark ? Colors.grey.shade900 : Colors.white,
      body: Stack(children: [
        Column(children: [
          _buildHeader(),
          _scrollZone('scroll_up_zone', true),
          _noteBody(),
          _scrollZone('scroll_down_zone', false),
        ]),
        _controls(),
        if (_isAutoScrolling)
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.white, width: 2)),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 8),
                  Text('Auto-scrolling...',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}
