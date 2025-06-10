// File: lib/pages/lecture_recorder_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../services/global_seeso_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import '../mixins/responsive_bounds_mixin.dart';
import '../models/lecture_note.dart';
import 'saved_notes_page.dart';

class LectureRecorderPage extends StatefulWidget {
  const LectureRecorderPage({super.key});

  @override
  State<LectureRecorderPage> createState() => _LectureRecorderPageState();
}

class _LectureRecorderPageState extends State<LectureRecorderPage>
    with ResponsiveBoundsMixin, TickerProviderStateMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration
  static const int _controlDwellTimeMs = 1000;
  static const int _buttonDwellTimeMs = 1500;
  static const int _dwellUpdateIntervalMs = 50;

  // Recording state
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;

  // Speech-to-text simulation
  String _transcriptionText = '';
  Timer? _transcriptionTimer;
  final List<String> _sampleWords = [
    'Today',
    'we',
    'will',
    'discuss',
    'the',
    'fundamental',
    'concepts',
    'of',
    'mathematics',
    'including',
    'algebra',
    'geometry',
    'and',
    'calculus',
    'These',
    'topics',
    'are',
    'essential',
    'for',
    'understanding',
    'advanced',
    'mathematical',
    'principles',
    'Let',
    'us',
    'begin',
    'with',
    'basic',
    'equations',
    'and',
    'their',
    'solutions',
    'Remember',
    'to',
    'take',
    'notes',
    'and',
    'ask',
    'questions',
    'if',
    'anything',
    'is',
    'unclear',
    'Practice',
    'makes',
    'perfect',
    'in',
    'mathematics',
    'education'
  ];
  int _currentWordIndex = 0;

  // Saved notes
  final List<LectureNote> _savedNotes = [];

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Override mixin configuration
  @override
  double get boundsUpdateDelay => 150.0;

  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    print("DEBUG: LectureRecorderPage initState");
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.setActivePage('lecture_recorder', _onEyeTrackingUpdate);

    // Initialize animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _initializeElementKeys();
    _initializeEyeTracking();
    updateBoundsAfterBuild();
  }

  void _initializeElementKeys() {
    // Generate keys for recording controls
    generateKeyForElement('record_button');
    generateKeyForElement('pause_button');
    generateKeyForElement('stop_button');
    generateKeyForElement('save_button');
    generateKeyForElement('clear_button');
    generateKeyForElement('saved_notes_button');

    print("DEBUG: Generated ${elementCount} element keys using mixin");
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _recordingTimer?.cancel();
    _transcriptionTimer?.cancel();
    _pulseController.dispose();

    _eyeTrackingService.removePage('lecture_recorder');
    clearBounds();

    print("DEBUG: LectureRecorderPage disposed");
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateBoundsAfterBuild();
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    String? hoveredElement = getElementAtPoint(currentGazePoint);

    if (hoveredElement != null) {
      if (_currentDwellingElement != hoveredElement) {
        print(
            "DEBUG: LectureRecorderPage - Started dwelling on: $hoveredElement");
        _handleElementHover(hoveredElement);
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

  void _handleElementHover(String elementId) {
    VoidCallback action;
    int dwellTime = _buttonDwellTimeMs;

    switch (elementId) {
      case 'record_button':
        if (!_isRecording) {
          action = _startRecording;
          dwellTime = _controlDwellTimeMs;
        } else {
          return; // Don't allow starting when already recording
        }
        break;
      case 'pause_button':
        if (_isRecording && !_isPaused) {
          action = _pauseRecording;
          dwellTime = _controlDwellTimeMs;
        } else if (_isRecording && _isPaused) {
          action = _resumeRecording;
          dwellTime = _controlDwellTimeMs;
        } else {
          return;
        }
        break;
      case 'stop_button':
        if (_isRecording) {
          action = _stopRecording;
          dwellTime = _controlDwellTimeMs;
        } else {
          return;
        }
        break;
      case 'save_button':
        if (!_isRecording && _transcriptionText.isNotEmpty) {
          action = _saveNote;
        } else {
          return;
        }
        break;
      case 'clear_button':
        if (!_isRecording) {
          action = _clearTranscription;
        } else {
          return;
        }
        break;
      case 'saved_notes_button':
        action = _navigateToSavedNotes;
        break;
      default:
        return;
    }

    _startDwellTimer(elementId, action, dwellTime);
  }

  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;

    try {
      print("DEBUG: Initializing eye tracking in LectureRecorderPage");
      await _eyeTrackingService.initialize(context);
      print(
          "DEBUG: Eye tracking successfully initialized in LectureRecorderPage");
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
    if (mounted && !_isDisposed) {
      setState(() {
        _currentDwellingElement = null;
        _dwellProgress = 0.0;
      });
    }
  }

  void _startRecording() {
    if (_isDisposed || !mounted || _isRecording) return;
    _stopDwellTimer();

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _transcriptionText = '';
      _currentWordIndex = 0;
    });

    _recordingStartTime = DateTime.now();

    // Start recording timer
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording || _isPaused) return;

      if (mounted && !_isDisposed) {
        setState(() {
          _recordingDuration = DateTime.now().difference(_recordingStartTime!);
        });
      }
    });

    // Start transcription simulation
    _startTranscriptionSimulation();

    // Start pulse animation
    _pulseController.repeat(reverse: true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording started'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _pauseRecording() {
    if (_isDisposed || !mounted || !_isRecording || _isPaused) return;
    _stopDwellTimer();

    setState(() {
      _isPaused = true;
    });

    _transcriptionTimer?.cancel();
    _pulseController.stop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording paused'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _resumeRecording() {
    if (_isDisposed || !mounted || !_isRecording || !_isPaused) return;
    _stopDwellTimer();

    setState(() {
      _isPaused = false;
    });

    _startTranscriptionSimulation();
    _pulseController.repeat(reverse: true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording resumed'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _stopRecording() {
    if (_isDisposed || !mounted || !_isRecording) return;
    _stopDwellTimer();

    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    _recordingTimer?.cancel();
    _transcriptionTimer?.cancel();
    _pulseController.stop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recording stopped'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _startTranscriptionSimulation() {
    _transcriptionTimer = Timer.periodic(
      Duration(
          milliseconds: 800 + Random().nextInt(1200)), // 0.8-2.0s intervals
      (timer) {
        if (!_isRecording || _isPaused || _isDisposed || !mounted) {
          timer.cancel();
          return;
        }

        if (_currentWordIndex < _sampleWords.length) {
          setState(() {
            if (_transcriptionText.isNotEmpty) {
              _transcriptionText += ' ';
            }
            _transcriptionText += _sampleWords[_currentWordIndex];
            _currentWordIndex++;
          });
        } else {
          timer.cancel();
        }
      },
    );
  }

  void _saveNote() {
    if (_isDisposed || !mounted || _transcriptionText.isEmpty) return;
    _stopDwellTimer();

    final note = LectureNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title:
          'Lecture ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      content: _transcriptionText,
      duration: _recordingDuration,
      timestamp: DateTime.now(),
    );

    setState(() {
      _savedNotes.add(note);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note saved successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _clearTranscription() {
    if (_isDisposed || !mounted || _isRecording) return;
    _stopDwellTimer();

    setState(() {
      _transcriptionText = '';
      _recordingDuration = Duration.zero;
      _currentWordIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcription cleared'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _navigateToSavedNotes() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    // Don't navigate if currently recording
    if (_isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stop recording before accessing saved notes'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _eyeTrackingService.removePage('lecture_recorder');

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => SavedNotesPage(savedNotes: _savedNotes),
      ),
    )
        .then((_) {
      if (!_isDisposed && mounted) {
        _eyeTrackingService.setActivePage(
            'lecture_recorder', _onEyeTrackingUpdate);
        updateBoundsAfterBuild();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Widget _buildControlButton({
    required String elementId,
    required IconData icon,
    required String label,
    required Color color,
    required bool isEnabled,
    double size = 80.0,
  }) {
    final isCurrentlyDwelling = _currentDwellingElement == elementId;
    final key = generateKeyForElement(elementId);

    return Container(
      key: key,
      width: size,
      height: size,
      margin: const EdgeInsets.all(8),
      child: Material(
        elevation: isCurrentlyDwelling ? 8 : (isEnabled ? 4 : 1),
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
            color: isEnabled
                ? (isCurrentlyDwelling ? color.withOpacity(0.8) : color)
                : Colors.grey.shade300,
            border: Border.all(
              color: isCurrentlyDwelling
                  ? Colors.white
                  : (isEnabled ? color.withOpacity(0.5) : Colors.grey.shade400),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              if (isCurrentlyDwelling && isEnabled)
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: _dwellProgress,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: (_isRecording &&
                                  elementId == 'record_button' &&
                                  !_isPaused)
                              ? _pulseAnimation.value
                              : 1.0,
                          child: Icon(
                            icon,
                            color:
                                isEnabled ? Colors.white : Colors.grey.shade600,
                            size: size * 0.35,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: isEnabled ? Colors.white : Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isRecording
            ? (_isPaused ? Colors.orange.shade50 : Colors.green.shade50)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isRecording
              ? (_isPaused ? Colors.orange.shade300 : Colors.green.shade300)
              : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _isRecording
                      ? (_isPaused ? Colors.orange : Colors.green)
                      : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _isRecording
                    ? (_isPaused ? 'Recording Paused' : 'Recording Active')
                    : 'Ready to Record',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isRecording
                      ? (_isPaused
                          ? Colors.orange.shade800
                          : Colors.green.shade800)
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Words Transcribed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_transcriptionText.split(' ').where((word) => word.isNotEmpty).length}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionArea() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Live Transcription',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  key: generateKeyForElement('saved_notes_button'),
                  child: Material(
                    elevation:
                        _currentDwellingElement == 'saved_notes_button' ? 4 : 2,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _currentDwellingElement == 'saved_notes_button'
                            ? Colors.blue.shade50
                            : Colors.white,
                        border: Border.all(
                          color: _currentDwellingElement == 'saved_notes_button'
                              ? Colors.blue.shade300
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (_currentDwellingElement == 'saved_notes_button')
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 2,
                                child: LinearProgressIndicator(
                                  value: _dwellProgress,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue.shade600),
                                ),
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder,
                                size: 16,
                                color: _currentDwellingElement ==
                                        'saved_notes_button'
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Saved Notes (${_savedNotes.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _currentDwellingElement ==
                                          'saved_notes_button'
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                child: SingleChildScrollView(
                  child: Text(
                    _transcriptionText.isEmpty
                        ? 'Transcription will appear here when recording starts...'
                        : _transcriptionText,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: _transcriptionText.isEmpty
                          ? Colors.grey.shade500
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    elementId: 'save_button',
                    icon: Icons.save,
                    label: 'Save',
                    color: Colors.green,
                    isEnabled: !_isRecording && _transcriptionText.isNotEmpty,
                    size: 60,
                  ),
                ),
                Expanded(
                  child: _buildControlButton(
                    elementId: 'clear_button',
                    icon: Icons.clear,
                    label: 'Clear',
                    color: Colors.orange,
                    isEnabled: !_isRecording,
                    size: 60,
                  ),
                ),
              ],
            ),
          ],
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF667EEA),
                  Color(0xFF764BA2),
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Lecture Recorder',
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
                          // Recording status
                          _buildStatusCard(),

                          // Recording controls
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildControlButton(
                                  elementId: 'record_button',
                                  icon: _isRecording
                                      ? Icons.fiber_manual_record
                                      : Icons.mic,
                                  label: _isRecording ? 'Recording' : 'Record',
                                  color:
                                      _isRecording ? Colors.red : Colors.green,
                                  isEnabled: !_isRecording,
                                ),
                                _buildControlButton(
                                  elementId: 'pause_button',
                                  icon: _isPaused
                                      ? Icons.play_arrow
                                      : Icons.pause,
                                  label: _isPaused ? 'Resume' : 'Pause',
                                  color: Colors.orange,
                                  isEnabled: _isRecording,
                                ),
                                _buildControlButton(
                                  elementId: 'stop_button',
                                  icon: Icons.stop,
                                  label: 'Stop',
                                  color: Colors.red,
                                  isEnabled: _isRecording,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Transcription area
                          _buildTranscriptionArea(),
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
            currentPage: 2,
            totalPages: 3,
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            currentDwellingElement: _currentDwellingElement,
            dwellProgress: _dwellProgress,
          ),
        ],
      ),
    );
  }
}
