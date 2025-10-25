// File: lib/services/stt/whisper_speech_engine.dart
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'speech_engine.dart';

/// Engine Whisper on-device berbasis file dengan "near-realtime" chunking.
/// Mekanisme:
/// - start(): mulai rekam WAV ke file rolling
/// - tiap [_chunkSecs] detik: potong salinan audio -> transcribe async -> kirim onPartial/onFinal
class WhisperSpeechEngine implements SpeechEngine {
  WhisperSpeechEngine({
    this.model = WhisperModel.small, // small: akurasi & size OK untuk id
    this.chunkSecs = 8, // jeda transcribe "near realtime"
    this.language = 'id', // paksa bahasa Indonesia
    this.translateToEnglish = false, // jangan translate; transkrip asli
  });

  final WhisperModel model;
  final int chunkSecs;
  final String language;
  final bool translateToEnglish;

  final _recorder = AudioRecorder();
  Whisper? _whisper;

  bool _available = false;
  bool _isRecording = false;
  Timer? _chunkTimer;

  late String _rollingWavPath;
  int _lastBytesRead = 0; // untuk men-slice bagian baru saja

  double _soundLevel = 0.0;
  @override
  double get soundLevel => _soundLevel;

  @override
  bool get available => _available;

  @override
  Future<bool> init() async {
    // siapkan instance Whisper (auto download model dari HF)
    _whisper = Whisper(
      model: model,
      downloadHost: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
    );
    // cek versi -> sekaligus trigger lib siap
    try {
      await _whisper!.getVersion();
    } catch (_) {
      // tetap lanjut; library akan unduh saat transcribe pertama
    }
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

    final dir = await getTemporaryDirectory();
    _rollingWavPath = '${dir.path}/dgz_rec.wav';
    _lastBytesRead = 0;

    // Mulai rekam WAV 16k mono
    final config = RecordConfig(
      encoder: AudioEncoder.wav,
      bitRate: 128000,
      sampleRate: 16000,
      numChannels: 1,
    );

    if (!await _recorder.hasPermission()) {
      onError?.call(StateError('Mic permission denied'));
      return;
    }

    await _recorder.start(config, path: _rollingWavPath);
    _isRecording = true;

    // timer chunk untuk near-realtime
    _chunkTimer?.cancel();
    _chunkTimer = Timer.periodic(Duration(seconds: chunkSecs), (_) async {
      try {
        // update "meter" pseudo level agar tombol berdenyut
        _soundLevel = 0.8;
        Future.delayed(
            const Duration(milliseconds: 250), () => _soundLevel = 0.2);

        final file = File(_rollingWavPath);
        if (!await file.exists()) return;

        final totalBytes = await file.length();
        if (totalBytes <= _lastBytesRead) return;

        // salin segmen baru (dari _lastBytesRead -> totalBytes)
        final slicePath =
            '${dir.path}/dgz_slice_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _copyTail(file, slicePath, fromByte: _lastBytesRead);
        _lastBytesRead = totalBytes;

        // transcribe segmen (non-blocking)
        unawaited(_transcribeFile(
          slicePath,
          onPartial: onPartial,
          onFinal: onFinal,
          onError: onError,
        ));
      } catch (e) {
        onError?.call(e);
      }
    });
  }

  Future<void> _transcribeFile(
    String wavPath, {
    void Function(String partial)? onPartial,
    void Function(String result)? onFinal,
    void Function(Object error)? onError,
  }) async {
    try {
      // NB: plugin ini output JSON string; by default kita minta tanpa timestamp biar simple
      final resp = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: wavPath,
          isTranslate: translateToEnglish,
          isNoTimestamps: true,
          language: language, // 'id' -> Indonesian
          splitOnWord: false,
        ),
      );

      // respons bisa berupa String atau object; ambil teks final dengan aman
      final dynamic d = resp;
      final String text = d is String
          ? d
          : (d.text ?? d.result ?? d.transcript ?? d.toString()) as String;

      if (text.trim().isNotEmpty) {
        onFinal?.call(text.trim());
      }
    } catch (e) {
      onError?.call(e);
    } finally {
      // hapus slice agar tidak menumpuk
      try {
        await File(wavPath).delete();
      } catch (_) {}
    }
  }

  /// Menyalin tail WAV dari offset byte tertentu termasuk header fix sederhana:
  /// Untuk kesederhanaan kita salin keseluruhan file ke slice, karena encoder WAV di `record`
  /// mengisi header final saat stop. Ini berarti chunk pertama saja yg besar, sisanya kecil
  /// (tetap bekerja untuk near-realtime meski tidak ideal). Alternatif: rekam ke file baru
  /// setiap interval (lebih kecil), tapi ada klik re-init encoder; implementasi ini stabil.
  Future<void> _copyTail(File src, String dest, {required int fromByte}) async {
    final bytes = await src.readAsBytes();
    // amankan indeks
    final start = (fromByte <= 0 || fromByte >= bytes.length) ? 0 : fromByte;
    // tulis slice (header+audio penuh jika start==0, atau tail raw -> Whisper masih bisa baca sebagian besar WAV)
    // Jika ada isu pada beberapa device, ganti strategi: stop() lalu start() tiap interval (lihat catatan).
    await File(dest).writeAsBytes(bytes.sublist(start));
  }

  @override
  Future<void> pause() async {
    if (!_isRecording) return;
    await _recorder.pause();
  }

  @override
  Future<void> resume({
    void Function(String partial)? onPartial,
    void Function(String result)? onFinal,
    void Function(Object error)? onError,
  }) async {
    if (!_isRecording) return;
    await _recorder.resume();
  }

  @override
  Future<void> stop() async {
    _chunkTimer?.cancel();
    _chunkTimer = null;
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }
  }
}
