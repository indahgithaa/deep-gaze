// File: lib/mixins/responsive_bounds_mixin.dart
import 'package:flutter/material.dart';

/// Mixin to provide responsive bounds calculation and accurate hit detection
/// for eye tracking interfaces
mixin ResponsiveBoundsMixin<T extends StatefulWidget> on State<T> {
  // Store element bounds
  final Map<String, Rect> _elementBounds = {};
  final Map<String, GlobalKey> _elementKeys = {};

  // Configuration
  double get boundsUpdateDelay => 100.0; // ms delay for bounds calculation
  bool get enableBoundsLogging => true; // Enable detailed logging

  /// Generate a GlobalKey for an element
  GlobalKey generateKeyForElement(String elementId) {
    if (!_elementKeys.containsKey(elementId)) {
      _elementKeys[elementId] = GlobalKey();
    }
    return _elementKeys[elementId]!;
  }

  /// Update bounds after build completes
  void updateBoundsAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: boundsUpdateDelay.toInt()), () {
        if (mounted) {
          calculateScaledBounds();
        }
      });
    });
  }

  /// Calculate all element bounds using their GlobalKeys
  Map<String, Rect> calculateScaledBounds() {
    if (!mounted) return {};

    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    if (enableBoundsLogging) {
      print("DEBUG: Calculating bounds for ${_elementKeys.length} elements");
      print("  - Screen size: $screenSize");
      print("  - Padding: $padding");
    }

    int successfulCalculations = 0;

    _elementKeys.forEach((elementId, globalKey) {
      try {
        final bounds = _calculateElementBounds(globalKey);
        if (bounds != null) {
          _elementBounds[elementId] = bounds;
          successfulCalculations++;

          if (enableBoundsLogging) {
            print("  - $elementId: $bounds");
          }
        } else {
          if (enableBoundsLogging) {
            print("  - WARNING: Could not calculate bounds for $elementId");
          }
        }
      } catch (e) {
        if (enableBoundsLogging) {
          print("  - ERROR calculating bounds for $elementId: $e");
        }
      }
    });

    if (enableBoundsLogging) {
      print(
          "DEBUG: Successfully calculated $successfulCalculations/${_elementKeys.length} bounds");
    }

    return Map.from(_elementBounds);
  }

  /// Calculate bounds for a specific element using its GlobalKey
  Rect? _calculateElementBounds(GlobalKey key) {
    try {
      final RenderBox? renderBox =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        return Rect.fromLTWH(
          position.dx,
          position.dy,
          size.width,
          size.height,
        );
      }
    } catch (e) {
      if (enableBoundsLogging) {
        print("ERROR: Exception in _calculateElementBounds: $e");
      }
    }
    return null;
  }

  /// Get element at a specific point with tolerance
  String? getElementAtPoint(Offset point, {double tolerance = 0.0}) {
    for (final entry in _elementBounds.entries) {
      final expandedRect = tolerance > 0
          ? Rect.fromLTWH(
              entry.value.left - tolerance,
              entry.value.top - tolerance,
              entry.value.width + (tolerance * 2),
              entry.value.height + (tolerance * 2),
            )
          : entry.value;

      if (expandedRect.contains(point)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Check if a point is within specific element bounds
  bool isPointInElement(String elementId, Offset point,
      {double tolerance = 0.0}) {
    final bounds = _elementBounds[elementId];
    if (bounds == null) return false;

    final expandedRect = tolerance > 0
        ? Rect.fromLTWH(
            bounds.left - tolerance,
            bounds.top - tolerance,
            bounds.width + (tolerance * 2),
            bounds.height + (tolerance * 2),
          )
        : bounds;

    return expandedRect.contains(point);
  }

  /// Get bounds for a specific element
  Rect? getBoundsForElement(String elementId) {
    return _elementBounds[elementId];
  }

  /// Get all calculated bounds
  Map<String, Rect> getAllBounds() {
    return Map.from(_elementBounds);
  }

  /// Get count of registered elements
  int get elementCount => _elementKeys.length;

  /// Get count of calculated bounds
  int get boundsCount => _elementBounds.length;

  /// Clear all bounds and keys
  void clearBounds() {
    _elementBounds.clear();
    _elementKeys.clear();
  }

  /// Validate that calculated bounds don't overlap with restricted areas
  List<String> validateBounds(List<Rect> restrictedAreas) {
    final conflicts = <String>[];

    for (final entry in _elementBounds.entries) {
      for (final restrictedArea in restrictedAreas) {
        if (entry.value.overlaps(restrictedArea)) {
          conflicts.add(
              '${entry.key} overlaps with restricted area $restrictedArea');
        }
      }
    }

    return conflicts;
  }

  /// Update a specific element's bounds manually
  void updateElementBounds(String elementId, Rect bounds) {
    _elementBounds[elementId] = bounds;

    if (enableBoundsLogging) {
      print("DEBUG: Manually updated bounds for $elementId: $bounds");
    }
  }

  /// Calculate safe zones avoiding bottom navigation
  Rect calculateSafeContentArea({
    double bottomNavHeight = 80.0,
    double headerHeight = 120.0,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    final safeTop = padding.top + headerHeight;
    final safeBottom = screenSize.height - bottomNavHeight - padding.bottom;

    return Rect.fromLTWH(
      0,
      safeTop,
      screenSize.width,
      safeBottom - safeTop,
    );
  }

  /// Debug method to print all current bounds
  void debugPrintBounds() {
    print("=== Current Element Bounds ===");
    if (_elementBounds.isEmpty) {
      print("  No bounds calculated");
    } else {
      _elementBounds.forEach((key, rect) {
        print("  $key: $rect");
      });
    }
    print("===============================");
  }

  /// Check for overlapping elements
  Map<String, List<String>> detectOverlappingElements() {
    final overlaps = <String, List<String>>{};

    final elementIds = _elementBounds.keys.toList();
    for (int i = 0; i < elementIds.length; i++) {
      for (int j = i + 1; j < elementIds.length; j++) {
        final id1 = elementIds[i];
        final id2 = elementIds[j];
        final rect1 = _elementBounds[id1]!;
        final rect2 = _elementBounds[id2]!;

        if (rect1.overlaps(rect2)) {
          overlaps.putIfAbsent(id1, () => []).add(id2);
          overlaps.putIfAbsent(id2, () => []).add(id1);
        }
      }
    }

    return overlaps;
  }

  /// Calculate minimum distance between elements
  double getDistanceBetweenElements(String element1, String element2) {
    final bounds1 = _elementBounds[element1];
    final bounds2 = _elementBounds[element2];

    if (bounds1 == null || bounds2 == null) return double.infinity;

    final center1 = bounds1.center;
    final center2 = bounds2.center;

    return (center1 - center2).distance;
  }

  /// Get elements within a certain radius of a point
  List<String> getElementsNearPoint(Offset point, double radius) {
    final nearbyElements = <String>[];

    _elementBounds.forEach((elementId, bounds) {
      final distance = (bounds.center - point).distance;
      if (distance <= radius) {
        nearbyElements.add(elementId);
      }
    });

    return nearbyElements;
  }
}
