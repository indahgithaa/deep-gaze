// File: lib/widgets/eye_controlled_keyboard.dart
import 'package:flutter/material.dart';
import '../services/global_seeso_service.dart';

class EyeControlledKeyboard extends StatefulWidget {
  final Function(String) onKeyPressed;
  final String? currentDwellingElement;
  final double dwellProgress;
  final Function(Map<String, Rect>)? onBoundsCalculated; // NEW CALLBACK

  const EyeControlledKeyboard({
    super.key,
    required this.onKeyPressed,
    required this.currentDwellingElement,
    required this.dwellProgress,
    this.onBoundsCalculated, // NEW PARAMETER
  });

  @override
  State<EyeControlledKeyboard> createState() => _EyeControlledKeyboardState();
}

class _EyeControlledKeyboardState extends State<EyeControlledKeyboard> {
  bool _isDisposed = false;

  // CRITICAL FIX: GlobalKeys for each key to get actual positions
  final Map<String, GlobalKey> _keyGlobalKeys = {};
  final Map<String, Rect> _calculatedBounds = {};

  // Keyboard layout configuration
  final List<List<String>> _keyboardLayout = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ['SPACE', 'BACKSPACE', 'ENTER']
  ];

  @override
  void initState() {
    super.initState();

    // Initialize GlobalKeys for all keys
    _initializeKeyGlobalKeys();

    // Calculate bounds after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateAndNotifyBounds();
    });
  }

  void _initializeKeyGlobalKeys() {
    for (final row in _keyboardLayout) {
      for (final key in row) {
        _keyGlobalKeys[key] = GlobalKey();
      }
    }
    print(
        "DEBUG: Initialized ${_keyGlobalKeys.length} GlobalKeys for keyboard");
  }

  void _calculateAndNotifyBounds() {
    if (_isDisposed || !mounted) return;

    try {
      _calculatedBounds.clear();
      int successfulCalculations = 0;

      // Calculate bounds for each key using its GlobalKey
      _keyGlobalKeys.forEach((keyValue, globalKey) {
        try {
          final RenderBox? renderBox =
              globalKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final position = renderBox.localToGlobal(Offset.zero);
            final size = renderBox.size;

            final rect = Rect.fromLTWH(
              position.dx,
              position.dy,
              size.width,
              size.height,
            );

            _calculatedBounds['key_$keyValue'] = rect;
            successfulCalculations++;

            print("DEBUG: Calculated bounds for key '$keyValue': $rect");
          } else {
            print("WARNING: Could not get RenderBox for key '$keyValue'");
          }
        } catch (e) {
          print("ERROR: Failed to calculate bounds for key '$keyValue': $e");
        }
      });

      print(
          "DEBUG: Successfully calculated $successfulCalculations/${_keyGlobalKeys.length} key bounds");

      // Notify parent with calculated bounds
      if (widget.onBoundsCalculated != null && _calculatedBounds.isNotEmpty) {
        widget.onBoundsCalculated!(_calculatedBounds);
        print(
            "DEBUG: Notified parent with ${_calculatedBounds.length} keyboard bounds");
      }
    } catch (e) {
      print("ERROR: Failed to calculate keyboard bounds: $e");
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Widget _buildKey(String keyValue, double width, double height) {
    final keyId = 'key_$keyValue';
    final isCurrentlyDwelling = widget.currentDwellingElement == keyId;

    // Determine key display and styling
    String displayText;
    IconData? icon;
    Color keyColor;
    Color textColor;

    switch (keyValue) {
      case 'SPACE':
        displayText = '';
        icon = Icons.space_bar;
        keyColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        break;
      case 'BACKSPACE':
        displayText = '';
        icon = Icons.backspace_outlined;
        keyColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        break;
      case 'ENTER':
        displayText = '';
        icon = Icons.keyboard_return;
        keyColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        break;
      default:
        displayText = keyValue;
        icon = null;
        // Check if it's a number
        if (RegExp(r'^[0-9]$').hasMatch(keyValue)) {
          keyColor = Colors.purple.shade50;
          textColor = Colors.purple.shade800;
        } else {
          // Regular letter
          keyColor = Colors.blue.shade50;
          textColor = Colors.blue.shade800;
        }
    }

    if (isCurrentlyDwelling) {
      keyColor = keyColor == Colors.grey.shade200
          ? Colors.grey.shade300
          : keyColor.withOpacity(0.8);
    }

    return Container(
      key: _keyGlobalKeys[
          keyValue], // CRITICAL: Assign GlobalKey to get position
      width: width,
      height: height,
      child: Material(
        elevation: isCurrentlyDwelling ? 4 : 1,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: keyColor,
            border: Border.all(
              color: isCurrentlyDwelling
                  ? Colors.blue.shade400
                  : Colors.grey.shade300,
              width: isCurrentlyDwelling ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // Progress indicator for dwell time
              if (isCurrentlyDwelling)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    height: 3,
                    width: width * widget.dwellProgress,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // Key content
              Center(
                child: icon != null
                    ? Icon(
                        icon,
                        color: textColor,
                        size: keyValue == 'SPACE' ? 24 : 20,
                      )
                    : Text(
                        displayText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
              ),
              // Dwell progress indicator (circular)
              if (isCurrentlyDwelling)
                Positioned(
                  top: 4,
                  right: 4,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: widget.dwellProgress,
                      strokeWidth: 2,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> row, int rowIndex) {
    final screenWidth = MediaQuery.of(context).size.width;
    final keyboardPadding = 20.0;
    final availableWidth = screenWidth - (keyboardPadding * 2);
    final keySpacing = 4.0;
    final keyHeight = 45.0;

    if (rowIndex == 4) {
      // Special row: SPACE, BACKSPACE, ENTER
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: keyboardPadding),
        child: Row(
          children: [
            _buildKey('SPACE', availableWidth * 0.5, keyHeight),
            SizedBox(width: keySpacing),
            _buildKey('BACKSPACE', availableWidth * 0.25, keyHeight),
            SizedBox(width: keySpacing),
            _buildKey('ENTER', availableWidth * 0.25 - keySpacing, keyHeight),
          ],
        ),
      );
    } else {
      // Regular rows (including the number row)
      final maxKeysPerRow = 10;
      final keyWidth =
          (availableWidth - (keySpacing * (maxKeysPerRow - 1))) / maxKeysPerRow;
      final rowWidth =
          (row.length * keyWidth) + ((row.length - 1) * keySpacing);
      final horizontalPadding =
          keyboardPadding + (availableWidth - rowWidth) / 2;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          children: row.asMap().entries.map((entry) {
            final index = entry.key;
            final key = entry.value;
            return Row(
              children: [
                if (index > 0) SizedBox(width: keySpacing),
                _buildKey(key, keyWidth, keyHeight),
              ],
            );
          }).toList(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // Keyboard layout with proper bounds calculation
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _keyboardLayout.asMap().entries.map((entry) {
                final rowIndex = entry.key;
                final row = entry.value;
                return Column(
                  children: [
                    if (rowIndex > 0) const SizedBox(height: 8),
                    _buildKeyboardRow(row, rowIndex),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Public method to manually trigger bounds recalculation (if needed)
  void recalculateBounds() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateAndNotifyBounds();
    });
  }
}
