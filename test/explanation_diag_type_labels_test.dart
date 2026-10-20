import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/trace_fixtures.dart';

Future<List<PracticeItem>> _allItems() async => [
  ...await loadPracticeItems('lib/data/latin_nouns.yaml'),
  ...await loadPracticeItems('lib/data/latin_verbs.yaml'),
];

/// Answers that give the ending another type uses for [key], on [item]'s own
/// stems.
Set<String> _otherTypeAnswers(PracticeItem item, FormKey key) {
  final derivation = item.derivation;
  return {
    for (final template in derivation.grammar.templatesByType.values)
      if (template[key] case final t?)
        if (t.stemName == null)
          t.endings.first
        else if (derivation.stems[t.stemName] case final stem?)
          stem.stem + t.endings.first,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the diagnosis-only phrases do not repeat the ending clause table', () {
    expect(
      endingTypePhrases.keys.toSet().intersection(
        diagnosisOnlyTypePhrases.keys.toSet(),
      ),
      isEmpty,
    );
  });

  test('a type without a phrase throws, naming the type', () {
    expect(
      () => typePhrase('Ohne-Etikett', 'de'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Ohne-Etikett'),
        ),
      ),
    );
  });

  test(
    'no rendered diagnosis line names a type by its internal name',
    () async {
      final texts = await germanTexts();
      final items = await _allItems();
      final types = {
        for (final item in items)
          ...item.derivation.grammar.templatesByType.keys,
      };
      final phrases = [
        for (final phrase in endingTypePhrases.values) phrase['de']!,
        for (final phrase in diagnosisOnlyTypePhrases.values) phrase['de']!,
      ]..sort((a, b) => b.length.compareTo(a.length));
      var lines = 0;
      for (final item in items) {
        for (final key in item.derivation.forms.keys) {
          final index = item.formOrder.indexOf(key);
          for (final answer in _otherTypeAnswers(item, key)) {
            if (item.accepts(index, answer)) continue;
            for (final line in explainWrongAnswer(item, key, answer)) {
              if (line.key != 'explain.diag.otherType') continue;
              lines++;
              var rest = renderDe(
                texts,
                line,
              ).replaceFirst('Du hast $answer geschrieben – ', '');
              for (final phrase in phrases) {
                rest = rest.replaceAll(phrase, '');
              }
              for (final type in types) {
                expect(
                  rest,
                  isNot(contains(type)),
                  reason: '${item.lemma} $key',
                );
              }
            }
          }
        }
      }
      expect(lines, greaterThan(10000));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
