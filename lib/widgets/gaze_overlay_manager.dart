import 'package:flutter/material.dart';
import '../main.dart'; // rootNavKey

class GazeOverlayManager {
  GazeOverlayManager._();
  static final GazeOverlayManager instance = GazeOverlayManager._();

  OverlayEntry? _entry;
  bool _requestedInsert = false;

  Offset _cursor = const Offset(-1000, -1000);
  bool _visible = false;
  Rect? _highlight;
  double? _progress; // 0..1 untuk dwell indicator

  OverlayState? _rootOverlay() => rootNavKey.currentState?.overlay;

  void _ensureInserted() {
    final overlay = _rootOverlay();
    if (overlay == null) {
      if (!_requestedInsert) {
        _requestedInsert = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _requestedInsert = false;
          _ensureInserted();
        });
      }
      return;
    }
    if (_entry == null) {
      _entry = OverlayEntry(builder: (_) {
        return IgnorePointer(
          ignoring: true,
          child: Stack(
            children: [
              if (_highlight != null)
                Positioned(
                  left: _highlight!.left,
                  top: _highlight!.top,
                  width: _highlight!.width,
                  height: _highlight!.height,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.06),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.30),
                          ),
                        ),
                      ),
                      if (_progress != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 3,
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _progress!.clamp(0.0, 1.0),
                              child: Container(height: 3, color: Colors.blue),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (_visible)
                Positioned(
                  left: _cursor.dx - 10,
                  top: _cursor.dy - 10,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 2),
                      boxShadow: const [
                        BoxShadow(blurRadius: 8, color: Colors.black26)
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      });
      overlay.insert(_entry!);
    }
  }

  /// progress: 0..1 (opsional). highlight: rect target (opsional).
  void update({
    required Offset cursor,
    required bool visible,
    Rect? highlight,
    double? progress,
  }) {
    _cursor = cursor;
    _visible = visible;
    _highlight = highlight;
    _progress = progress;
    _ensureInserted();
    _entry?.markNeedsBuild();
  }

  void hide() {
    _visible = false;
    _highlight = null;
    _progress = null;
    _entry?.markNeedsBuild();
  }

  void dispose() {
    _entry?.remove();
    _entry = null;
  }
}
