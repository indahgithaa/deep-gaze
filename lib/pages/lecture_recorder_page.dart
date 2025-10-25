// File: lib/pages/lecture_recorder_page.dart
import 'package:flutter/material.dart';
import 'package:whisper_flutter_new/download_model.dart';
import 'dart:async';

import '../services/global_seeso_service.dart';
import '../widgets/status_info_widget.dart';
import '../mixins/responsive_bounds_mixin.dart';
import '../models/lecture_note.dart';
import 'saved_notes_page.dart';
import '../widgets/nav_gaze_bridge.dart';
import '../widgets/gaze_overlay_manager.dart';

// STT on-device (Whisper)
import '../services/stt/speech_engine.dart';
import '../services/stt/whisper_speech_engine.dart';

class LectureRecorderPage extends StatefulWidget {
  const LectureRecorderPage({super.key});

  @override
  State<LectureRecorderPage> createState() => _LectureRecorderPageState();
}

class _LectureRecorderPageState extends State<LectureRecorderPage>
    with ResponsiveBoundsMixin, TickerProviderStateMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  static const int _controlDwellTimeMs = 1000;
  static const int _buttonDwellTimeMs = 1500;
  static const int _dwellUpdateIntervalMs = 50;

  // Recording
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;

  // STT
  late final SpeechEngine _stt;
  bool _sttAvailable = false;
  String _transcriptionText = '';

  // Saved notes
  final List<LectureNote> _savedNotes = [];

  // Pulse anim
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  double get boundsUpdateDelay => 150.0;
  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.setActivePage('lecture_recorder', _onEyeTrackingUpdate);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // init Whisper engine (offline, Bahasa Indonesia)
    _stt = WhisperSpeechEngine(
      model: WhisperModel.small, // small: balance speed/accuracy utk ID
      chunkSecs: 8,
      language: 'id',
      translateToEnglish: false,
    );

    _initializeElementKeys();
    _initializeEyeTracking();
    _initStt();
    updateBoundsAfterBuild();
  }

  Future<void> _initStt() async {
    final ok = await _stt.init();
    if (!mounted) return;
    setState(() => _sttAvailable = ok);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Whisper offline belum siap (model/izin).'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _initializeElementKeys() {
    generateKeyForElement('record_button');
    generateKeyForElement('pause_button');
    generateKeyForElement('stop_button');
    generateKeyForElement('save_button');
    generateKeyForElement('clear_button');
    generateKeyForElement('saved_notes_button');
  }

  void _initializeEyeTracking() {
    // Ensure the eye-tracking service is subscribed for this page and bounds are updated.
    // Calling setActivePage again is idempotent and ensures the callback is registered.
    try {
      _eyeTrackingService.setActivePage(
          'lecture_recorder', _onEyeTrackingUpdate);
      // Make sure bounds are updated after making tracking active
      updateBoundsAfterBuild();
    } catch (_) {
      // If the service isn't ready for some reason, ignore the error to avoid crashes.
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _recordingTimer?.cancel();
    _pulseController.dispose();

    _stt.stop();

    _eyeTrackingService.removePage('lecture_recorder');
    clearBounds();
    GazeOverlayManager.instance.hide();
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

    NavGazeBridge.instance
        .update(currentGazePoint, _eyeTrackingService.isTracking);

    GazeOverlayManager.instance.update(
      cursor: currentGazePoint,
      visible: _eyeTrackingService.isTracking,
      highlight: null,
    );

    final hovered = getElementAtPoint(currentGazePoint);
    if (hovered != null) {
      if (_currentDwellingElement != hovered) _handleElementHover(hovered);
    } else if (_currentDwellingElement != null) {
      _stopDwellTimer();
    }

    if (mounted && !_isDisposed) setState(() {});
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
          return;
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
        if (!_isRecording && _transcriptionText.trim().isNotEmpty) {
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

  void _startDwellTimer(
      String elementId, VoidCallback action, int dwellTimeMs) {
    if (_isDisposed || !mounted) return;
    if (_currentDwellingElement == elementId) return;
    _stopDwellTimer();
    setState(() {
      _currentDwellingElement = elementId;
      _dwellProgress = 0.0;
    });

    _dwellStartTime = DateTime.now();
    _dwellTimer = Timer.periodic(
      const Duration(milliseconds: _dwellUpdateIntervalMs),
      (t) {
        if (_isDisposed || !mounted || _currentDwellingElement != elementId) {
          t.cancel();
          return;
        }
        final elapsed =
            DateTime.now().difference(_dwellStartTime!).inMilliseconds;
        final progress = (elapsed / dwellTimeMs).clamp(0.0, 1.0);
        setState(() {
          _dwellProgress = progress;
        });
        if (progress >= 1.0) {
          t.cancel();
          action();
        }
      },
    );
  }

  void _stopDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    setState(() {
      _currentDwellingElement = null;
      _dwellProgress = 0.0;
    });
  }

  // ====== RECORD CONTROL ======

  void _startRecording() async {
    if (_isDisposed || !mounted || _isRecording) return;
    _stopDwellTimer();

    if (!_sttAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Whisper offline belum siap.'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _transcriptionText = '';
    });

    _recordingStartTime = DateTime.now();
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRecording || _isPaused) return;
      setState(() {
        _recordingDuration = DateTime.now().difference(_recordingStartTime!);
      });
    });

    await _stt.start(
      onPartial: (p) {}, // Whisper file-based -> kita pakai onFinal tiap slice
      onFinal: (r) {
        if (!mounted) return;
        setState(() {
          if (_transcriptionText.isNotEmpty &&
              !_transcriptionText.trim().endsWith('\n')) {
            _transcriptionText += '\n';
          }
          _transcriptionText += r;
        });
      },
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('STT error: $e'), backgroundColor: Colors.orange),
        );
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Recording started (offline Whisper)'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1)));
  }

  void _pauseRecording() async {
    if (_isDisposed || !mounted || !_isRecording || _isPaused) return;
    _stopDwellTimer();
    setState(() {
      _isPaused = true;
    });
    await _stt.pause();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Recording paused'), backgroundColor: Colors.orange));
  }

  void _resumeRecording() async {
    if (_isDisposed || !mounted || !_isRecording || !_isPaused) return;
    _stopDwellTimer();
    setState(() {
      _isPaused = false;
    });
    await _stt.resume();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Recording resumed'), backgroundColor: Colors.green));
  }

  void _stopRecording() async {
    if (_isDisposed || !mounted || !_isRecording) return;
    _stopDwellTimer();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
    _recordingTimer?.cancel();
    await _stt.stop();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Recording stopped'), backgroundColor: Colors.red));
  }

  void _saveNote() {
    if (_transcriptionText.trim().isEmpty) return;
    _stopDwellTimer();
    final note = LectureNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title:
          'Lecture ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      content: _transcriptionText.trim(),
      duration: _recordingDuration,
      timestamp: DateTime.now(),
    );
    setState(() {
      _savedNotes.add(note);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Note saved successfully'),
        backgroundColor: Colors.green));
  }

  void _clearTranscription() {
    if (_isRecording) return;
    _stopDwellTimer();
    setState(() {
      _transcriptionText = '';
      _recordingDuration = Duration.zero;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Transcription cleared'),
        backgroundColor: Colors.orange));
  }

  void _navigateToSavedNotes() {
    if (_isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stop recording before accessing saved notes'),
          backgroundColor: Colors.orange));
      return;
    }
    _eyeTrackingService.removePage('lecture_recorder');
    Navigator.of(context)
        .push(
      MaterialPageRoute(
          builder: (_) => SavedNotesPage(savedNotes: _savedNotes)),
    )
        .then((_) {
      if (!_isDisposed && mounted) {
        _eyeTrackingService.setActivePage(
            'lecture_recorder', _onEyeTrackingUpdate);
        updateBoundsAfterBuild();
      }
    });
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  Widget _buildControlButton({
    required String elementId,
    required IconData icon,
    required String label,
    required Color color,
    required bool isEnabled,
    double size = 80.0,
  }) {
    final isDwelling = _currentDwellingElement == elementId;
    final key = generateKeyForElement(elementId);
    final dynamicScale =
        (_isRecording && !_isPaused && elementId == 'record_button')
            ? (1.0 + (_stt.soundLevel.clamp(0.0, 1.0) * 0.25))
            : 1.0;

    return Container(
      key: key,
      width: size,
      height: size,
      margin: const EdgeInsets.all(8),
      child: Material(
        elevation: isDwelling ? 8 : (isEnabled ? 4 : 1),
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
            color: isEnabled
                ? (isDwelling ? color.withOpacity(0.8) : color)
                : Colors.grey.shade300,
            border: Border.all(
              color: isDwelling
                  ? Colors.white
                  : (isEnabled ? color.withOpacity(0.5) : Colors.grey.shade400),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              if (isDwelling && isEnabled)
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
                        final baseScale = (_isRecording &&
                                elementId == 'record_button' &&
                                !_isPaused)
                            ? _pulseAnimation.value
                            : 1.0;
                        return Transform.scale(
                          scale: baseScale * dynamicScale,
                          child: Icon(icon,
                              color: isEnabled
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              size: size * 0.35),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                          color:
                              isEnabled ? Colors.white : Colors.grey.shade600,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
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
    final wordsCount = _transcriptionText
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .length;

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
            width: 2),
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _isRecording
                      ? (_isPaused ? Colors.orange : Colors.green)
                      : (_sttAvailable ? Colors.grey : Colors.red),
                  shape: BoxShape.circle,
                )),
            const SizedBox(width: 12),
            Text(
              _isRecording
                  ? (_isPaused ? 'Recording Paused' : 'Recording Active')
                  : (_sttAvailable
                      ? 'Ready to Record (offline, Whisper)'
                      : 'Offline STT not available'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isRecording
                    ? (_isPaused
                        ? Colors.orange.shade800
                        : Colors.green.shade800)
                    : (_sttAvailable
                        ? Colors.grey.shade700
                        : Colors.red.shade700),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Duration',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
                Text(_formatDuration(_recordingDuration),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            )),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Words Transcribed',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
                Text('$wordsCount',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            )),
          ]),
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
            Row(children: [
              const Text('Live Transcription',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const Spacer(),
              Container(
                key: generateKeyForElement('saved_notes_button'),
                child: Material(
                  elevation:
                      _currentDwellingElement == 'saved_notes_button' ? 4 : 2,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            child: SizedBox(
                              height: 2,
                              child: LinearProgressIndicator(
                                value: _dwellProgress,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue.shade600),
                              ),
                            ),
                          ),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.folder,
                              size: 16,
                              color: _currentDwellingElement ==
                                      'saved_notes_button'
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade600),
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
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
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
                        offset: const Offset(0, 2))
                  ],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _transcriptionText.isEmpty
                        ? (_sttAvailable
                            ? 'Mulai rekam — transkripsi offline (Whisper) akan muncul tiap beberapa detik...'
                            : 'Offline STT tidak tersedia. Pastikan izin mikrofon & model terunduh.')
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
            Row(children: [
              Expanded(
                child: _buildControlButton(
                    elementId: 'save_button',
                    icon: Icons.save,
                    label: 'Save',
                    color: Colors.green,
                    isEnabled: !_isRecording && _transcriptionText.isNotEmpty,
                    size: 60),
              ),
              Expanded(
                child: _buildControlButton(
                    elementId: 'clear_button',
                    icon: Icons.clear,
                    label: 'Clear',
                    color: Colors.orange,
                    isEnabled: !_isRecording,
                    size: 60),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
          ),
          child: SafeArea(
            child: Column(children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child:
                        const Icon(Icons.menu, color: Colors.white, size: 20),
                  ),
                  const Expanded(
                    child: Text('Lecture Recorder (Offline Whisper)',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                        textAlign: TextAlign.center),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.visibility,
                        color: Colors.blue, size: 20),
                  ),
                ]),
              ),

              // Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20)),
                  ),
                  child: Column(children: [
                    _buildStatusCard(),
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
                              color: _isRecording ? Colors.red : Colors.green,
                              isEnabled: !_isRecording && _sttAvailable,
                            ),
                            _buildControlButton(
                              elementId: 'pause_button',
                              icon: _isPaused ? Icons.play_arrow : Icons.pause,
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
                          ]),
                    ),
                    const SizedBox(height: 20),
                    _buildTranscriptionArea(),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
