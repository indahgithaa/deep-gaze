import 'package:deep_gaze/models/question.dart';

class QuizResult {
  final int totalQuestions;
  final int correctAnswers;
  final List<int> userAnswers;
  final List<Question> questions;
  final DateTime completedAt;

  QuizResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.userAnswers,
    required this.questions,
    required this.completedAt,
  });

  double get percentage => (correctAnswers / totalQuestions) * 100;

  String get grade {
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }
}
