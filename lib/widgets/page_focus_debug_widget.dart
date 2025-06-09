// File: lib/widgets/page_focus_debug_widget.dart
import 'package:flutter/material.dart';
import '../services/global_seeso_service.dart';

class PageFocusDebugWidget extends StatefulWidget {
  const PageFocusDebugWidget({super.key});

  @override
  State<PageFocusDebugWidget> createState() => _PageFocusDebugWidgetState();
}

class _PageFocusDebugWidgetState extends State<PageFocusDebugWidget> {
  late GlobalSeesoService _eyeTrackingService;

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = GlobalSeesoService();
    // Listen to changes for debug updates
    _eyeTrackingService.addListener(_updateDebugInfo);
  }

  @override
  void dispose() {
    _eyeTrackingService.removeListener(_updateDebugInfo);
    super.dispose();
  }

  void _updateDebugInfo() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 150,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade300, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bug_report,
                  color: Colors.green.shade300,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  "Page Focus Debug",
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Active: ${_eyeTrackingService.activePageId ?? 'NONE'}",
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              "Tracking: ${_eyeTrackingService.isTracking ? 'YES' : 'NO'}",
              style: TextStyle(
                color:
                    _eyeTrackingService.isTracking ? Colors.green : Colors.red,
                fontSize: 10,
              ),
            ),
            Text(
              "Gaze: (${_eyeTrackingService.gazeX.toInt()}, ${_eyeTrackingService.gazeY.toInt()})",
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),

            // Emergency buttons
            const SizedBox(height: 4),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    _eyeTrackingService.debugPageStatus();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "Debug",
                      style: TextStyle(color: Colors.white, fontSize: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    _eyeTrackingService.clearAllPageListeners();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Emergency cleanup performed!"),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "Reset",
                      style: TextStyle(color: Colors.white, fontSize: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
