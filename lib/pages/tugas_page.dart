// File: lib/pages/tugas_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/subject.dart';
import '../models/topic.dart';
import '../services/global_seeso_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import '../widgets/eye_controlled_keyboard.dart';

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

class _TugasPageState extends State<TugasPage> {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration - 600ms for keyboard, 1.5s for other buttons
  static const int _keyboardDwellTimeMs = 600;
  static const int _buttonDwellTimeMs = 1500;
  static const int _dwellUpdateIntervalMs = 100;

  // Button boundaries for automatic detection
  final Map<String, Rect> _buttonBounds = {};

  // Text input state
  String _answerText = '';
  final ScrollController _scrollController = ScrollController();

  // CRITICAL FIX: Keys for getting actual widget positions
  final GlobalKey _keyboardContainerKey = GlobalKey();
  final GlobalKey _answerBoxKey = GlobalKey();
  final GlobalKey _submitButtonKey = GlobalKey();
  final GlobalKey _clearButtonKey = GlobalKey();

  // Flag to track if bounds have been calculated
  bool _boundsCalculated = false;

  @override
  void initState() {
    super.initState();
    print("DEBUG: TugasPage initState");
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.setActivePage('tugas_page', _onEyeTrackingUpdate);
    _initializeEyeTracking();
    _initializeStaticButtonBounds();

    // Calculate keyboard bounds after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateActualKeyboardBounds();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _scrollController.dispose();
    _eyeTrackingService.removePage('tugas_page');
    print("DEBUG: TugasPage disposed");
    super.dispose();
  }

  void _initializeStaticButtonBounds() {
    // Initialize non-keyboard button bounds (these will be updated with actual positions)
    _buttonBounds['back_button'] = const Rect.fromLTWH(20, 50, 50, 50);
    _buttonBounds['submit_button'] = const Rect.fromLTWH(50, 700, 300, 60);
    _buttonBounds['clear_button'] = const Rect.fromLTWH(260, 180, 100, 40);
  }

  // CRITICAL FIX: Calculate actual keyboard bounds using RenderBox
  void _calculateActualKeyboardBounds() {
    if (_isDisposed || !mounted) return;

    try {
      // Update actual positions for static buttons
      _updateButtonPosition('clear_button', _clearButtonKey);
      _updateButtonPosition('submit_button', _submitButtonKey);

      // Calculate keyboard bounds using the callback from EyeControlledKeyboard
      // This will be set up in the keyboard widget
      print("DEBUG: Triggering keyboard bounds calculation");

      // Mark bounds as calculated
      _boundsCalculated = true;

      // Debug: Print all calculated bounds
      _debugPrintBounds();
    } catch (e) {
      print("DEBUG: Error calculating bounds: $e");
    }
  }

  void _updateButtonPosition(String buttonId, GlobalKey key) {
    try {
      final RenderBox? renderBox =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        _buttonBounds[buttonId] = Rect.fromLTWH(
          position.dx,
          position.dy,
          size.width,
          size.height,
        );
        print("DEBUG: Updated $buttonId bounds: ${_buttonBounds[buttonId]}");
      }
    } catch (e) {
      print("DEBUG: Error updating $buttonId position: $e");
    }
  }

  // CRITICAL FIX: Callback to receive keyboard bounds from the keyboard widget
  void _onKeyboardBoundsCalculated(Map<String, Rect> keyboardBounds) {
    print("DEBUG: Received keyboard bounds: ${keyboardBounds.length} keys");

    // Update keyboard bounds
    _buttonBounds.addAll(keyboardBounds);

    // Debug print all bounds
    _debugPrintBounds();

    if (mounted) {
      setState(() {
        _boundsCalculated = true;
      });
    }
  }

  void _debugPrintBounds() {
    print("=== BUTTON BOUNDS DEBUG ===");
    _buttonBounds.forEach((key, rect) {
      print("$key: ${rect.toString()}");
    });
    print("Total bounds: ${_buttonBounds.length}");
    print("========================");
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
          title: const Text('Assignment Submitted!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Topic: ${widget.topic.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Your Answer:'),
              const SizedBox(height: 5),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
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
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Back to Topics'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _answerText = '';
                });
              },
              child: const Text('Start Over'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnswerBox() {
    final isCurrentlyDwelling = _currentDwellingElement == 'clear_button';

    return Container(
      key: _answerBoxKey,
      margin: const EdgeInsets.all(20),
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
              // Clear button with GlobalKey for position tracking
              Material(
                key: _clearButtonKey,
                elevation: isCurrentlyDwelling ? 4 : 1,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isCurrentlyDwelling
                        ? Colors.red.shade100
                        : Colors.grey.shade100,
                    border: Border.all(
                      color: isCurrentlyDwelling
                          ? Colors.red
                          : Colors.grey.shade300,
                      width: 1,
                    ),
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
            height: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
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

  Widget _buildSubmitButton() {
    final isCurrentlyDwelling = _currentDwellingElement == 'submit_button';
    final hasText = _answerText.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        key: _submitButtonKey,
        width: double.infinity,
        height: 50,
        child: Material(
          elevation: isCurrentlyDwelling ? 4 : 1,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: hasText
                  ? (isCurrentlyDwelling
                      ? Colors.blue.shade700
                      : Colors.blue.shade600)
                  : Colors.grey.shade300,
              border: Border.all(
                color: hasText ? Colors.blue.shade600 : Colors.grey.shade400,
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                if (isCurrentlyDwelling)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      height: 3,
                      width: (MediaQuery.of(context).size.width - 40) *
                          _dwellProgress,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Center(
                  child: Text(
                    hasText ? 'Submit Assignment' : 'Type your answer first',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: hasText ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                            'Tugas',
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
                  // Topic info
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.assignment,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.topic.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.subject.name,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                          // Answer input box
                          _buildAnswerBox(),
                          // Eye-controlled keyboard with bounds callback
                          Expanded(
                            child: Container(
                              key: _keyboardContainerKey,
                              child: EyeControlledKeyboard(
                                onKeyPressed: _onKeyPressed,
                                currentDwellingElement: _currentDwellingElement,
                                dwellProgress: _dwellProgress,
                                onBoundsCalculated:
                                    _onKeyboardBoundsCalculated, // NEW CALLBACK
                              ),
                            ),
                          ),
                          // Submit button
                          _buildSubmitButton(),
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
          StatusInfoWidget(
            statusMessage: _eyeTrackingService.statusMessage,
            currentPage: 4,
            totalPages: 4,
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            currentDwellingElement: _currentDwellingElement,
            dwellProgress: _dwellProgress,
          ),
          // Debug bounds visualization (remove in production)
          if (_boundsCalculated) _buildBoundsDebugOverlay(),
        ],
      ),
    );
  }

  // DEBUG: Visual overlay to show calculated bounds
  Widget _buildBoundsDebugOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: BoundsDebugPainter(_buttonBounds),
        ),
      ),
    );
  }
}

// DEBUG: Custom painter to visualize bounds
class BoundsDebugPainter extends CustomPainter {
  final Map<String, Rect> bounds;

  BoundsDebugPainter(this.bounds);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    bounds.forEach((key, rect) {
      canvas.drawRect(rect, paint);

      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(
          text: key,
          style: const TextStyle(color: Colors.red, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 15));
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
