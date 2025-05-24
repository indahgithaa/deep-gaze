import 'package:flutter/material.dart';

class StatusInfoWidget extends StatelessWidget {
  final String statusMessage;
  final int currentPage;
  final int totalPages;
  final double gazeX;
  final double gazeY;
  final String? currentDwellingElement;
  final double dwellProgress;

  const StatusInfoWidget({
    super.key,
    required this.statusMessage,
    required this.currentPage,
    required this.totalPages,
    required this.gazeX,
    required this.gazeY,
    this.currentDwellingElement,
    this.dwellProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.remove_red_eye,
                  color: Colors.green,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  "Eye Tracking Status",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Status: $statusMessage",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              "Page: $currentPage/$totalPages",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              "Gaze: (${gazeX.toInt()}, ${gazeY.toInt()})",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            if (currentDwellingElement != null) ...[
              const SizedBox(height: 4),
              Text(
                "Dwelling: ${(dwellProgress * 100).toInt()}%",
                style: const TextStyle(color: Colors.yellow, fontSize: 12),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 100,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: dwellProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.red],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
