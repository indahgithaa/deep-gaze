// File: lib/models/lecture_note.dart
class LectureNote {
  final String id;
  final String title;
  final String content;
  final Duration duration;
  final DateTime timestamp;
  final List<String> tags;
  final String? audioFilePath;

  LectureNote({
    required this.id,
    required this.title,
    required this.content,
    required this.duration,
    required this.timestamp,
    this.tags = const [],
    this.audioFilePath,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'duration': duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'tags': tags,
      'audioFilePath': audioFilePath,
    };
  }

  // Create from JSON
  factory LectureNote.fromJson(Map<String, dynamic> json) {
    return LectureNote(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      duration: Duration(milliseconds: json['duration']),
      timestamp: DateTime.parse(json['timestamp']),
      tags: List<String>.from(json['tags'] ?? []),
      audioFilePath: json['audioFilePath'],
    );
  }

  // Create a copy with updated fields
  LectureNote copyWith({
    String? title,
    String? content,
    Duration? duration,
    DateTime? timestamp,
    List<String>? tags,
    String? audioFilePath,
  }) {
    return LectureNote(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      tags: tags ?? this.tags,
      audioFilePath: audioFilePath ?? this.audioFilePath,
    );
  }

  // Get formatted duration string
  String get formattedDuration {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  // Get formatted timestamp
  String get formattedTimestamp {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
  }

  // Get word count
  int get wordCount {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }

  // Get character count (excluding spaces)
  int get characterCount {
    return content.replaceAll(RegExp(r'\s+'), '').length;
  }
}
