/// Shapes and curricula built by hand, so the course laws are tested
/// against a handful of forms instead of the real data.
library;

import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/data/lesson_data.dart';
import 'package:latin_practice/models/course_filter.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';

import 'test_axes.dart';

final fixtureLabels = [
  nounLabel('nom', 'sg'),
  nounLabel('gen', 'sg'),
  nounLabel('dat', 'pl'),
  nounLabel('abl', 'pl'),
];

const fixtureTypes = ['A-Deklination', 'O-Deklination'];

DataFileShape nounShape({List<FormLabel>? labels, List<String>? types}) =>
    (labels: labels ?? fixtureLabels, types: types ?? fixtureTypes);

Curriculum parseNouns(String yaml, {DataFileShape? shape}) =>
    Curriculum.parse([yaml], {'nouns': shape ?? nounShape()});

/// Every order of [items], so an order-independent law can be stated over
/// all of them instead of over two hand-picked orders.
Iterable<List<T>> permutations<T>(List<T> items) sync* {
  if (items.length <= 1) {
    yield List.of(items);
    return;
  }
  for (var i = 0; i < items.length; i++) {
    final rest = [...items]..removeAt(i);
    for (final tail in permutations(rest)) {
      yield [items[i], ...tail];
    }
  }
}

/// A curriculum that teaches every fixture form and type in lesson 1.
const everythingInLessonOne = '''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination]
''';

/// A filter whose course has taught [item] completely, so only the learner's
/// overrides decide what is practised.
CourseFilter filterTeachingAll(Settings settings, PracticeItem item) =>
    CourseFilter(
      settings,
      Curriculum.parse(
        [
          '- lesson: 1\n'
              '  ${item.dataFileId}:\n'
              '    forms:\n'
              '      - {}\n'
              '    types: [${item.type}]\n',
        ],
        {
          item.dataFileId: (labels: item.formLabels, types: [item.type]),
        },
      ),
      LessonData(
        lessonNames: const ['Lektion 1'],
        wordToLesson: {item.lemma: 'Lektion 1'},
        lessonWords: {
          'Lektion 1': [item.lemma],
        },
        bookByLesson: const {1: 1},
      ),
    );
