// File: lib/services/stt/whisper_speech_engine.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'speech_engine.dart';

/// Rotating double-buffer for “near-live” transcription using Whisper (non-streaming).
class WhisperSpeechEngine implements SpeechEngine {
  WhisperSpeechEngine({
    this.model = WhisperModel.tiny, // use base/small if device is strong
    this.segmentSeconds = 2,
    this.language = 'id',
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

  Directory? _tmpDir;

  String? _activePath; // currently recording
  String? _standbyPath; // next target

  Timer? _rotateTimer;
  bool _rotating = false;

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
    try {
      await _whisper!.getVersion();
    } catch (_) {}
    _tmpDir = await getTemporaryDirectory();
    _available = true;
    return true;
  }

  @override
  Future<void> start({
    void Function(String partial)? onPartial,
    void Function(String result)? onFinal,
    void Function(Object error)? onError,
  }) async {
    if (!_available || _isRecording) return;

    if (!await _recorder.hasPermission()) {
      onError?.call(StateError('Mic permission denied'));
      return;
    }

    _isRecording = true;
    _isPaused = false;

    final t = DateTime.now().millisecondsSinceEpoch;
    _activePath = '${_tmpDir!.path}/dgz_${t}_A.wav'; // <-- fixed interpolation
    _standbyPath = '${_tmpDir!.path}/dgz_${t}_B.wav'; // <-- fixed interpolation

    await _startRecordingTo(_activePath!, onError);

    _rotateTimer?.cancel();
    _rotateTimer = Timer.periodic(Duration(seconds: segmentSeconds), (_) async {
      if (!_isRecording || _isPaused) return;
      try {
        await _rotate(onFinal, onError);
      } catch (e) {
        onError?.call(e);
      }
    });
  }

  Future<void> _startRecordingTo(
      String path, void Function(Object error)? onError) async {
    try {
      final cfg = RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000,
        numChannels: 1,
      );
      await _recorder.start(cfg, path: path);
      if (kDebugMode) debugPrint('[WhisperSTT] start -> $path');
    } catch (e) {
      onError?.call(e);
    }
  }

  Future<void> _rotate(
    void Function(String result)? onFinal,
    void Function(Object error)? onError,
  ) async {
    if (_rotating) return;
    _rotating = true;

    _soundLevel = 0.9;
    Future.delayed(const Duration(milliseconds: 160), () => _soundLevel = 0.2);

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      onError?.call(e);
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final closedPath = _activePath;

    _activePath = _standbyPath;
    _standbyPath =
        '${_tmpDir!.path}/dgz_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _startRecordingTo(_activePath!, onError);

    if (closedPath != null) {
      try {
        final f = File(closedPath);
        if (await f.exists() && await f.length() > 1024) {
          _pending.add(closedPath);
          if (kDebugMode) {
            debugPrint(
                '[WhisperSTT] enqueue -> $closedPath (${await f.length()} B)');
          }
          _drainQueue(onFinal, onError);
        } else {
          try {
            await f.delete();
          } catch (_) {}
        }
      } catch (e) {
        onError?.call(e);
      }
    }

    _rotating = false;
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
    if (kDebugMode) debugPrint('[WhisperSTT] transcribe -> $wavPath');
    final resp = await _whisper!.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: wavPath,
        isTranslate: translateToEnglish,
        isNoTimestamps: true,
        language: language,
        splitOnWord: false,
      ),
    );

    String _extract(dynamic r) {
      try {
        final primary = (r.text ?? r.result?.text ?? '').toString();
        if (primary.isNotEmpty) return primary;
        final segs = r.result?.segments;
        if (segs is List) {
          final joined = segs.map((s) => (s.text ?? '').toString()).join(' ');
          return joined;
        }
      } catch (_) {}
      return r.toString();
    }

    final out = _extract(resp);
    if (kDebugMode) {
      final preview = out.length > 120 ? '${out.substring(0, 120)}…' : out;
      debugPrint('[WhisperSTT] text <- $preview');
    }
    return out;
  }

  @override
  Future<void> pause() async {
    if (!_isRecording || _isPaused) return;
    _isPaused = true;
    _rotateTimer?.cancel();

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}

    final p = _activePath;
    if (p != null) {
      try {
        final f = File(p);
        if (await f.exists() && await f.length() > 1024) {
          _pending.add(p);
        } else {
          try {
            await f.delete();
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> resume({
    void Function(String partial)? onPartial,
    void Function(String result)? onFinal,
    void Function(Object error)? onError,
  }) async {
    if (!_isRecording || !_isPaused) return;
    _isPaused = false;

    _activePath =
        '${_tmpDir!.path}/dgz_${DateTime.now().millisecondsSinceEpoch}_R.wav';
    await _startRecordingTo(_activePath!, onError);
    _standbyPath =
        '${_tmpDir!.path}/dgz_${DateTime.now().millisecondsSinceEpoch}_S.wav';

    _rotateTimer?.cancel();
    _rotateTimer = Timer.periodic(
      Duration(seconds: segmentSeconds),
      (_) async {
        if (!_isRecording || _isPaused) return;
        try {
          await _rotate(onFinal, onError);
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

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    } catch (_) {}

    final p = _activePath;
    if (p != null) {
      try {
        final f = File(p);
        if (await f.exists() && await f.length() > 1024) {
          _pending.add(p);
        } else {
          try {
            await f.delete();
          } catch (_) {}
        }
      } catch (_) {}
    }
    _activePath = null;
    _standbyPath = null;

    _isRecording = false;
    _isPaused = false;

    _soundLevel = 0.0;
  }
}
