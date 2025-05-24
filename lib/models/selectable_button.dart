class SelectableButton {
  final String id;
  final String text;
  final dynamic Function() action;
  final String? icon;

  SelectableButton({
    required this.id,
    required this.text,
    required this.action,
    this.icon,
  });
}
