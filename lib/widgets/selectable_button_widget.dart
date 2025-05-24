import 'package:flutter/material.dart';
import '../models/selectable_button.dart';

class SelectableButtonWidget extends StatelessWidget {
  final SelectableButton button;
  final bool isCurrentlyDwelling;
  final double dwellProgress;
  final VoidCallback onDwellStart;
  final VoidCallback onDwellStop;

  const SelectableButtonWidget({
    super.key,
    required this.button,
    required this.isCurrentlyDwelling,
    required this.dwellProgress,
    required this.onDwellStart,
    required this.onDwellStop,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDwellStart(),
      onTapUp: (_) => onDwellStop(),
      onTapCancel: () => onDwellStop(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: double.infinity,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: isCurrentlyDwelling
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrentlyDwelling
                      ? Colors.yellow
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: isCurrentlyDwelling
                    ? [
                        BoxShadow(
                          color: Colors.yellow.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (button.icon != null) ...[
                    Icon(
                      _getIconData(button.icon!),
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    button.text,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: isCurrentlyDwelling
                          ? [
                              const Shadow(
                                color: Colors.yellow,
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrentlyDwelling)
              Positioned(
                bottom: 0,
                left: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  height: 4,
                  width:
                      MediaQuery.of(context).size.width * 0.9 * dwellProgress,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.red],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'settings':
        return Icons.settings;
      case 'person':
        return Icons.person;
      case 'gamepad':
        return Icons.gamepad;
      case 'home':
        return Icons.home;
      case 'volume_up':
        return Icons.volume_up;
      case 'edit':
        return Icons.edit;
      case 'bar_chart':
        return Icons.bar_chart;
      case 'easy':
        return Icons.sentiment_satisfied;
      case 'hard':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.circle;
    }
  }
}
