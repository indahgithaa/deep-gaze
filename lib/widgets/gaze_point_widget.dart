import 'package:flutter/material.dart';

class GazePointWidget extends StatelessWidget {
  final double gazeX;
  final double gazeY;
  final bool isVisible;

  const GazePointWidget({
    super.key,
    required this.gazeX,
    required this.gazeY,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      left: gazeX - 10,
      top: gazeY - 10,
      child: IgnorePointer(
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
