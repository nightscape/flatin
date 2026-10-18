import '../data/lesson_data.dart' show lastLesson;

/// The stop beyond the last lesson: what the course never reaches.
const int laterLesson = lastLesson + 1;

/// A closed interval of lesson numbers, the learner's course position.
final class LessonRange {
  final int from, to;

  LessonRange(this.from, this.to) {
    assert(
      1 <= from && from <= to && to <= laterLesson,
      'lesson range $from..$to is outside 1..$laterLesson',
    );
  }

  /// Every lesson of the word lists.
  static final fullWords = LessonRange(1, lastLesson);

  /// Every lesson plus the "later" stop for what no lesson teaches.
  static final fullGrammar = LessonRange(1, laterLesson);

  /// The grammar range that trails [words]: everything taught up to its end,
  /// and with the words at their top also what no lesson teaches.
  static LessonRange grammarFollowing(LessonRange words) =>
      words.to == lastLesson ? fullGrammar : LessonRange(1, words.to);

  bool contains(int lesson) => from <= lesson && lesson <= to;

  Map<String, dynamic> toJson() => {'from': from, 'to': to};

  factory LessonRange.fromJson(Map<String, dynamic> json) =>
      LessonRange(json['from'] as int, json['to'] as int);

  @override
  bool operator ==(Object other) =>
      other is LessonRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'LessonRange($from..$to)';
}
