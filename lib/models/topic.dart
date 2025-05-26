import 'package:deep_gaze/models/question.dart';

class Topic {
  final String id;
  final String name;
  final String type; // "Tugas", "Materi", "Kuis"
  final bool isCompleted;
  final List<Question>? questions; // null if not a quiz

  Topic({
    required this.id,
    required this.name,
    required this.type,
    this.isCompleted = false,
    this.questions,
  });
}
