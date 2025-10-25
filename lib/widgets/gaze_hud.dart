import 'package:flutter/material.dart';

/// Singleton controller utk mengupdate HUD dari mana saja.
class GazeHUDController extends ChangeNotifier {
  static final GazeHUDController instance = GazeHUDController._internal();
  GazeHUDController._internal();

  Offset _cursor = const Offset(-1000, -1000);
  bool _visible = false;
  Rect? _highlight; // rect yang disorot (mis. nav item saat hover)

  void show(
      {required Offset cursor, required bool isTracking, Rect? highlight}) {
    _cursor = cursor;
    _visible = isTracking;
    _highlight = highlight;
    notifyListeners();
  }

  void hide() {
    _visible = false;
    _highlight = null;
    notifyListeners();
  }
}

class GazeHUD extends StatefulWidget {
  const GazeHUD({super.key});

  @override
  State<GazeHUD> createState() => _GazeHUDState();
}

class _GazeHUDState extends State<GazeHUD> {
  @override
  void initState() {
    super.initState();
    GazeHUDController.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    GazeHUDController.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = GazeHUDController.instance;

    // Selalu paling atas, tidak menangkap pointer
    return IgnorePointer(
      ignoring: true,
      child: Stack(
        children: [
          // highlight target (opsional)
          if (ctrl._highlight != null)
            Positioned(
              left: ctrl._highlight!.left,
              top: ctrl._highlight!.top,
              width: ctrl._highlight!.width,
              height: ctrl._highlight!.height,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.06),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
              ),
            ),
          // dot hijau (hanya saat tracking)
          if (ctrl._visible)
            Positioned(
              left: ctrl._cursor.dx - 10,
              top: ctrl._cursor.dy - 10,
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
  }
}
