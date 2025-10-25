// File: lib/services/stt/whisper_speech_engine.dart
import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'speech_engine.dart';

/// Whisper is non-streaming. We emulate "live" by recording short segments
/// (2-3s), immediately transcribing each segment in the background, and
/// appending the text to UI. This avoids huge files and 30s-crash issues.
///
/// Key points:
/// - Rotating files: stop -> emit segment -> start next segment quickly
/// - Concurrency guard: transcribe queue processed one-by-one
/// - Small/base model for lower RAM usage
/// - Works offline after first model download
class WhisperSpeechEngine implements SpeechEngine {
  WhisperSpeechEngine({
    this.model = WhisperModel
        .base, // use base for stability; tiny is faster but less accurate
    this.segmentSeconds = 3, // “near-live” latency
    this.language = 'id', // Indonesian
    this.translateToEnglish = false,
  }) : assert(segmentSeconds >= 2 && segmentSeconds <= 10);

  final WhisperModel model;
  final int segmentSeconds;
  final String language;
  final bool translateToEnglish;

  final _recorder = AudioRecorder();
  Whisper? _whisper;

  bool _available = false;
  bool _isRecording = false;
  bool _isPaused = false;

  Timer? _rotateTimer;
  Directory? _tmpDir;

  // current active segment (being recorded)
  String? _currentSegPath;

  // queue of closed segments waiting to be transcribed
  final List<String> _pending = <String>[];
  bool _isTranscribing = false;

  double _soundLevel = 0.0;
  @override
  double get soundLevel => _soundLevel;

  @override
  bool get available => _available;

  @override
  Future<bool> init() async {
    _whisper = Whisper(
      model: model,
      downloadHost: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
    );

    // Don’t fail init just because the model isn’t downloaded yet.
    try {
      await _whisper!.getVersion();
    } catch (_) {
      // ignore — model will be pulled on first transcribe if not cached
    }

    _tmpDir = await getTemporaryDirectory();
    _available = true;
    return true;
  }

  @override
  Future<void> start({
    void Function(String partial)?
        onPartial, // Whisper can't yield true partials
    void Function(String result)? onFinal,
    void Function(Object error)? onError,
  }) async {
    if (!_available || _isRecording) return;

    // mic permission via `record`
    if (!await _recorder.hasPermission()) {
      onError?.call(StateError('Mic permission denied'));
      return;
    }

    _isRecording = true;
    _isPaused = false;

    // start first fresh segment
    await _startNewSegment(onError);

    // rotate every N seconds
    _rotateTimer?.cancel();
    _rotateTimer = Timer.periodic(Duration(seconds: segmentSeconds), (_) async {
      if (!_isRecording || _isPaused) return;
      try {
        // little “VU meter” bump for UI pulse
        _soundLevel = 0.9;
        Future.delayed(
            const Duration(milliseconds: 200), () => _soundLevel = 0.2);

        await _rotateSegment(onError);
        // kick background worker
        _drainQueue(onFinal, onError);
      } catch (e) {
        onError?.call(e);
      }
    });
  }

  Future<void> _startNewSegment(
    void Function(Object error)? onError,
  ) async {
    try {
      _currentSegPath =
          '${_tmpDir!.path}/dgz_${DateTime.now().millisecondsSinceEpoch}.wav';
      final cfg = RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000,
        numChannels: 1,
      );
      await _recorder.start(cfg, path: _currentSegPath!);
    } catch (e) {
      onError?.call(e);
    }
  }

  Future<void> _rotateSegment(
    void Function(Object error)? onError,
  ) async {
    // stop current
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      onError?.call(e);
    }

    // enqueue the finished file for transcription
    if (_currentSegPath != null) {
      final f = File(_currentSegPath!);
      if (await f.exists() && await f.length() > 44) {
        // >44 bytes to avoid empty WAV header-only
        _pending.add(_currentSegPath!);
      } else {
        // delete empty file
        try {
          await f.delete();
        } catch (_) {}
      }
    }

    // start next segment ASAP to keep recording continuous
    await _startNewSegment(onError);
  }

  void _drainQueue(
    void Function(String result)? onFinal,
    void Function(Object error)? onError,
  ) {
    if (_isTranscribing) return;
    _isTranscribing = true;

    Future<void>(() async {
      while (_pending.isNotEmpty) {
        final path = _pending.removeAt(0);
        try {
          final text = await _transcribe(path);
          final t = text.trim();
          if (t.isNotEmpty) onFinal?.call(t);
        } catch (e) {
          onError?.call(e);
        } finally {
          try {
            await File(path).delete();
          } catch (_) {}
        }
      }
      _isTranscribing = false;
    });
  }

  Future<String> _transcribe(String wavPath) async {
    final resp = await _whisper!.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: wavPath,
        isTranslate: translateToEnglish,
        isNoTimestamps: true,
        language: language,
        splitOnWord: false,
      ),
    );

    // ---- Safe extract text from WhisperTranscribeResponse ----
    String _extract(dynamic r) {
      try {
        final text1 = (r.text ?? r.result?.text ?? '').toString();
        if (text1.isNotEmpty) return text1;
        final segs = r.result?.segments;
        if (segs is List) {
          final joined = segs.map((s) => (s.text ?? '').toString()).join(' ');
          return joined;
        }
      } catch (_) {}
      return r.toString();
    }

    return _extract(resp);
  }

  @override
  Future<void> pause() async {
    if (!_isRecording || _isPaused) return;
    _isPaused = true;
    _rotateTimer?.cancel();
    try {
      if (await _recorder.isRecording()) {
        await _recorder.pause();
      }
    } catch (_) {}
  }

  @override
  Future<void> resume({
    void Function(String partial)? onPartial,
    void Function(String result)? onFinal,
    void Function(Object error)? onError,
  }) async {
    if (!_isRecording || !_isPaused) return;
    _isPaused = false;

    try {
      // If `pause()` paused the file handle, resume; otherwise ensure we’re recording a fresh segment.
      if (await _recorder.isPaused()) {
        await _recorder.resume();
      } else {
        await _startNewSegment(onError);
      }
    } catch (e) {
      onError?.call(e);
    }

    _rotateTimer?.cancel();
    _rotateTimer = Timer.periodic(
      Duration(seconds: segmentSeconds),
      (_) async {
        if (!_isRecording || _isPaused) return;
        try {
          _soundLevel = 0.9;
          Future.delayed(
              const Duration(milliseconds: 200), () => _soundLevel = 0.2);

          await _rotateSegment(onError);
          _drainQueue(onFinal, onError);
        } catch (e) {
          onError?.call(e);
        }
      },
    );
  }

  @override
  Future<void> stop() async {
    _rotateTimer?.cancel();
    _rotateTimer = null;

    // stop current recording & enqueue last file
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}

    if (_currentSegPath != null) {
      final f = File(_currentSegPath!);
      if (await f.exists() && await f.length() > 44) {
        _pending.add(_currentSegPath!);
      } else {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    _currentSegPath = null;

    _isRecording = false;
    _isPaused = false;

    // cleanly finish remaining transcriptions (best-effort)
    try {
      while (_pending.isNotEmpty) {
        final p = _pending.removeAt(0);
        try {
          await _transcribe(p);
        } catch (_) {}
        try {
          await File(p).delete();
        } catch (_) {}
      }
    } catch (_) {}

    _soundLevel = 0.0;
  }
}
