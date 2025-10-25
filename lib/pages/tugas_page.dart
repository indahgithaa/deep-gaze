// File: lib/pages/tugas_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/subject.dart';
import '../models/topic.dart';
import '../services/global_seeso_service.dart';
import '../mixins/responsive_bounds_mixin.dart';
import '../widgets/eye_controlled_keyboard.dart';
import '../widgets/gaze_overlay_manager.dart';

class TugasPage extends StatefulWidget {
  final Subject subject;
  final Topic topic;

  const TugasPage({
    super.key,
    required this.subject,
    required this.topic,
  });

  @override
  State<TugasPage> createState() => _TugasPageState();
}

class _TugasPageState extends State<TugasPage> with ResponsiveBoundsMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Config
  static const int _keyboardDwellMs = 600;
  static const int _buttonDwellMs = 1500;
  static const int _backDwellMs = 1000;
  static const int _dwellUpdateIntervalMs = 60;

  // Anti-jitter
  static const int _hoverGraceMs = 120;
  static const double _backInflatePx = 12.0;
  Timer? _hoverGraceTimer;

  // Content
  final List<String> _questions = [
    "x + 8 = 14, x = ?",
    "x : 4 = 2, x = ?",
    "What is 2 + 2?",
    "Write a short greeting.",
    "What day is today?"
  ];
  int _currentQuestionIndex = 0;
  String _answerText = '';
  final ScrollController _scrollController = ScrollController();

  bool _boundsReady = false;

  @override
  double get boundsUpdateDelay => 150.0;
  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.setActivePage('tugas_page', _onEyeTrackingUpdate);
    _initializeEyeTracking();

    // Global HUD attach
    GazeOverlayManager.instance.attach(context);
    GazeOverlayManager.instance.update(
      cursor: const Offset(-1000, -1000),
      visible: false,
      highlight: null,
      progress: null,
    );

    _registerAllKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateBoundsAfterBuild();
      _boundsReady = true;
    });
  }

  void _registerAllKeys() {
    generateKeyForElement('back_button');
    generateKeyForElement('clear_button');
    generateKeyForElement('submit_button');
    generateKeyForElement('next_button');
    generateKeyForElement('prev_button');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hoverGraceTimer?.cancel();
    _dwellTimer?.cancel();
    _scrollController.dispose();
    _eyeTrackingService.removePage('tugas_page');
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eye tracking init failed: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // ================== EYE TRACKING =====================
  void _onEyeTrackingUpdate() {
    if (!mounted || _isDisposed || !_boundsReady) return;
    final gaze = Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    GazeOverlayManager.instance.update(
      cursor: gaze,
      visible: _eyeTrackingService.isTracking,
      progress: _currentDwellingElement != null ? _dwellProgress : null,
    );

    String? hovered = getElementAtPoint(gaze);
    final backRect = getBoundsForElement('back_button');
    if (backRect != null && backRect.inflate(_backInflatePx).contains(gaze)) {
      hovered = 'back_button';
    }

    if (hovered != null) {
      _hoverGraceTimer?.cancel();
      if (_currentDwellingElement != hovered) {
        _handleHover(hovered);
      }
    } else if (_currentDwellingElement != null) {
      _maybeStopWithGrace(_currentDwellingElement!);
    }
  }

  void _handleHover(String id) {
    VoidCallback? action;
    int dwell = _buttonDwellMs;

    if (id == 'back_button') {
      dwell = _backDwellMs;
      action = _goBack;
    } else if (id == 'clear_button') {
      action = _clearText;
    } else if (id == 'submit_button') {
      action = _submitAnswer;
    } else if (id == 'next_button') {
      action = _nextQuestion;
    } else if (id == 'prev_button') {
      action = _prevQuestion;
    } else if (id.startsWith('key_')) {
      dwell = _keyboardDwellMs;
      final key = id.substring(4);
      action = () => _onKeyPressed(key);
    }

    if (action != null) _startDwellTimer(id, action, dwell);
  }

  void _maybeStopWithGrace(String leaving) {
    if (leaving == 'back_button') {
      _hoverGraceTimer?.cancel();
      _hoverGraceTimer = Timer(
        Duration(milliseconds: _hoverGraceMs),
        () {
          if (_currentDwellingElement == leaving) _stopDwellTimer();
        },
      );
    } else {
      _stopDwellTimer();
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
      final progress = (elapsed / dwellMs).clamp(0.0, 1.0);
      setState(() => _dwellProgress = progress);

      if (progress >= 1.0) {
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

  // ================== ACTIONS =====================
  void _goBack() {
    _stopDwellTimer();
    Navigator.of(context).pop();
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answerText = '';
      });
      updateBoundsAfterBuild();
    }
  }

  void _prevQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _answerText = '';
      });
      updateBoundsAfterBuild();
    }
  }

  void _onKeyPressed(String key) {
    setState(() {
      if (key == 'BACKSPACE') {
        if (_answerText.isNotEmpty) {
          _answerText = _answerText.substring(0, _answerText.length - 1);
        }
      } else if (key == 'SPACE') {
        _answerText += ' ';
      } else if (key == 'ENTER') {
        _answerText += '\n';
      } else {
        _answerText += key;
      }
    });
  }

  void _clearText() {
    _stopDwellTimer();
    setState(() => _answerText = '');
  }

  void _submitAnswer() {
    _stopDwellTimer();
    if (_answerText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please type your answer first!'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Answer Submitted!'),
        content: SingleChildScrollView(
          child: Text(
            _answerText,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
        actions: [
          if (_currentQuestionIndex < _questions.length - 1)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _nextQuestion();
              },
              child: const Text('Next'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ================== UI =====================
  Widget _buildHeader() {
    return Padding(
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
                  const Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
          const Expanded(
            child: Text(
              'Assignment Questions',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Text(
          _questions[_currentQuestionIndex],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildAnswerBox() {
    final isDwelling = _currentDwellingElement == 'clear_button';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Your Answer:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black87)),
              const Spacer(),
              Container(
                key: generateKeyForElement('clear_button'),
                decoration: BoxDecoration(
                  color: isDwelling ? Colors.red.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.clear,
                        size: 16,
                        color: isDwelling ? Colors.red : Colors.grey.shade600),
                    const SizedBox(width: 4),
                    const Text('Clear',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 100,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Text(
                _answerText.isEmpty
                    ? 'Start typing using the keyboard below...'
                    : _answerText,
                style: TextStyle(
                  color:
                      _answerText.isEmpty ? Colors.grey.shade500 : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtons() {
    final isSubmit = _currentDwellingElement == 'submit_button';
    final isNext = _currentDwellingElement == 'next_button';
    final isPrev = _currentDwellingElement == 'prev_button';
    final hasText = _answerText.trim().isNotEmpty;
    final last = _currentQuestionIndex == _questions.length - 1;
    final first = _currentQuestionIndex == 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (!first)
            Expanded(
              child: Container(
                key: generateKeyForElement('prev_button'),
                height: 50,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isPrev ? Colors.grey.shade400 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    if (isPrev)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          height: 3,
                          width: (MediaQuery.of(context).size.width / 2 - 30) *
                              _dwellProgress,
                          color: Colors.white,
                        ),
                      ),
                    const Center(
                        child: Text('Previous',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Container(
              key: generateKeyForElement('submit_button'),
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: hasText
                    ? (isSubmit ? Colors.green.shade700 : Colors.green.shade600)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  if (isSubmit)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        height: 3,
                        width: (MediaQuery.of(context).size.width / 2 - 30) *
                            _dwellProgress,
                        color: Colors.white,
                      ),
                    ),
                  Center(
                      child: Text(
                    hasText ? 'Submit' : 'Type first',
                    style: TextStyle(
                        color: hasText ? Colors.white : Colors.grey.shade600),
                  )),
                ],
              ),
            ),
          ),
          if (!last)
            Expanded(
              child: Container(
                key: generateKeyForElement('next_button'),
                height: 50,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: isNext ? Colors.blue.shade700 : Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    if (isNext)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          height: 3,
                          width: (MediaQuery.of(context).size.width / 2 - 30) *
                              _dwellProgress,
                          color: Colors.white,
                        ),
                      ),
                    const Center(
                        child: Text('Next',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(
                    int.parse('0xFF${widget.subject.colors[0].substring(1)}')),
                Color(
                    int.parse('0xFF${widget.subject.colors[1].substring(1)}')),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      _buildQuestion(),
                      _buildAnswerBox(),
                      Expanded(
                        child: EyeControlledKeyboard(
                          onKeyPressed: _onKeyPressed,
                          currentDwellingElement: _currentDwellingElement,
                          dwellProgress: _dwellProgress,
                          onBoundsCalculated: (kb) {
                            kb.forEach(updateElementBounds);
                            _boundsReady = true;
                          },
                        ),
                      ),
                      _buildNavButtons(),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
