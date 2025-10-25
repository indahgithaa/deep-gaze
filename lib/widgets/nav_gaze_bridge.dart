import 'package:flutter/material.dart';

/// Event bus sederhana untuk menyebarkan posisi gaze ke siapa pun yang butuh.
/// Halaman aktif: panggil NavGazeBridge.instance.update(Offset, isTracking)
/// MainAppScaffold: subscribe via addListener().
class NavGazeBridge extends ChangeNotifier {
  NavGazeBridge._();
  static final NavGazeBridge instance = NavGazeBridge._();

  Offset _cursor = const Offset(-1000, -1000);
  bool _isTracking = false;

  Offset get cursor => _cursor;
  bool get isTracking => _isTracking;

  void update(Offset pos, bool tracking) {
    _cursor = pos;
    _isTracking = tracking;
    notifyListeners();
  }
}
