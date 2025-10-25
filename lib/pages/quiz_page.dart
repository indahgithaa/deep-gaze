// File: lib/pages/quiz_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/subject.dart';
import '../models/topic.dart';
import '../models/question.dart';
import '../models/quiz_result.dart';
import '../services/global_seeso_service.dart';
import '../mixins/responsive_bounds_mixin.dart';
import '../widgets/gaze_overlay_manager.dart';

class QuizPage extends StatefulWidget {
  final Subject subject;
  final Topic topic;
  final List<Question> questions;

  const QuizPage({
    super.key,
    required this.subject,
    required this.topic,
    required this.questions,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with ResponsiveBoundsMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // ===== Quiz state =====
  int _currentQuestionIndex = 0;
  List<int?> _userAnswers = [];
  bool _quizCompleted = false;
  bool _showExplanation = false;

  // ===== Dwell state =====
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // ===== Dwell config =====
  static const int _dwellUpdateIntervalMs = 50;
  static const int _dwellTimeAnswersMs = 1500; // answers + nav
  static const int _dwellTimeBackMs = 1000; // back 1s
  int _activeDwellTimeMs = 1500;

  // ===== Anti-jitter back button =====
  static const int _hoverGraceMs = 120; // brief leave tolerance
  static const double _backInflatePx = 12.0; // sticky hitbox grow
  Timer? _hoverGraceTimer;

  // ===== ResponsiveBoundsMixin config =====
  @override
  double get boundsUpdateDelay => 150.0;

  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.setActivePage('quiz_page', _onEyeTrackingUpdate);

    _userAnswers = List.filled(widget.questions.length, null);
    _initializeEyeTracking();
    _initializeQuizElements();

    // ensure HUD initial state
    GazeOverlayManager.instance.update(
      cursor: const Offset(-1000, -1000),
      visible: false,
      highlight: null,
      progress: null,
    );

    // IMPORTANT: run bounds calc AFTER first frame to avoid MediaQuery crash
    _updateBoundsPostFrame();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _hoverGraceTimer?.cancel();

    _eyeTrackingService.removePage('quiz_page');
    clearBounds();
    GazeOverlayManager.instance.hide();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe to access MediaQuery here
    updateBoundsAfterBuild();
  }

  // ===== Helpers =====
  void _initializeQuizElements() {
    // 4 answer slots (A-D)
    for (int i = 0; i < 4; i++) {
      generateKeyForElement('answer_$i');
    }
    // nav + back
    generateKeyForElement('back_button');
    generateKeyForElement('submit_button');
    generateKeyForElement('next_button');
    generateKeyForElement('previous_button');
    // DO NOT call updateBoundsAfterBuild() here (too early in init)
  }

  void _updateBoundsPostFrame() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      updateBoundsAfterBuild();
    });
  }

  // ===== Eye-tracking =====
  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;
    try {
      await _eyeTrackingService.initialize(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Eye tracking init failed: $e"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;
    final gaze = Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    // HUD global
    GazeOverlayManager.instance.update(
      cursor: gaze,
      visible: _eyeTrackingService.isTracking,
      highlight: null,
      progress: _currentDwellingElement != null ? _dwellProgress : null,
    );

    // Hit test
    String? hovered = getElementAtPoint(gaze);

    // Sticky for back button
    final backRect = getBoundsForElement('back_button');
    if (backRect != null && backRect.inflate(_backInflatePx).contains(gaze)) {
      hovered = 'back_button';
    }

    if (hovered != null) {
      _hoverGraceTimer?.cancel();
      if (_currentDwellingElement != hovered) {
        _handleElementHover(hovered);
      }
    } else {
      if (_currentDwellingElement != null) {
        _maybeStopDwellTimerWithGrace(_currentDwellingElement);
      }
    }

    if (mounted) setState(() {});
  }

  // ===== Dwell helpers =====
  void _handleElementHover(String id) {
    VoidCallback? action;
    if (id == 'back_button') {
      action = _goBack;
      _activeDwellTimeMs = _dwellTimeBackMs;
    } else if (id == 'next_button') {
      action = _nextQuestion;
      _activeDwellTimeMs = _dwellTimeAnswersMs;
    } else if (id == 'previous_button') {
      action = _previousQuestion;
      _activeDwellTimeMs = _dwellTimeAnswersMs;
    } else if (id == 'submit_button') {
      action = _submitQuiz;
      _activeDwellTimeMs = _dwellTimeAnswersMs;
    } else if (id.startsWith('answer_')) {
      final idx = int.tryParse(id.split('_')[1]) ?? 0;
      action = () => _selectAnswer(idx);
      _activeDwellTimeMs = _dwellTimeAnswersMs;
    }
    if (action != null) {
      _startDwellTimer(id, action, dwellMs: _activeDwellTimeMs);
    }
  }

  void _startDwellTimer(String id, VoidCallback action,
      {required int dwellMs}) {
    if (_isDisposed || !mounted) return;
    if (_currentDwellingElement == id) return;

    _stopDwellTimer();
    setState(() {
      _currentDwellingElement = id;
      _dwellProgress = 0.0;
    });

    _dwellStartTime = DateTime.now();
    _dwellTimer = Timer.periodic(
        const Duration(milliseconds: _dwellUpdateIntervalMs), (timer) {
      if (_isDisposed ||
          !mounted ||
          _currentDwellingElement != id ||
          _dwellStartTime == null) {
        timer.cancel();
        return;
      }
      final elapsed =
          DateTime.now().difference(_dwellStartTime!).inMilliseconds;
      final progress = (elapsed / dwellMs).clamp(0.0, 1.0);
      setState(() => _dwellProgress = progress);

      // HUD progress
      GazeOverlayManager.instance.update(
        cursor: Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY),
        visible: _eyeTrackingService.isTracking,
        progress: _dwellProgress,
      );

      if (progress >= 1.0) {
        timer.cancel();
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
    // reset HUD progress
    GazeOverlayManager.instance.update(
      cursor: Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY),
      visible: _eyeTrackingService.isTracking,
      progress: null,
    );
  }

  void _maybeStopDwellTimerWithGrace(String? leaving) {
    if (leaving == 'back_button') {
      _hoverGraceTimer?.cancel();
      _hoverGraceTimer = Timer(Duration(milliseconds: _hoverGraceMs), () {
        if (_currentDwellingElement == leaving) _stopDwellTimer();
      });
    } else {
      _stopDwellTimer();
    }
  }

  // ===== Quiz logic =====
  void _goBack() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    Navigator.of(context).pop();
  }

  void _selectAnswer(int i) {
    if (_quizCompleted) return;
    _stopDwellTimer();
    setState(() => _userAnswers[_currentQuestionIndex] = i);
  }

  void _nextQuestion() {
    _stopDwellTimer();
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _showExplanation = false;
      });
      _updateBoundsPostFrame(); // <— SAFE post-frame
    }
  }

  void _previousQuestion() {
    _stopDwellTimer();
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _showExplanation = false;
      });
      _updateBoundsPostFrame(); // <— SAFE post-frame
    }
  }

  void _submitQuiz() {
    _stopDwellTimer();
    if (_userAnswers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please answer all questions first!'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    int correct = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_userAnswers[i] == widget.questions[i].correctAnswerIndex) correct++;
    }
    final result = QuizResult(
      totalQuestions: widget.questions.length,
      correctAnswers: correct,
      userAnswers: _userAnswers.cast<int>(),
      questions: widget.questions,
      completedAt: DateTime.now(),
    );
    _showResultsDialog(result);
  }

  void _showResultsDialog(QuizResult r) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Quiz Completed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: ${r.correctAnswers}/${r.totalQuestions}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Grade: ${r.grade}',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: r.percentage >= 70 ? Colors.green : Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // back to subject
            },
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              setState(() {
                _quizCompleted = false;
                _userAnswers = List.filled(widget.questions.length, null);
                _currentQuestionIndex = 0;
                _showExplanation = false;
              });
              _updateBoundsPostFrame(); // <— SAFE post-frame
            },
            child: const Text('Retake'),
          ),
        ],
      ),
    );
  }

  // ===== UI components =====
  Widget _buildAnswerOption(int i, String text) {
    final selected = _userAnswers[_currentQuestionIndex] == i;
    final dwell = _currentDwellingElement == 'answer_$i';
    final q = widget.questions[_currentQuestionIndex];

    Color bg;
    if (_showExplanation) {
      if (i == q.correctAnswerIndex) {
        bg = Colors.green.shade100;
      } else if (selected) {
        bg = Colors.red.shade100;
      } else {
        bg = Colors.white;
      }
    } else {
      bg = selected
          ? Colors.blue.shade100
          : (dwell ? Colors.blue.shade50 : Colors.white);
    }

    return Container(
      key: generateKeyForElement('answer_$i'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: dwell ? 4 : 1,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: bg,
            border: Border.all(
              color: dwell
                  ? Colors.blue
                  : (selected ? Colors.blue : Colors.grey.shade300),
              width: dwell || selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              if (dwell)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    height: 3,
                    width: (MediaQuery.of(context).size.width - 80) *
                        _dwellProgress,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.blue : Colors.grey.shade300,
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + i),
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(String label, Color baseColor,
      {bool active = false, bool enabled = true}) {
    final Color bgColor = enabled
        ? (active ? _darken(baseColor, 0.15) : baseColor)
        : Colors.grey.shade300;

    return Material(
      elevation: active ? 4 : 1,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            if (active)
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
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// helper kecil buat gelapin warna (mirip shade700)
  Color _darken(Color color, [double amount = .1]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  Widget _buildNavigationButtons() {
    final last = _currentQuestionIndex == widget.questions.length - 1;
    final answered = _userAnswers[_currentQuestionIndex] != null;
    final allDone = !_userAnswers.contains(null);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            Expanded(
              child: Container(
                key: generateKeyForElement('previous_button'),
                height: 50,
                margin: const EdgeInsets.only(right: 10),
                child: _navBtn(
                  'Previous',
                  Colors.grey,
                  active: _currentDwellingElement == 'previous_button',
                  enabled: true,
                ),
              ),
            ),
          Expanded(
            child: Container(
              key:
                  generateKeyForElement(last ? 'submit_button' : 'next_button'),
              height: 50,
              child: _navBtn(
                last
                    ? (allDone
                        ? 'Submit'
                        : 'Submit (${_userAnswers.where((a) => a != null).length}/${widget.questions.length})')
                    : 'Next',
                Colors.blue,
                active: _currentDwellingElement ==
                    (last ? 'submit_button' : 'next_button'),
                enabled: last ? allDone : answered,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Build =====
  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.questions.length;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(int.parse(
                      '0xFF${widget.subject.colors[0].substring(1)}')),
                  Color(int.parse(
                      '0xFF${widget.subject.colors[1].substring(1)}')),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // ===== Header =====
                  Padding(
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
                                      child: Container(
                                          height: 3, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Kuis',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 44), // spacer kanan
                      ],
                    ),
                  ),

                  // ===== Progress =====
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Question ${_currentQuestionIndex + 1}/${widget.questions.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.35),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 6,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== Question Card =====
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x11000000),
                            blurRadius: 10,
                            offset: Offset(0, 6),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.questionText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ===== Answers =====
                          Expanded(
                            child: ListView.builder(
                              itemCount: q.options.length,
                              itemBuilder: (context, i) =>
                                  _buildAnswerOption(i, q.options[i]),
                            ),
                          ),

                          // ===== Explanation (optional) =====
                          if (_showExplanation && q.explanation != null)
                            Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.lightbulb,
                                      size: 20, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      q.explanation!,
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ===== Nav Buttons =====
                  _buildNavigationButtons(),
                ],
              ),
            ),
          ),

          // HUD handled globally by GazeOverlayManager
        ],
      ),
    );
  }
}
