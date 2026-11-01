import 'lesson_range.dart';
import 'settings.dart';

/// The preset ranges of a Lernziel row for the class at [kursstand]: the
/// Kursstand lesson alone, its volume up to it, and every lesson up to it,
/// each distinct range once in that order.
List<LessonRange> chipsFor(int kursstand, List<int> bookStarts) => {
  LessonRange(kursstand, kursstand),
  LessonRange(bookStarts.lastWhere((s) => s <= kursstand), kursstand),
  LessonRange(1, kursstand),
}.toList();

/// One chip of a row: a preset, or with a null [preset] the custom chip that
/// shows a range equal to no preset.
typedef LernzielChip = ({LessonRange? preset, bool selected});

/// The chips a row shows for [range]: the presets, then the custom chip while
/// [range] equals none of them. Exactly one chip is selected.
List<LernzielChip> lernzielRow(LessonRange range, List<LessonRange> presets) =>
    [
      for (final p in presets) (preset: p, selected: p == range),
      if (!presets.contains(range)) (preset: null, selected: true),
    ];

/// `L24`, `L20–L24`, or with the open end `L3–[later]`.
String lernzielLabel(LessonRange range, String later) {
  String stop(int lesson) => lesson == laterLesson ? later : 'L$lesson';
  return range.from == range.to
      ? stop(range.from)
      : '${stop(range.from)}–${stop(range.to)}';
}

/// What a tap on [preset] in the word row, or else the grammar row, makes of
/// [settings]: that row's range is [preset]; the link rule of [Settings]
/// moves a linked grammar bound with the words.
Settings chooseLernziel(
  Settings settings,
  LessonRange preset, {
  required bool words,
}) =>
    words ? settings.withWordRange(preset) : settings.withGrammarRange(preset);
