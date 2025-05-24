import 'dart:async';

import 'package:flutter/material.dart';

class SiapaKamuPage extends StatefulWidget {
  final double gazeX;
  final double gazeY;

  const SiapaKamuPage({super.key, required this.gazeX, required this.gazeY});

  @override
  State<SiapaKamuPage> createState() => _SiapaKamuPageState();
}

class _SiapaKamuPageState extends State<SiapaKamuPage> {
  final GlobalKey _teacherKey = GlobalKey();
  final GlobalKey _studentKey = GlobalKey();

  Timer? _dwellTimer;
  String? _currentTarget;

  @override
  void didUpdateWidget(SiapaKamuPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkGaze(widget.gazeX, widget.gazeY);
  }

  void _checkGaze(double x, double y) {
    _checkTarget(_teacherKey, "teacher", x, y);
    _checkTarget(_studentKey, "student", x, y);
  }

  void _checkTarget(GlobalKey key, String id, double x, double y) {
    final RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final position = box.localToGlobal(Offset.zero);
      final size = box.size;
      final rect =
          Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

      if (rect.contains(Offset(x, y))) {
        if (_currentTarget != id) {
          _currentTarget = id;
          _dwellTimer?.cancel();
          _dwellTimer = Timer(const Duration(seconds: 1), () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("You selected: $id")),
            );
          });
        }
      } else if (_currentTarget == id) {
        _dwellTimer?.cancel();
        _currentTarget = null;
      }
    }
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Siapa kamu?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 32),
            ElevatedButton(
              key: _teacherKey,
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Saya seorang guru'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: _studentKey,
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Saya seorang siswa'),
            ),
          ],
        ),
      ),
    );
  }
}
