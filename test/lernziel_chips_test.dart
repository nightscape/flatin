// Properties of the Lernziel chip rows over any settings of the real
// course: the presets are the distinct ranges of the Kursstand alone, its
// volume up to it and every lesson up to it; each row shows exactly one
// selected chip, the custom one only while the range equals no preset; a
// tap on a preset sets that row's range and moves the other row only by the
// link rule; after a Kursstand change the presets follow it.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/lernziel_chips.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';

import 'support/gen_settings.dart';

const _later = 'Später';

/// The presets for [kursstand], written out: the three ranges in their
/// order, each one kept only where it is new.
List<LessonRange> _presetsOracle(int kursstand, List<int> bookStarts) {
  final volume = bookStarts.where((s) => s <= kursstand).reduce(max);
  final all = [
    LessonRange(kursstand, kursstand),
    LessonRange(volume, kursstand),
    LessonRange(1, kursstand),
  ];
  return [
    for (var i = 0; i < all.length; i++)
      if (!all.take(i).contains(all[i])) all[i],
  ];
}

/// [settings] as stored, without its course ranges.
Map<String, dynamic> _rest(Settings settings) => settings.toJson()
  ..remove('courseWords')
  ..remove('courseGrammar');

/// The grammar range the link rule makes of [grammar] with words [words].
LessonRange _linked(LessonRange words, LessonRange grammar, Settings s) {
  final start = s.grammarFromLinked ? words.from : grammar.from;
  final end = s.grammarToLinked ? words.to : grammar.to;
  return s.grammarFromLinked
      ? LessonRange(start, max(start, end))
      : LessonRange(min(start, end), end);
}

