// File: lib/widgets/gaze_overlay_manager.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// GazeOverlayManager
/// - Singleton overlay cursor (HUD) yang selalu di root Overlay
/// - Aman dari "setState/markNeedsBuild called during build" karena
///   semua rebuild/insert/remove dijadwalkan post-frame bila perlu.
class GazeOverlayManager {
  GazeOverlayManager._();
  static final GazeOverlayManager instance = GazeOverlayManager._();

  OverlayEntry? _entry;
  OverlayState? _overlayState;

  // State HUD
  Offset _cursor = const Offset(-10000, -10000);
  bool _visible = false;
  Rect? _highlight;
  double? _progress;

  // Internal flags
  bool _rebuildScheduled = false;
  bool _insertScheduled = false;
  bool _removeScheduled = false;

  // ===== Public API =========================================================

  /// Panggil sekali dari halaman manapun yang punya context valid.
  /// Aman dipanggil berulang; hanya akan mengikat OverlayState sekali.
  void attach(BuildContext context) {
    _overlayState ??= Overlay.of(context, rootOverlay: true);
    _ensureEntry(); // create + insert bila perlu (aman: ter-schedule)
  }

  /// Update posisi cursor, visibilitas, highlight rect, dan progress dwell.
  /// Boleh dipanggil sangat sering (tiap frame).
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
    _ensureEntry();
    _markNeedsBuildSafe();
  }

  /// Tampilkan HUD (jika sebelumnya tersembunyi).
  void show() {
    _visible = true;
    _ensureEntry();
    _markNeedsBuildSafe();
  }

  /// Sembunyikan HUD (tetap mempertahankan entry agar murah).
  void hide() {
    _visible = false;
    _markNeedsBuildSafe();
  }

  /// Hapus OverlayEntry sepenuhnya (opsional).
  void dispose() {
    if (_entry == null) return;
    _removeEntrySafe();
    _overlayState = null;
  }

  // ===== Internals ==========================================================

  void _ensureEntry() {
    if (_entry != null) return;

    _entry = OverlayEntry(builder: (context) {
      return IgnorePointer(
        child: Positioned.fill(
          child: CustomPaint(
            painter: _GazeHudPainter(
              cursor: _cursor,
              visible: _visible,
              highlight: _highlight,
              progress: _progress,
            ),
          ),
        ),
      );
    });

    // Pastikan ada OverlayState, kalau belum ada tapi attach belum pernah dipanggil,
    // coba ambil dari WidgetsBinding (fallback lewat gesture: tidak selalu ada).
    _overlayState ??= _fallbackOverlayState();

    // Insert entry aman (post-frame bila phase lagi build)
    _insertEntrySafe();
  }

  OverlayState? _fallbackOverlayState() {
    // Coba cari dari navigator key global jika ada di tree aplikasi.
    // Bila tidak ada, biarkan null — attach(context) wajib memanggil sebelum update berguna.
    try {
      final navigator =
          WidgetsBinding.instance.focusManager.primaryFocus?.context;
      if (navigator != null) {
        return Overlay.of(navigator, rootOverlay: true);
      }
    } catch (_) {}
    return null;
  }

  // Jadwalkan rebuild aman (tanpa error "called during build")
  void _markNeedsBuildSafe() {
    if (_entry == null) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    // Aman langsung rebuild saat idle / setelah frame
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      _entry!.markNeedsBuild();
      return;
    }

    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      _entry?.markNeedsBuild();
    });
  }

  void _insertEntrySafe() {
    if (_entry == null || _overlayState == null) return;

    // Kalau sudah ada di overlay, skip (OverlayEntry tidak punya properti ini,
    // jadi kita coba markNeedsBuild saja).
    // Insert hanya jika belum pernah dimasukkan.
    // Trik: kita coba rebuild; jika tidak terlihat, insert.
    // Untuk aman, kita langsung jadwalkan insert post-frame.
    if (_insertScheduled) return;
    _insertScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _insertScheduled = false;
      // Kalau sudah di-dispose saat menunggu frame, abaikan.
      if (_entry == null || _overlayState == null) return;

      // Coba insert — bila sudah ada, Flutter akan anggap valid (tidak crash).
      try {
        _overlayState!.insert(_entry!);
      } catch (_) {
        // Bisa terjadi jika sudah tersisip; abaikan.
      }
      _entry!.markNeedsBuild();
    });
  }

  void _removeEntrySafe() {
    if (_entry == null) return;
    if (_removeScheduled) return;

    _removeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _removeScheduled = false;
      try {
        _entry?.remove();
      } catch (_) {
        // ignore
      }
      _entry = null;
    });
  }
}

/// Painter sederhana untuk HUD cursor / highlight / progress.
class _GazeHudPainter extends CustomPainter {
  final Offset cursor;
  final bool visible;
  final Rect? highlight;
  final double? progress;

  _GazeHudPainter({
    required this.cursor,
    required this.visible,
    required this.highlight,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (visible) {
      // Cursor bulat hijau
      final cursorPaint = Paint()
        ..color = const Color(0xFF00C853); // green A700
      canvas.drawCircle(cursor, 8, cursorPaint);

      // Ring luar tipis
      final ring = Paint()
        ..color = const Color(0x8800C853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(cursor, 14, ring);

      // Progress dwell (arc)
      if (progress != null) {
        final arcPaint = Paint()
          ..color = const Color(0xFF00C853)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        final rect = Rect.fromCircle(center: cursor, radius: 18);
        final sweep = (progress!.clamp(0.0, 1.0)) * 6.283185307179586; // 2π
        canvas.drawArc(
            rect, -1.57079632679, sweep, false, arcPaint); // start at top
      }
    }

    // Highlight rect (opsional)
    if (highlight != null) {
      final hl = Paint()
        ..color = const Color(0x3300C853)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = const Color(0xFF00C853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(highlight!, const Radius.circular(6)),
        hl,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(highlight!, const Radius.circular(6)),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GazeHudPainter old) {
    return cursor != old.cursor ||
        visible != old.visible ||
        progress != old.progress ||
        highlight != old.highlight;
  }
}
