import 'package:deep_gaze/models/topic.dart';

class Subject {
  final String id;
  final String name;
  final String teacher;
  final String iconName;
  final List<String> colors;
  final List<Topic> topics;

  Subject({
    required this.id,
    required this.name,
    required this.teacher,
    required this.iconName,
    required this.colors,
    required this.topics,
  });
}
