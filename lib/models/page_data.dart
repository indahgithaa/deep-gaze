import 'selectable_button.dart';

class PageData {
  final String title;
  final String subtitle;
  final List<SelectableButton> buttons;
  final String? backgroundImagePath;

  PageData({
    required this.title,
    required this.subtitle,
    required this.buttons,
    this.backgroundImagePath,
  });
}
