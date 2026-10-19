import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';

import 'support/course_fixture.dart';
import 'support/hand_items.dart';
import 'support/test_axes.dart';

const _lessons = LessonData(
  lessonNames: ['Lektion 21'],
  wordToLesson: {'nauta': 'Lektion 21'},
  lessonWords: {
    'Lektion 21': ['nauta'],
  },
  bookByLesson: {21: 2},
);

final _nauta = handItem(
  dataFileId: 'nouns',
  lemma: 'nauta',
  axes: nounAxes,
  type: 'A-Deklination',
  forms: {
    'nom.sg': ['nauta'],
    'gen.sg': ['nautae'],
    'dat.pl': ['nautīs'],
    'abl.pl': ['nautīs'],
  },
);

const _lateType = '''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [O-Deklination]
- lesson: 32
  nouns:
    types: [A-Deklination]
''';

const _lateGenitive = '''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination]
- lesson: 30
  nouns:
    forms:
      - {kasus: gen}
''';

const _lateForms = '''
- lesson: 1
  nouns:
    types: [A-Deklination, O-Deklination]
- lesson: 30
  nouns:
    forms:
      - {}
''';

CourseFilter _filter(Settings settings, String curriculum) => CourseFilter(
      settings,
      parseNouns(curriculum, shape: nounShape(labels: _nauta.formLabels)),
      _lessons,
    );

final _inRange = Settings().withWordRange(LessonRange(21, 23));
final _gen = _nauta.formLabels.firstWhere((l) => l.key == 'gen.sg');

void main() {
  group('a gap is cleared by the force-on override of its own row', () {
    test('type gap on the word row and the type row', () {
      final forced = _inRange.copyWith(forcedOnTypes: {
        'nouns': {'A-Deklination'},
      });

      expect(_filter(_inRange, _lateType).wordGap(_nauta),
          isA<FromLesson>());
      expect(_filter(_inRange, _lateType).typeGap('nouns', 'A-Deklination'),
          isA<FromLesson>());
      expect(_filter(forced, _lateType).wordGap(_nauta), isNull);
      expect(_filter(forced, _lateType).typeGap('nouns', 'A-Deklination'),
          isNull);
    });

    test('word gap on the word row', () {
      final outside = Settings().withWordRange(LessonRange(1, 5));
      final forced = outside.copyWith(forcedOnWords: {'nauta'});

      expect(_filter(outside, everythingInLessonOne).wordGap(_nauta),
          isA<OutsideRange>());
      expect(_filter(forced, everythingInLessonOne).wordGap(_nauta), isNull);
    });

    test('form gap on the form row', () {
      final forced = _inRange.copyWith(forcedOnForms: {
        'nouns': {'gen.sg'},
      });

      expect(_filter(_inRange, _lateGenitive).formGap('nouns', _gen),
          isA<FromLesson>());
      expect(_filter(forced, _lateGenitive).formGap('nouns', _gen), isNull);
    });
  });

  test('a word whose forms are all taught later is greyed from that lesson',
      () {
    final filter = _filter(_inRange, _lateForms);

    expect(filter.reachesPractice(_nauta), isFalse);
    final gap = filter.wordGap(_nauta);
    expect(gap, isA<FromLesson>());
    expect((gap as FromLesson).lesson, 30);
  });

  test('a form forced on clears the gap of a word with late forms', () {
    final forced = _inRange.copyWith(forcedOnForms: {
      'nouns': {'gen.sg'},
    });
    final filter = _filter(forced, _lateForms);

    expect(filter.reachesPractice(_nauta), isTrue);
    expect(filter.wordGap(_nauta), isNull);
  });

  test('a word whose forms are all switched off has no course gap', () {
    final off = _inRange.copyWith(disabledForms: {
      'nouns': {for (final l in _nauta.formLabels) l.key},
    });

    expect(_filter(off, everythingInLessonOne).wordGap(_nauta), isNull);
  });

  test('a gap below the grammar range is not the word-axis gap', () {
    final settings = Settings(
      grammarFollowsWords: false,
      courseGrammar: LessonRange(5, 40),
    );
    const early = '''
- lesson: 2
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination]
''';

    final gap = _filter(settings, early).typeGap('nouns', 'A-Deklination');
    expect(gap, isNotNull);
    expect(gap, isNot(isA<OutsideRange>()));
  });

  test('an item with a gap is exactly an item practice does not offer', () {
    for (final curriculum in [_lateType, _lateGenitive, _lateForms]) {
      for (final settings in [
        _inRange,
        _inRange.copyWith(forcedOnWords: {'nauta'}),
        _inRange.copyWith(forcedOnTypes: {
          'nouns': {'A-Deklination'},
        }),
      ]) {
        final filter = _filter(settings, curriculum);
        expect(filter.wordGap(_nauta) == null, filter.reachesPractice(_nauta),
            reason: '$curriculum $settings');
      }
    }
  });
}
