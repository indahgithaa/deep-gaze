// File: lib/models/lecture_note.dart
class LectureNote {
  final String id;
  final String title;
  final String content;
  final Duration duration;
  final DateTime timestamp;

  LectureNote({
    required this.id,
    required this.title,
    required this.content,
    required this.duration,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'duration': duration.inSeconds,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LectureNote.fromJson(Map<String, dynamic> json) {
    return LectureNote(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      duration: Duration(seconds: json['duration']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  // Create a copy with modified fields
  LectureNote copyWith({
    String? id,
    String? title,
    String? content,
    Duration? duration,
    DateTime? timestamp,
  }) {
    return LectureNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'LectureNote(id: $id, title: $title, duration: $duration, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LectureNote &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.duration == duration &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        content.hashCode ^
        duration.hashCode ^
        timestamp.hashCode;
  }
}
