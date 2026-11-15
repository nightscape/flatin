import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart';

import 'support/diagnosis_only_types.dart';

Future<Grammar> _grammar() async =>
    (await loadAllPracticeItems()).first.derivation.grammar;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every type whose ending can be named has a display phrase', () async {
    final grammar = await _grammar();
    final shown = grammar.borrowsByType.values.expand((types) => types).toSet();
    expect(
      grammar.phraseByType.keys.toSet().difference(diagnosisOnlyTypes),
      shown,
    );
  });

  test('every type phrase exists in every data language', () async {
    for (final phrases in (await _grammar()).phraseByType.values) {
      expect(phrases.keys, unorderedEquals(dataLanguages), reason: '$phrases');
    }
  });

  test(
    'a shown ending type without a phrase throws, naming the type',
    () async {
      final grammar = await _grammar();
      expect(
        () => typePhrase(grammar, 'Ohne-Etikett'),
        throwsA(predicate((e) => e.toString().contains('Ohne-Etikett'))),
      );
    },
  );
}
