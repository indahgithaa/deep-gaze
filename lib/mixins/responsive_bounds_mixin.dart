// File: lib/mixins/responsive_bounds_mixin.dart
import 'package:flutter/material.dart';

mixin ResponsiveBoundsMixin<T extends StatefulWidget> on State<T> {
  // Store widget keys for bounds calculation
  final Map<String, GlobalKey> _widgetKeys = {};

  // Store calculated bounds
  final Map<String, Rect> _calculatedBounds = {};

  // Screen size caching
  Size? _lastScreenSize;

  // Generate a unique key for an element
  GlobalKey generateKeyForElement(String elementId) {
    if (!_widgetKeys.containsKey(elementId)) {
      _widgetKeys[elementId] = GlobalKey();
    }
    return _widgetKeys[elementId]!;
  }

  // Calculate bounds for all registered widgets
  Map<String, Rect> calculateScaledBounds() {
    final currentScreenSize = MediaQuery.of(context).size;

    // Check if screen size changed (orientation change)
    if (_lastScreenSize != null && _lastScreenSize != currentScreenSize) {
      _calculatedBounds.clear();
      print("DEBUG: Screen size changed, clearing bounds");
    }
    _lastScreenSize = currentScreenSize;

    // Calculate bounds for each widget with a key
    for (final entry in _widgetKeys.entries) {
      final elementId = entry.key;
      final key = entry.value;

      try {
        final RenderBox? renderBox =
            key.currentContext?.findRenderObject() as RenderBox?;

        if (renderBox != null && renderBox.hasSize) {
          final position = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;

          // Apply responsive scaling based on screen size
          final scaleFactor = _getScaleFactor(currentScreenSize);
          final padding = _getAdaptivePadding(size, scaleFactor);

          final scaledBounds = Rect.fromLTWH(
            position.dx - padding,
            position.dy - padding,
            size.width + (padding * 2),
            size.height + (padding * 2),
          );

          _calculatedBounds[elementId] = scaledBounds;

          print("DEBUG: Calculated bounds for $elementId: $scaledBounds");
        }
      } catch (e) {
        print("DEBUG: Error calculating bounds for $elementId: $e");
      }
    }

    return Map.from(_calculatedBounds);
  }

  // Get scale factor based on screen size
  double _getScaleFactor(Size screenSize) {
    final baseSize = 400.0; // Base screen width
    final currentWidth = screenSize.width;
    return (currentWidth / baseSize).clamp(0.8, 2.0);
  }

  // Get adaptive padding based on widget size and scale factor
  double _getAdaptivePadding(Size widgetSize, double scaleFactor) {
    final baseArea = widgetSize.width * widgetSize.height;
    double basePadding;

    // Larger widgets get more padding
    if (baseArea > 10000) {
      basePadding = 15.0;
    } else if (baseArea > 5000) {
      basePadding = 10.0;
    } else {
      basePadding = 8.0;
    }

    return basePadding * scaleFactor;
  }

  // Find which element contains the given point
  String? getElementAtPoint(Offset point) {
    for (final entry in _calculatedBounds.entries) {
      if (entry.value.contains(point)) {
        return entry.key;
      }
    }
    return null;
  }

  // Update bounds after build
  void updateBoundsAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        calculateScaledBounds();
        if (mounted) setState(() {});
      }
    });
  }

  // Clear all bounds (call in dispose)
  void clearBounds() {
    _calculatedBounds.clear();
    _widgetKeys.clear();
    _lastScreenSize = null;
  }

  // Debug function to visualize bounds
  Widget debugBoundsOverlay() {
    if (_calculatedBounds.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: _calculatedBounds.entries.map((entry) {
        final bounds = entry.value;
        return Positioned(
          left: bounds.left,
          top: bounds.top,
          width: bounds.width,
          height: bounds.height,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
              color: Colors.red.withOpacity(0.1),
            ),
            child: Center(
              child: Text(
                entry.key,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
