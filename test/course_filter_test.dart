import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';

import 'support/course_fixture.dart';
import 'support/hand_items.dart';
import 'support/test_axes.dart';

/// A learner whose course reaches lesson 23: "nauta" is a word of lesson 21,
/// but its type is not taught before lesson 32.
const _lessons = LessonData(
  lessonNames: ['Lektion 21', 'Lektion 32'],
  wordToLesson: {'nauta': 'Lektion 21', 'cornu': 'Lektion 32'},
  lessonWords: {
    'Lektion 21': ['nauta'],
    'Lektion 32': ['cornū'],
  },
  bookByLesson: {21: 2, 32: 2},
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
- lesson: 21
  nouns:
    forms:
      - {name: T}
    types: [O-Deklination]
- lesson: 32
  nouns:
    types: [A-Deklination]
''';

CourseFilter _filter(Settings settings, String curriculum) => CourseFilter(
  settings,
  parseNouns(curriculum, shape: nounShape(labels: _nauta.formLabels)),
  _lessons,
);

void main() {
  test('a word in range whose type comes later is not practised yet', () {
    final filter = _filter(
      Settings().withWordRange(LessonRange(21, 23)),
      _lateType,
    );

    expect(filter.wordInRange(_nauta), isTrue);
    expect(filter.typeInRange('nouns', 'A-Deklination'), isFalse);
    expect(filter.itemPracticed(_nauta), isFalse);
  });

  test('once the type is taught the item is practised', () {
    final filter = _filter(Settings().withWordRange(LessonRange(21, 23)), '''
- lesson: 21
  nouns:
    forms:
      - {name: T}
    types: [A-Deklination, O-Deklination]
''');

    expect(filter.itemPracticed(_nauta), isTrue);
  });

  test('a word the course has not reached is out of range', () {
    final filter = _filter(
      Settings().withWordRange(LessonRange(1, 20)),
      everythingInLessonOne,
    );

    expect(filter.wordInRange(_nauta), isFalse);
    expect(filter.wordPracticed(_nauta), isFalse);
  });

  test('forced-off beats forced-on beats the range', () {
    final inRange = Settings().withWordRange(LessonRange(21, 23));

    expect(
      _filter(
        inRange.toggleWord('nauta', inRange: true),
        everythingInLessonOne,
      ).wordPracticed(_nauta),
      isFalse,
    );

    final outOfRange = Settings().withWordRange(LessonRange(1, 20));
    expect(
      _filter(
        outOfRange.toggleWord('nauta', inRange: false),
        everythingInLessonOne,
      ).wordPracticed(_nauta),
      isTrue,
    );

    final both = Settings(
      deselectedWords: {'nauta'},
      forcedOnTypes: {
        'nouns': {'A-Deklination'},
      },
      courseWords: LessonRange(1, 20),
    );
    expect(_filter(both, everythingInLessonOne).itemPracticed(_nauta), isFalse);
  });

  test('a switched-off axis value beats a forced-on form', () {
    final settings = Settings()
        .toggleFeature('nouns', 'numerus', 'pl')
        .toggleForm('nouns', 'dat.pl', inRange: false);
    final filter = _filter(settings, everythingInLessonOne);

    expect(settings.overrideOfForm('nouns', 'dat.pl'), Override.forcedOn);
    expect(filter.formPracticed('nouns', _nauta.formLabels[2]), isFalse);
  });

  test('practicedForms and summary count what the learner sees', () {
    final filter = _filter(Settings().withWordRange(LessonRange(21, 23)), '''
- lesson: 21
  nouns:
    forms:
      - {name: T}
    types: [A-Deklination, O-Deklination]
- lesson: 32
  nouns:
    forms:
      - {name: T, numerus: pl}
''');

    expect(filter.practicedForms('nouns', _nauta.formLabels), {
      'nom.sg',
      'gen.sg',
    });
    expect(filter.summary(<PracticeItem>[_nauta]), (
      words: 1,
      nounForms: 2,
      verbForms: 0,
    ));
  });

  test('a word without a basic form is a data error', () {
    final noNominative = handItem(
      dataFileId: 'nouns',
      lemma: 'nautae',
      axes: nounAxes,
      type: 'A-Deklination',
      forms: {
        'gen.sg': ['nautae'],
      },
    );
    final filter = _filter(Settings().withWordRange(LessonRange(21, 23)), '''
- lesson: 21
  nouns:
    types: [A-Deklination, O-Deklination]
- lesson: 32
  nouns:
    forms:
      - {name: T}
''');

    expect(
      () => filter.practicedForms('nouns', noNominative.formLabels),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('gen.sg'),
        ),
      ),
    );
  });

  group('grammar topics', () {
    const lateForms = '''
- lesson: 21
  nouns:
    forms:
      - {name: T}
    types: [A-Deklination, O-Deklination]
- lesson: 32
  nouns:
    forms:
      - {name: T, numerus: pl}
''';
    final inRange = Settings().withWordRange(LessonRange(21, 23));

    test('a deselected topic\'s forms are not practised', () {
      final filter = _filter(inRange, lateForms);
      final topic = filter.curriculum.formTopic('nouns', 'nom.sg');
      final switchedOff = _filter(
        inRange.toggleTopic(topic.key, inRange: true),
        lateForms,
      );

      expect(filter.practicedForms('nouns', _nauta.formLabels), {
        'nom.sg',
        'gen.sg',
      });
      expect(switchedOff.practicedForms('nouns', _nauta.formLabels), isEmpty);
      expect(switchedOff.reachesPractice(_nauta), isFalse);
    });

    test('a forced-on later topic\'s forms are practised', () {
      final topic = _filter(
        inRange,
        lateForms,
      ).curriculum.formTopic('nouns', 'dat.pl');
      final filter = _filter(
        inRange.toggleTopic(topic.key, inRange: false),
        lateForms,
      );

      expect(filter.practicedForms('nouns', _nauta.formLabels), {
        'nom.sg',
        'gen.sg',
        'dat.pl',
        'abl.pl',
      });
      expect(filter.formGap('nouns', _nauta.formLabels[2]), isNull);
    });

    test('a deselected type topic keeps its words from practice', () {
      final topic = _filter(
        inRange,
        lateForms,
      ).curriculum.typeTopic('nouns', 'A-Deklination');
      final filter = _filter(
        inRange.toggleTopic(topic.key, inRange: true),
        lateForms,
      );

      expect(filter.itemPracticed(_nauta), isFalse);
      expect(filter.typeGap('nouns', 'A-Deklination'), isNull);
    });
  });
}
