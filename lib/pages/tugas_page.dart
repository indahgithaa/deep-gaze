// File: lib/pages/tugas_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/subject.dart';
import '../models/topic.dart';
import '../services/global_seeso_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import '../widgets/eye_controlled_keyboard.dart';
import '../mixins/responsive_bounds_mixin.dart';

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

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration
  static const int _keyboardDwellTimeMs = 600;
  static const int _buttonDwellTimeMs = 1500;
  static const int _dwellUpdateIntervalMs = 100;

  // Question management
  int _currentQuestionIndex = 0;
  final List<String> _questions = [
    "I ___ a mistake yesterday (do).",
    "Last week, I ___ Julia (meet).",
    "What is 2 + 2?",
    "Write a short greeting.",
    "What day is today?"
  ];

  // Text input state
  String _answerText = '';
  final ScrollController _scrollController = ScrollController();

  // Flag to track if bounds have been calculated
  bool _boundsCalculated = false;

  // Override mixin configuration
  @override
  double get boundsUpdateDelay => 150.0;

  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    print("DEBUG: TugasPage initState");
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.addListener(_onEyeTrackingUpdate);

    // Initialize element keys using mixin
    _initializeElementKeys();

    _initializeEyeTracking();

    // Calculate bounds after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateBoundsAfterBuild();
    });
  }

  void _initializeElementKeys() {
    // Generate keys for navigation and control buttons using mixin
    generateKeyForElement('back_button');
    generateKeyForElement('submit_button');
    generateKeyForElement('clear_button');
    generateKeyForElement('next_button');
    generateKeyForElement('prev_button');

    print(
        "DEBUG: Generated ${elementCount} non-keyboard element keys using mixin");
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _scrollController.dispose();
    if (_eyeTrackingService.hasListeners) {
      _eyeTrackingService.removeListener(_onEyeTrackingUpdate);
    }

    // Clean up mixin resources
    clearBounds();

    print("DEBUG: TugasPage disposed");
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recalculate bounds when dependencies change
    updateBoundsAfterBuild();
  }

  void _onKeyboardBoundsCalculated(Map<String, Rect> keyboardBounds) {
    print("DEBUG: Received keyboard bounds: ${keyboardBounds.length} keys");

    // Add keyboard bounds to the mixin's bounds system
    keyboardBounds.forEach((elementId, bounds) {
      updateElementBounds(elementId, bounds);
    });

    if (mounted) {
      setState(() {
        _boundsCalculated = true;
      });
    }

    print("DEBUG: Total bounds after keyboard integration: ${boundsCount}");
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted || !_boundsCalculated) return;
    if (!_eyeTrackingService.isTracking) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    // Quick bounds check
    if (currentGazePoint.dx < 0 ||
        currentGazePoint.dy < 0 ||
        currentGazePoint.dx > MediaQuery.of(context).size.width ||
        currentGazePoint.dy > MediaQuery.of(context).size.height) {
      return;
    }

    // Use mixin's precise hit detection for all elements
    String? hoveredElement = getElementAtPoint(currentGazePoint);

    // Only process if hover state changed
    if (hoveredElement != _currentDwellingElement) {
      if (hoveredElement != null) {
        print(
            "DEBUG: TugasPage - Started dwelling on: $hoveredElement at gaze point: $currentGazePoint");
        _handleElementHover(hoveredElement);
      } else if (_currentDwellingElement != null) {
        print(
            "DEBUG: TugasPage - Stopped dwelling on: $_currentDwellingElement");
        _stopDwellTimer();
      }
    }
  }

  void _handleElementHover(String elementId) {
    VoidCallback action;
    int dwellTime = _buttonDwellTimeMs;

    if (elementId == 'back_button') {
      action = _goBack;
    } else if (elementId == 'submit_button') {
      action = _submitAnswer;
    } else if (elementId == 'clear_button') {
      action = _clearText;
    } else if (elementId == 'next_button') {
      action = _nextQuestion;
    } else if (elementId == 'prev_button') {
      action = _previousQuestion;
    } else if (elementId.startsWith('key_')) {
      final keyValue = elementId.substring(4);
      action = () => _onKeyPressed(keyValue);
      dwellTime = _keyboardDwellTimeMs;
    } else {
      print("DEBUG: Unknown element: $elementId");
      return;
    }

    _startDwellTimer(elementId, action, dwellTime);
  }

  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;

    try {
      print("DEBUG: Initializing eye tracking di TugasPage");
      await _eyeTrackingService.initialize(context);
      print("DEBUG: Eye tracking berhasil diinisialisasi di TugasPage");
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
          print(
              "DEBUG: Dwell timer completed for $elementId, executing action");
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

  void _goBack() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    Navigator.of(context).pop();
  }

  void _nextQuestion() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answerText = ''; // Clear answer for new question
      });

      // Recalculate bounds after question change
      updateBoundsAfterBuild();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Question ${_currentQuestionIndex + 1} of ${_questions.length}'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _previousQuestion() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _answerText = ''; // Clear answer for previous question
      });

      // Recalculate bounds after question change
      updateBoundsAfterBuild();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Question ${_currentQuestionIndex + 1} of ${_questions.length}'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _onKeyPressed(String key) {
    if (_isDisposed || !mounted) return;

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

    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Show feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Typed: ${key == 'SPACE' ? 'Space' : key == 'ENTER' ? 'Enter' : key == 'BACKSPACE' ? 'Backspace' : key}'),
        duration: const Duration(milliseconds: 500),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _clearText() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    setState(() {
      _answerText = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text cleared'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _submitAnswer() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    if (_answerText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type your answer before submitting!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Answer Submitted!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1}: ${_questions[_currentQuestionIndex]}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Your Answer:'),
              const SizedBox(height: 5),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(
                    _answerText,
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Word count: ${_answerText.trim().split(RegExp(r'\s+')).length}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            if (_currentQuestionIndex < _questions.length - 1)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _nextQuestion();
                },
                child: const Text('Next Question'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Finish'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _answerText = '';
                });
              },
              child: const Text('Clear & Retry'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuestionHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              // Question navigation indicators
              Row(
                children: List.generate(_questions.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentQuestionIndex
                          ? Colors.blue.shade700
                          : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              _questions[_currentQuestionIndex],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerBox() {
    final isCurrentlyDwelling = _currentDwellingElement == 'clear_button';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Your Answer:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // Clear button using mixin
              Material(
                key: generateKeyForElement('clear_button'), // Use mixin
                elevation: isCurrentlyDwelling ? 4 : 2,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isCurrentlyDwelling
                        ? Colors.red.shade50
                        : Colors.grey.shade50,
                  ),
                  child: Stack(
                    children: [
                      if (isCurrentlyDwelling)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            height: 2,
                            width: 88 * _dwellProgress,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear,
                            size: 16,
                            color: isCurrentlyDwelling
                                ? Colors.red
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 12,
                              color: isCurrentlyDwelling
                                  ? Colors.red
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 100,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Text(
                  _answerText.isEmpty
                      ? 'Start typing using the keyboard below...'
                      : _answerText,
                  style: TextStyle(
                    fontSize: 14,
                    color: _answerText.isEmpty
                        ? Colors.grey.shade500
                        : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Words: ${_answerText.trim().isEmpty ? 0 : _answerText.trim().split(RegExp(r'\s+')).length} | Characters: ${_answerText.length}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final isSubmitDwelling = _currentDwellingElement == 'submit_button';
    final isNextDwelling = _currentDwellingElement == 'next_button';
    final isPrevDwelling = _currentDwellingElement == 'prev_button';
    final hasText = _answerText.trim().isNotEmpty;
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;
    final isFirstQuestion = _currentQuestionIndex == 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Previous button using mixin
          if (!isFirstQuestion)
            Expanded(
              flex: 1,
              child: Container(
                key: generateKeyForElement('prev_button'), // Use mixin
                height: 50,
                margin: const EdgeInsets.only(right: 8),
                child: Material(
                  elevation: isPrevDwelling ? 6 : 2,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isPrevDwelling
                          ? Colors.grey.shade300
                          : Colors.grey.shade100,
                    ),
                    child: Stack(
                      children: [
                        if (isPrevDwelling)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _dwellProgress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade800,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const Center(
                          child: Text(
                            'Previous',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Submit button using mixin
          Expanded(
            flex: 2,
            child: Container(
              key: generateKeyForElement('submit_button'), // Use mixin
              height: 50,
              margin: EdgeInsets.symmetric(horizontal: isFirstQuestion ? 0 : 8),
              child: Material(
                elevation: isSubmitDwelling ? 6 : 2,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: hasText
                        ? (isSubmitDwelling
                            ? Colors.green.shade700
                            : Colors.green.shade600)
                        : Colors.grey.shade300,
                  ),
                  child: Stack(
                    children: [
                      if (isSubmitDwelling)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _dwellProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Center(
                        child: Text(
                          hasText ? 'Submit Answer' : 'Type answer first',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                hasText ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Next button using mixin (only if not last question)
          if (!isLastQuestion)
            Expanded(
              flex: 1,
              child: Container(
                key: generateKeyForElement('next_button'), // Use mixin
                height: 50,
                margin: const EdgeInsets.only(left: 8),
                child: Material(
                  elevation: isNextDwelling ? 6 : 2,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isNextDwelling
                          ? Colors.blue.shade700
                          : Colors.blue.shade600,
                    ),
                    child: Stack(
                      children: [
                        if (isNextDwelling)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _dwellProgress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const Center(
                          child: Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(int.parse(
                      '0xFF${widget.subject.colors[0].substring(1)}')),
                  Color(int.parse(
                      '0xFF${widget.subject.colors[1].substring(1)}')),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        GestureDetector(
                          key:
                              generateKeyForElement('back_button'), // Use mixin
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
                            'Assignment Questions',
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

                  // Main content area
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Question header
                          _buildQuestionHeader(),

                          // Answer input box
                          _buildAnswerBox(),

                          const SizedBox(height: 10),

                          // Eye-controlled keyboard with mixin integration
                          Expanded(
                            child: EyeControlledKeyboard(
                              onKeyPressed: _onKeyPressed,
                              currentDwellingElement: _currentDwellingElement,
                              dwellProgress: _dwellProgress,
                              onBoundsCalculated: _onKeyboardBoundsCalculated,
                            ),
                          ),

                          // Navigation buttons
                          _buildNavigationButtons(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Gaze point indicator
          GazePointWidget(
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            isVisible: _eyeTrackingService.isTracking,
          ),
          // Status information
          // StatusInfoWidget(
          //   statusMessage: _eyeTrackingService.statusMessage,
          //   currentPage: 4,
          //   totalPages: 4,
          //   gazeX: _eyeTrackingService.gazeX,
          //   gazeY: _eyeTrackingService.gazeY,
          //   currentDwellingElement: _currentDwellingElement,
          //   dwellProgress: _dwellProgress,
          // ),
        ],
      ),
    );
  }
}