void _checkRow(LessonRange range, List<LessonRange> presets, String when) {
  final row = lernzielRow(range, presets);
  final selected = row.where((c) => c.selected).toList();
  expect(selected, hasLength(1), reason: '$when: one selected chip');
  final custom = row.where((c) => c.preset == null).toList();
  expect(
    custom.length,
    presets.contains(range) ? 0 : 1,
    reason: '$when: the custom chip only off the presets',
  );
  expect(
    selected.single.preset,
    presets.contains(range) ? range : null,
    reason: '$when: the equal preset, else the custom chip',
  );
  expect(
    [
      for (final c in row)
        if (c.preset != null) c.preset,
    ],
    presets,
    reason: '$when: the presets in order',
  );
  expect(
    lernzielLabel(selected.single.preset ?? range, _later),
    lernzielLabel(range, _later),
    reason: '$when: the selected label names the range',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<int> bookStarts;

  setUpAll(() async {
    bookStarts = (await loadLessonData(bookAssets)).bookStarts;
    expect(bookStarts.length, greaterThan(1), reason: 'the course has volumes');
  });

  test('the presets are the distinct ranges up to the Kursstand', () {
    for (var k = 1; k <= lastLesson; k++) {
      final presets = chipsFor(k, bookStarts);
      expect(presets, _presetsOracle(k, bookStarts), reason: 'Kursstand $k');
      expect(presets.toSet(), hasLength(presets.length), reason: 'L$k');
      for (final p in presets) {
        expect(p.to, k, reason: 'Kursstand $k: $p ends at it');
      }
      // In the first volume and at a volume start two ranges coincide.
      final expected = k == 1
          ? 1
          : (k < bookStarts[1] || bookStarts.contains(k) ? 2 : 3);
      expect(presets, hasLength(expected), reason: 'Kursstand $k');
    }
    expect(chipsFor(1, bookStarts), [LessonRange(1, 1)]);
    expect(chipsFor(21, bookStarts), [LessonRange(21, 21), LessonRange(1, 21)]);
    expect(chipsFor(24, bookStarts), [
      LessonRange(24, 24),
      LessonRange(21, 24),
      LessonRange(1, 24),
    ]);
    expect(chipsFor(lastLesson, bookStarts), [
      LessonRange(lastLesson, lastLesson),
      LessonRange(21, lastLesson),
      LessonRange(1, lastLesson),
    ]);
  });

  test('every range has its own label', () {
    final ranges = [
      for (var from = 1; from <= laterLesson; from++)
        for (var to = from; to <= laterLesson; to++) LessonRange(from, to),
    ];
    final labels = {for (final r in ranges) lernzielLabel(r, _later)};
    expect(labels, hasLength(ranges.length));
    expect(lernzielLabel(LessonRange(24, 24), _later), 'L24');
    expect(lernzielLabel(LessonRange(20, 24), _later), 'L20–L24');
    expect(lernzielLabel(LessonRange(3, laterLesson), _later), 'L3–Später');
  });

  test('each row selects exactly one chip for any range and Kursstand', () {
    final fixed = <(int, LessonRange)>[
      (1, LessonRange(1, 1)),
      (1, LessonRange(1, 2)),
      (21, LessonRange(21, 21)),
      (21, LessonRange(1, 21)),
      (21, LessonRange(20, 21)),
      (24, LessonRange(24, 24)),
      (24, LessonRange(21, 24)),
      (24, LessonRange(1, 24)),
      (24, LessonRange(20, 24)),
      (24, LessonRange(25, 30)),
      (24, LessonRange(3, laterLesson)),
      (lastLesson, LessonRange(lastLesson, lastLesson)),
      (lastLesson, LessonRange(1, laterLesson)),
      (lastLesson, LessonRange(laterLesson, laterLesson)),
    ];
    for (final (k, range) in fixed) {
      _checkRow(range, chipsFor(k, bookStarts), 'K$k, $range');
    }
    final rng = Random(351);
    for (var i = 0; i < 2000; i++) {
      final s = drawLernzielSettings(rng, bookStarts);
      final presets = chipsFor(s.kursstand, bookStarts);
      for (final range in [s.courseWords, s.courseGrammar]) {
        _checkRow(range, presets, 'case $i, K${s.kursstand}, $range');
      }
    }
  });

  test('a preset tap sets its row and moves the other only by the link '
      'rule', () {
    final fixed = [
      Settings(kursstand: 1),
      Settings(courseWords: LessonRange(3, 30), kursstand: 21),
      Settings(
        courseWords: LessonRange(25, 30),
        courseGrammar: LessonRange(26, laterLesson),
        grammarFromLinked: true,
        kursstand: 24,
      ),
      Settings(
        courseWords: LessonRange(5, 10),
        courseGrammar: LessonRange(30, 35),
        grammarToLinked: false,
        kursstand: 24,
      ),
      Settings(
        courseWords: LessonRange(1, laterLesson),
        grammarToLinked: false,
        courseGrammar: LessonRange(2, laterLesson),
        kursstand: lastLesson,
      ),
    ];
    final rng = Random(3510);
    final cases = [
      ...fixed,
      for (var i = 0; i < 2000; i++) drawLernzielSettings(rng, bookStarts),
    ];
    for (final (i, s) in cases.indexed) {
      for (final preset in chipsFor(s.kursstand, bookStarts)) {
        final when = 'case $i, K${s.kursstand}, $preset';
        final words = chooseLernziel(s, preset, words: true);
        expect(words.courseWords, preset, reason: '$when: word row');
        expect(
          words.courseGrammar,
          _linked(preset, s.courseGrammar, s),
          reason: '$when: grammar by the link rule',
        );
        expect(_rest(words), _rest(s), reason: '$when: nothing else moves');
        if (!s.grammarFromLinked && !s.grammarToLinked) {
          expect(words.courseGrammar, s.courseGrammar, reason: when);
        }

        final grammar = chooseLernziel(s, preset, words: false);
        expect(grammar.courseGrammar, preset, reason: '$when: grammar row');
        expect(grammar.courseWords, s.courseWords, reason: '$when: words');
        expect(
          _rest(grammar),
          _rest(s)
            ..['grammarFromLinked'] =
                s.grammarFromLinked && preset.from == s.courseGrammar.from
            ..['grammarToLinked'] =
                s.grammarToLinked && preset.to == s.courseGrammar.to,
          reason: '$when: a moved linked grammar bound unlinks, nothing else',
        );
        _checkRow(words.courseWords, chipsFor(s.kursstand, bookStarts), when);
        _checkRow(
          grammar.courseGrammar,
          chipsFor(s.kursstand, bookStarts),
          when,
        );
      }
    }
  });

  test('after a Kursstand change the presets and the selection follow', () {
    final fixed = <(Settings, int)>[
      (Settings(courseWords: LessonRange(1, 24), kursstand: 24), 25),
      (Settings(courseWords: LessonRange(21, 24), kursstand: 24), 25),
      (Settings(courseWords: LessonRange(20, 20), kursstand: 20), 21),
      (Settings(courseWords: LessonRange(1, 2), kursstand: 2), 1),
      (Settings(courseWords: LessonRange(30, 35), kursstand: 24), 25),
      (Settings(kursstand: lastLesson), 1),
    ];
    final rng = Random(3511);
    final cases = [
      ...fixed,
      for (var i = 0; i < 2000; i++)
        (drawLernzielSettings(rng, bookStarts), 1 + rng.nextInt(lastLesson)),
    ];
    for (final (i, (s, n)) in cases.indexed) {
      final next = s.withKursstand(n);
      final presets = chipsFor(n, bookStarts);
      final when = 'case $i, K${s.kursstand} -> $n';
      expect(presets, _presetsOracle(n, bookStarts), reason: when);
      for (final (before, after) in [
        (s.courseWords, next.courseWords),
        (s.courseGrammar, next.courseGrammar),
      ]) {
        _checkRow(after, presets, '$when, $after');
        if (before == LessonRange(1, s.kursstand)) {
          expect(after, LessonRange(1, n), reason: '$when: all up to it');
        }
        final volume = bookStarts.where((b) => b <= s.kursstand).reduce(max);
        if (before == LessonRange(volume, s.kursstand) &&
            bookStarts.where((b) => b <= n).reduce(max) == volume) {
          expect(after, LessonRange(volume, n), reason: '$when: its volume');
        }
      }
    }
  });
}
