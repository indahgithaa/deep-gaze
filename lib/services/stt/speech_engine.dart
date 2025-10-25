// File: lib/services/stt/speech_engine.dart
import 'dart:async';

abstract class SpeechEngine {
  Future<bool> init();
  Future<void> start({
    void Function(String partial)? onPartial,
    void Function(String result)? onFinal,
    void Function(Object error)? onError,
  });
  Future<void> pause();
  Future<void> resume({
    void Function(String partial)? onPartial,
    void Function(String result)? onFinal,
    void Function(Object error)? onError,
  });
  Future<void> stop();
  bool get available;
  double get soundLevel; // 0..1
}
