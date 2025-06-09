// File: lib/pages/lecture_recorder_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/global_seeso_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';

class LectureRecorderPage extends StatefulWidget {
  const LectureRecorderPage({super.key});

  @override
  State<LectureRecorderPage> createState() => _LectureRecorderPageState();
}

class _LectureRecorderPageState extends State<LectureRecorderPage>
    with TickerProviderStateMixin {
  late GlobalSeesoService _eyeTrackingService;
  late stt.SpeechToText _speech;
  bool _isDisposed = false;
  bool _isInitialized = false;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration - 1.5 seconds
  static const int _dwellTimeMs = 1500;
  static const int _dwellUpdateIntervalMs = 50;

  // Button boundaries for automatic detection
  final Map<String, Rect> _buttonBounds = {};

  // Recording state
  bool _isRecording = false;
  bool _speechAvailable = false;
  bool _speechEnabled = false;
  String _transcribedText = '';
  String _currentWords = '';
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  // Notes storage
  final List<LectureNote> _savedNotes = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    print("DEBUG: LectureRecorderPage initState");

    _eyeTrackingService = GlobalSeesoService();
    _speech = stt.SpeechToText();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));

    // Delay initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _initializeAsync();
      }
    });
  }

  Future<void> _initializeAsync() async {
    if (_isDisposed || !mounted) return;

    try {
      _eyeTrackingService.setActivePage(
          'lecture_recorder', _onEyeTrackingUpdate);
      await _initializeEyeTracking();
      await _initializeSpeech();
      _initializeButtonBounds();

      setState(() {
        _isInitialized = true;
      });

      print("DEBUG: LectureRecorderPage initialization complete");
    } catch (e) {
      print("DEBUG: LectureRecorderPage initialization error: $e");
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _scrollController.dispose();

    _eyeTrackingService.removePage('lecture_recorder');

    print("DEBUG: LectureRecorderPage disposed");
    super.dispose();
  }

  void _initializeButtonBounds() {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    // FIXED: Separate bounds for record and stop buttons based on recording state
    // Back button
    _buttonBounds['back_button'] = const Rect.fromLTWH(20, 50, 50, 50);

    // Record button - only active when NOT recording
    _buttonBounds['record_button'] =
        Rect.fromLTWH(centerX - 60, centerY - 60, 120, 120);

    // Stop button - only active when recording (SAME POSITION but different ID)
    _buttonBounds['stop_button'] =
        Rect.fromLTWH(centerX - 60, centerY - 60, 120, 120);

    // Notes button
    _buttonBounds['notes_button'] =
        Rect.fromLTWH(screenSize.width - 80, 50, 60, 50);

    // Save note button
    _buttonBounds['save_note_button'] =
        Rect.fromLTWH(20, screenSize.height - 120, screenSize.width - 40, 50);

    print("DEBUG: Button bounds initialized for LectureRecorder");
    print("DEBUG: Record button bounds: ${_buttonBounds['record_button']}");
    print("DEBUG: Stop button bounds: ${_buttonBounds['stop_button']}");
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted || !_isInitialized) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    String? hoveredElement;

    // FIXED: Check only relevant buttons based on recording state
    if (_isRecording) {
      // When recording, only check stop button, back button, notes button
      final activeButtons = ['stop_button', 'back_button', 'notes_button'];
      if (_transcribedText.isNotEmpty) {
        activeButtons.add('save_note_button');
      }

      for (final buttonId in activeButtons) {
        final bounds = _buttonBounds[buttonId];
        if (bounds != null && bounds.contains(currentGazePoint)) {
          hoveredElement = buttonId;
          break;
        }
      }
    } else {
      // When not recording, only check record button, back button, notes button
      final activeButtons = ['record_button', 'back_button', 'notes_button'];
      if (_transcribedText.isNotEmpty) {
        activeButtons.add('save_note_button');
      }

      for (final buttonId in activeButtons) {
        final bounds = _buttonBounds[buttonId];
        if (bounds != null && bounds.contains(currentGazePoint)) {
          hoveredElement = buttonId;
          break;
        }
      }
    }

    if (hoveredElement != null) {
      if (_currentDwellingElement != hoveredElement) {
        print(
            "DEBUG: Hovering over: $hoveredElement (recording: $_isRecording)");
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

    switch (elementId) {
      case 'back_button':
        action = _goBack;
        break;
      case 'record_button':
        if (!_isRecording) {
          action = _startRecording;
        } else {
          return; // Should not happen due to filtering in _onEyeTrackingUpdate
        }
        break;
      case 'stop_button':
        if (_isRecording) {
          action = _stopRecording;
          print("DEBUG: Stop button action assigned");
        } else {
          return; // Should not happen due to filtering in _onEyeTrackingUpdate
        }
        break;
      case 'notes_button':
        action = _showNotes;
        break;
      case 'save_note_button':
        if (_transcribedText.isNotEmpty) {
          action = _saveNote;
        } else {
          return;
        }
        break;
      default:
        print("DEBUG: Unknown element: $elementId");
        return;
    }

    _startDwellTimer(elementId, action);
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

  Future<void> _initializeSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          if (mounted) {
            setState(() {
              _speechEnabled = status == 'listening';
            });
          }
        },
        onError: (error) {
          print('Speech error: $error');
          if (mounted) {
            setState(() {
              _speechEnabled = false;
            });
          }
        },
      );

      if (mounted) {
        setState(() {});
      }

      print('Speech to text available: $_speechAvailable');
    } catch (e) {
      print('Speech initialization error: $e');
      _speechAvailable = false;
      if (mounted) {
        setState(() {});
      }
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

    print("DEBUG: Starting dwell timer for: $elementId");
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

    if (_isRecording) {
      _stopRecording();
    }

    Navigator.of(context).pop();
  }

  void _startRecording() {
    if (_isDisposed || !mounted || _isRecording) return;
    _stopDwellTimer();

    print("DEBUG: Starting recording...");

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Speech recognition not available - Recording simulation mode'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
      _transcribedText = '';
      _currentWords = '';
    });

    // Start animations
    _pulseController.repeat(reverse: true);
    _waveController.repeat(reverse: true);

    // Start recording timer
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      setState(() {
        _recordingDuration =
            Duration(seconds: _recordingDuration.inSeconds + 1);
      });
    });

    // Start speech recognition if available
    if (_speechAvailable) {
      _speech.listen(
        onResult: (result) {
          if (mounted && _isRecording) {
            setState(() {
              _transcribedText = result.recognizedWords;
              _currentWords = result.recognizedWords;
            });
          }
        },
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'id_ID',
      );
    } else {
      // Simulation mode
      Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!_isRecording || _isDisposed) {
          timer.cancel();
          return;
        }

        final sampleTexts = [
          "Hari ini kita akan mempelajari tentang matematika dasar.",
          "Perhatikan contoh soal yang ada di papan tulis.",
          "Siapa yang bisa menjawab pertanyaan ini?",
          "Mari kita lanjutkan ke materi selanjutnya.",
        ];

        if (mounted) {
          setState(() {
            _transcribedText +=
                " " + sampleTexts[timer.tick % sampleTexts.length];
          });
        }
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_speechAvailable
            ? 'Recording started!'
            : 'Recording started in simulation mode!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _stopRecording() {
    if (_isDisposed || !mounted || !_isRecording) return;
    _stopDwellTimer();

    print("DEBUG: Stopping recording...");

    setState(() {
      _isRecording = false;
      _speechEnabled = false;
    });

    // Stop animations
    _pulseController.stop();
    _waveController.stop();

    // Stop timers
    _recordingTimer?.cancel();
    _recordingTimer = null;

    // Stop speech recognition
    if (_speechAvailable) {
      _speech.stop();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Recording stopped! Duration: ${_formatDuration(_recordingDuration)}'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _saveNote() {
    if (_isDisposed || !mounted || _transcribedText.isEmpty) return;
    _stopDwellTimer();

    final note = LectureNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Lecture ${_savedNotes.length + 1}',
      content: _transcribedText,
      duration: _recordingDuration,
      timestamp: DateTime.now(),
    );

    setState(() {
      _savedNotes.add(note);
      _transcribedText = '';
      _recordingDuration = Duration.zero;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note saved successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showNotes() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotesModal(),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Widget _buildRecordButton() {
    // FIXED: Show record button only when not recording
    if (_isRecording) return const SizedBox.shrink();

    final isCurrentlyDwelling = _currentDwellingElement == 'record_button';

    return AnimatedBuilder(
      animation: const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Transform.scale(
          scale: isCurrentlyDwelling ? 1.1 : 1.0,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.shade600,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                if (isCurrentlyDwelling)
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: _dwellProgress,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                const Center(
                  child: Icon(
                    Icons.mic,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStopButton() {
    // FIXED: Show stop button only when recording
    if (!_isRecording) return const SizedBox.shrink();

    final isCurrentlyDwelling = _currentDwellingElement == 'stop_button';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value * (isCurrentlyDwelling ? 1.1 : 1.0),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade600,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                if (isCurrentlyDwelling)
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: _dwellProgress,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                const Center(
                  child: Icon(
                    Icons.stop,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTranscriptionBox() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.transcribe, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text(
                'Live Transcription',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isRecording)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_recordingDuration),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Text(
                  _transcribedText.isEmpty
                      ? (_isRecording
                          ? 'Listening... Start speaking to see transcription here.'
                          : 'Press the record button to start recording.')
                      : _transcribedText,
                  style: TextStyle(
                    fontSize: 14,
                    color: _transcribedText.isEmpty
                        ? Colors.grey.shade500
                        : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          if (_transcribedText.isNotEmpty && !_isRecording) ...[
            const SizedBox(height: 12),
            _buildSaveNoteButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveNoteButton() {
    final isCurrentlyDwelling = _currentDwellingElement == 'save_note_button';

    return Container(
      width: double.infinity,
      height: 50,
      child: Material(
        elevation: isCurrentlyDwelling ? 4 : 2,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isCurrentlyDwelling
                ? Colors.green.shade700
                : Colors.green.shade600,
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
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Save Note',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildNotesModal() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.note, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Saved Notes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_savedNotes.length} notes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _savedNotes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_add, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No notes saved yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Record a lecture to create your first note',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _savedNotes.length,
                    itemBuilder: (context, index) {
                      final note = _savedNotes[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  note.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDuration(note.duration),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${note.timestamp.day}/${note.timestamp.month}/${note.timestamp.year} '
                              '${note.timestamp.hour.toString().padLeft(2, '0')}:'
                              '${note.timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              note.content,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Lecture Recorder...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
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
                            'Lecture Recorder',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        GestureDetector(
                          onTap: _showNotes,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                const Icon(
                                  Icons.note,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                if (_savedNotes.isNotEmpty)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        '${_savedNotes.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status indicators
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _speechAvailable ? Icons.mic : Icons.mic_off,
                          color: _speechAvailable ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _speechAvailable
                              ? 'Speech Recognition Ready'
                              : 'Speech Recognition Unavailable',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        if (_isRecording) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'REC ${_formatDuration(_recordingDuration)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
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
                          const SizedBox(height: 40),
                          // Record/Stop button area - FIXED: Show appropriate button
                          SizedBox(
                            height: 200,
                            child: Center(
                              child: Stack(
                                children: [
                                  _buildRecordButton(),
                                  _buildStopButton(),
                                ],
                              ),
                            ),
                          ),
                          // Instructions
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _isRecording
                                  ? 'Look at the red stop button for 1.5 seconds to stop recording'
                                  : 'Look at the blue record button for 1.5 seconds to start recording',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Transcription box
                          Expanded(
                            child: _buildTranscriptionBox(),
                          ),
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
            currentPage: 5,
            totalPages: 5,
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

// Data model for lecture notes
class LectureNote {
  final String id;
  final String title;
  final String content;
  final Duration duration;
  final DateTime timestamp;

  LectureNote({
    required this.id,
    required this.title,
    required this.content,
    required this.duration,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'duration': duration.inSeconds,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LectureNote.fromJson(Map<String, dynamic> json) {
    return LectureNote(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      duration: Duration(seconds: json['duration']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
