/// Shapes and curricula built by hand, so the course laws are tested
/// against a handful of forms instead of the real data.
library;

import 'package:latin_practice/data/curriculum.dart';
import 'package:latin_practice/models/form_label.dart';

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

/// A curriculum that teaches every fixture form and type in lesson 1.
const everythingInLessonOne = '''
- lesson: 1
  nouns:
    forms:
      - {}
    types: [A-Deklination, O-Deklination]
''';
