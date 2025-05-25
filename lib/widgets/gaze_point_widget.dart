import 'package:flutter/material.dart';

class GazePointWidget extends StatefulWidget {
  final double gazeX;
  final double gazeY;
  final bool isVisible;
  final Color? color;
  final double size;
  final bool showTrail;

  const GazePointWidget({
    super.key,
    required this.gazeX,
    required this.gazeY,
    this.isVisible = true,
    this.color,
    this.size = 20.0,
    this.showTrail = false,
  });

  @override
  State<GazePointWidget> createState() => _GazePointWidgetState();
}

class _GazePointWidgetState extends State<GazePointWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Trail untuk tracking history
  final List<Offset> _gazeTrail = [];
  static const int _maxTrailLength = 10;

  @override
  void initState() {
    super.initState();

    // Animation untuk pulse effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GazePointWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update trail jika posisi berubah
    if (widget.gazeX != oldWidget.gazeX || widget.gazeY != oldWidget.gazeY) {
      _updateTrail();
    }
  }

  void _updateTrail() {
    if (!widget.showTrail) return;

    final newPoint = Offset(widget.gazeX, widget.gazeY);

    // Tambahkan point baru jika berbeda dari yang terakhir
    if (_gazeTrail.isEmpty || (_gazeTrail.last - newPoint).distance > 5.0) {
      _gazeTrail.add(newPoint);

      // Hapus point lama jika terlalu banyak
      if (_gazeTrail.length > _maxTrailLength) {
        _gazeTrail.removeAt(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    // Debug print untuk memastikan koordinat diterima
    print(
        "DEBUG: GazePoint - X: ${widget.gazeX.toInt()}, Y: ${widget.gazeY.toInt()}, Visible: ${widget.isVisible}");

    return Stack(
      children: [
        // Trail points (jika enabled)
        if (widget.showTrail) ..._buildTrailPoints(),

        // Main gaze point
        Positioned(
          left: widget.gazeX - (widget.size / 2),
          top: widget.gazeY - (widget.size / 2),
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: (widget.color ?? Colors.green).withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (widget.color ?? Colors.green).withOpacity(0.6),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Container(
                      width: widget.size * 0.4,
                      height: widget.size * 0.4,
                      margin: EdgeInsets.all(widget.size * 0.3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Debug overlay (hanya dalam debug mode)
        if (true) // Set false untuk production
          Positioned(
            left: widget.gazeX + 25,
            top: widget.gazeY - 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '(${widget.gazeX.toInt()}, ${widget.gazeY.toInt()})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildTrailPoints() {
    List<Widget> trailWidgets = [];

    for (int i = 0; i < _gazeTrail.length; i++) {
      final point = _gazeTrail[i];
      final opacity = (i + 1) / _gazeTrail.length * 0.6;
      final size = widget.size * (0.3 + (i + 1) / _gazeTrail.length * 0.4);

      trailWidgets.add(
        Positioned(
          left: point.dx - (size / 2),
          top: point.dy - (size / 2),
          child: IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: (widget.color ?? Colors.green).withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    return trailWidgets;
  }
}

// Enhanced version dengan lebih banyak opsi customization
class AdvancedGazePointWidget extends StatefulWidget {
  final double gazeX;
  final double gazeY;
  final bool isVisible;
  final Color? color;
  final double size;
  final bool showTrail;
  final bool showAccuracyRing;
  final double accuracy; // 0.0 - 1.0
  final bool showCoordinates;
  final GazePointStyle style;

  const AdvancedGazePointWidget({
    super.key,
    required this.gazeX,
    required this.gazeY,
    this.isVisible = true,
    this.color,
    this.size = 20.0,
    this.showTrail = false,
    this.showAccuracyRing = false,
    this.accuracy = 1.0,
    this.showCoordinates = false,
    this.style = GazePointStyle.circle,
  });

  @override
  State<AdvancedGazePointWidget> createState() =>
      _AdvancedGazePointWidgetState();
}

class _AdvancedGazePointWidgetState extends State<AdvancedGazePointWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _ringAnimation = Tween<double>(
      begin: 1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOut,
    ));

    _pulseController.repeat(reverse: true);
    if (widget.showAccuracyRing) {
      _ringController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final effectiveColor =
        widget.color ?? _getColorForAccuracy(widget.accuracy);

    return Stack(
      children: [
        // Accuracy ring (jika enabled)
        if (widget.showAccuracyRing)
          Positioned(
            left: widget.gazeX - (widget.size * 1.5),
            top: widget.gazeY - (widget.size * 1.5),
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ringAnimation,
                builder: (context, child) {
                  return Container(
                    width: widget.size * 3 * _ringAnimation.value,
                    height: widget.size * 3 * _ringAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: effectiveColor
                            .withOpacity(0.3 / _ringAnimation.value),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // Main gaze point
        Positioned(
          left: widget.gazeX - (widget.size / 2),
          top: widget.gazeY - (widget.size / 2),
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: _buildGazePoint(effectiveColor),
                );
              },
            ),
          ),
        ),

        // Coordinates display (jika enabled)
        if (widget.showCoordinates)
          Positioned(
            left: widget.gazeX + widget.size,
            top: widget.gazeY - 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '(${widget.gazeX.toInt()}, ${widget.gazeY.toInt()})\n${(widget.accuracy * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGazePoint(Color color) {
    switch (widget.style) {
      case GazePointStyle.circle:
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            margin: EdgeInsets.all(widget.size * 0.25),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );

      case GazePointStyle.cross:
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              // Horizontal bar
              Positioned(
                left: 0,
                top: widget.size * 0.4,
                child: Container(
                  width: widget.size,
                  height: widget.size * 0.2,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(widget.size * 0.1),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              // Vertical bar
              Positioned(
                left: widget.size * 0.4,
                top: 0,
                child: Container(
                  width: widget.size * 0.2,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(widget.size * 0.1),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case GazePointStyle.diamond:
        return Transform.rotate(
          angle: 0.785398, // 45 degrees
          child: Container(
            width: widget.size * 0.8,
            height: widget.size * 0.8,
            decoration: BoxDecoration(
              color: color.withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );

      case GazePointStyle.target:
        return Stack(
          children: [
            // Outer ring
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            // Inner circle
            Positioned(
              left: widget.size * 0.25,
              top: widget.size * 0.25,
              child: Container(
                width: widget.size * 0.5,
                height: widget.size * 0.5,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
    }
  }

  Color _getColorForAccuracy(double accuracy) {
    if (accuracy >= 0.9) return Colors.green;
    if (accuracy >= 0.7) return Colors.orange;
    return Colors.red;
  }
}

enum GazePointStyle {
  circle,
  cross,
  diamond,
  target,
}
