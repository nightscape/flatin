/// A closed interval of lesson numbers, the learner's course position.
final class LessonRange {
  final int from, to;

  LessonRange(this.from, this.to) {
    assert(
      1 <= from && from <= to,
      'lesson range $from..$to is not 1 <= from <= to',
    );
  }

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
