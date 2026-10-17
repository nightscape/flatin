import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/trace_fixtures.dart';

Future<List<PracticeItem>> _allItems() async => [
  ...await loadPracticeItems('lib/data/latin_nouns.yaml'),
  ...await loadPracticeItems('lib/data/latin_verbs.yaml'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every type whose ending can be named has a display phrase', () {
    final shown = borrowedEndings.values.expand((types) => types).toSet();
    expect(endingTypePhrases.keys.toSet(), shown);
  });

  test('a shown ending type without a phrase throws, naming the type', () {
    expect(
      () => endingTypePhrase('Ohne-Etikett'),
      throwsA(predicate((e) => e.toString().contains('Ohne-Etikett'))),
    );
  });

  test(
    'no rendered clause names an ending type by its internal name',
    () async {
      final texts = await germanTexts();
      final phrases = endingTypePhrases.values.toSet();
      var clauses = 0;
      for (final item in await _allItems()) {
        for (final key in item.derivation.forms.keys) {
          for (final line in [
            ...explainForm(item, [key]),
            ...explainWrongAnswer(item, key, 'zzz'),
          ]) {
            final phrase = line.params['endingType'];
            if (phrase == null) continue;
            clauses++;
            expect(phrases, contains(phrase), reason: item.lemma);
            expect(renderDe(texts, line), endsWith('$phrase)'));
          }
        }
      }
      expect(clauses, greaterThan(0));
    },
  );
}
