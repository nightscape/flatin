import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/diagnosis.dart';
import 'package:latin_practice/data/explanation.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:yaml/yaml.dart';

const _assets = ['lib/data/latin_nouns.yaml', 'lib/data/latin_verbs.yaml'];

// The verbs have 284 keys; the pairwise checks sample them so the file runs in
// seconds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T-diag-1 another form of the same word is recognised', () {
    for (final asset in _assets) {
      test(asset, () async {
        int checked = 0;
        for (final item in await loadPracticeItems(asset)) {
          for (int k = 0; k < item.formOrder.length; k += 37) {
            for (int j = 0; j < item.formOrder.length; j += 11) {
              if (item.accepts(k, item.forms[j])) continue;
              checked++;
              final result = diagnose(item, item.formOrder[k], item.forms[j]);
              final where =
                  '${item.translation}: ${item.formOrder[k]} '
                  'answered with ${item.forms[j]}';
              if (result is RegularInsteadOfIrregular) continue;
              expect(result, isA<OtherFormOfWord>(), reason: where);
              expect(
                (result as OtherFormOfWord).formKeys,
                orderedEquals([
                  for (int o = 0; o < item.formOrder.length; o++)
                    if (o != k && item.accepts(o, item.forms[j]))
                      item.formOrder[o],
                ]),
                reason: where,
              );
            }
          }
        }
        expect(checked, greaterThan(0));
      });
    }
  });

  group('T-diag-2 the ending of another type is recognised', () {
    for (final asset in _assets) {
      test(asset, () async {
        int checked = 0;
        final parents = await _parentTypes(asset);
        for (final item in await loadPracticeItems(asset)) {
          for (final formKey in item.formOrder.indexed
              .where((e) => e.$1 % 7 == 0)
              .map((e) => e.$2)) {
            final asked = item.derivation.forms[formKey]!;
            for (final entry
                in item.derivation.grammar.templatesByType.entries) {
              if (entry.key == item.type) continue;
              final template = entry.value[formKey];
              if (template == null) continue;
              final stemName = template.stemName;
              final stem = stemName == null
                  ? ''
                  : item.derivation.stems[stemName]?.stem;
              if (stem == null) continue;
              final candidate = stem + template.endings.first;
              // Earlier steps own these answers: they are a form of the word
              // itself, or the regular variant of an irregular form.
              if (List.generate(item.formOrder.length, (j) => j)
                  .any((j) => item.accepts(j, candidate))) {
                continue;
              }
              if (asked is IrregularForm &&
                  asked.regular != null &&
                  asked.regular!.variants.any((v) => norm(v) == norm(candidate))) {
                continue;
              }
              checked++;
              final result = diagnose(item, formKey, candidate);
              final where =
                  '${item.translation}: $formKey answered with $candidate';
              expect(result, isA<EndingOfOtherType>(), reason: where);
              final types = (result as EndingOfOtherType).types;
              expect(types, contains(entry.key), reason: where);
              // R1: an inherited ending names the parent type, never both.
              for (final type in types) {
                expect(types, isNot(contains(parents[type])), reason: where);
              }
            }
          }
        }
        expect(checked, greaterThan(0));
      });
    }
  });

  group('T-diag-3 wrong stem, macrons and nonsense', () {
    for (final asset in _assets) {
      test(asset, () async {
        int checked = 0;
        for (final item in await loadPracticeItems(asset)) {
          for (int i = 0; i < item.formOrder.length; i++) {
            final form = item.derivation.forms[item.formOrder[i]]!;
            if (form is! GeneratedForm) continue;
            checked++;
            final formKey = item.formOrder[i];
            final where = '${item.translation}: $formKey';

            expect(
              diagnose(item, formKey, 'xq${form.ending}'),
              isA<WrongStem>()
                  .having((d) => d.usedStem, 'usedStem', 'xq')
                  .having((d) => d.stemName, 'stemName', form.stemName),
              reason: where,
            );
            // An empty ending accepts any text as a stem.
            expect(
              diagnose(item, formKey, 'zzz'),
              form.ending.isEmpty ? isA<WrongStem>() : isA<NoMatch>(),
              reason: where,
            );

            // Q11 A: the macrons are no wrong answer any more; the correct
            // answer carries the marked spelling as an info line.
            final macronised = _macronise(item.forms[i]);
            if (macronised != null) {
              expect(item.accepts(i, macronised), isTrue, reason: where);
              expect(
                explainCorrectAnswer(item, formKey, macronised)
                    .map((line) => line.params['result']),
                [item.forms[i]],
                reason: where,
              );
            }
          }
        }
        expect(checked, greaterThan(0));
      });
    }
  });

  group('T-diag-4 goldens', () {
    late List<PracticeItem> nouns;
    setUp(() async => nouns = await loadPracticeItems(_assets.first));

    PracticeItem byWord(String word) =>
        nouns.firstWhere((item) => item.lemma == word);

    test('dominis is the dative/ablative plural, not the genitive', () {
      final result = diagnose(byWord('dominus'), 'gen.pl', 'dominis');
      expect(
        result,
        isA<OtherFormOfWord>().having(
          (d) => d.formKeys,
          'formKeys',
          orderedEquals(['dat.pl', 'abl.pl']),
        ),
      );
    });

    test('rosorum is an o-declension ending', () {
      final result = diagnose(byWord('rosa'), 'gen.pl', 'rosorum');
      expect(
        result,
        isA<EndingOfOtherType>().having(
          (d) => d.types,
          'types',
          contains('O-Deklination-maskulinum'),
        ),
      );
    });

    test('dominusorum keeps the whole nominative as stem', () {
      final result = diagnose(
        byWord('dominus'),
        'gen.pl',
        'dominusorum',
      );
      expect(
        result,
        isA<WrongStem>()
            .having((d) => d.usedStem, 'usedStem', 'dominus')
            .having((d) => d.stemName, 'stemName', 'stamm'),
      );
    });

    test('the ending of an inheriting type is named by its parent only', () async {
      final verbs = await loadPracticeItems(_assets.last);
      final item = verbs.firstWhere((i) => i.lemma == 'amāre');
      final result = diagnose(item, 'ind.praes.akt.1.sg', 'amāō');
      expect(
        result,
        isA<EndingOfOtherType>().having(
          (d) => d.types,
          'types',
          orderedEquals(['I-Konjugation', 'Konsonantische']),
        ),
      );
    });
  });
}

/// Type → the type it inherits from, for the types of one YAML file.
Future<Map<String, String>> _parentTypes(String asset) async {
  final yaml = loadYaml(await rootBundle.loadString(asset)) as YamlMap;
  return {
    for (final entry in (yaml['types'] as YamlMap).entries)
      if ((entry.value as YamlMap)['inherits_from'] != null)
        entry.key as String:
            (entry.value as YamlMap)['inherits_from'] as String,
  };
}

/// The same word with one macron added, or null if it has no plain vowel.
String? _macronise(String word) {
  const macrons = {'a': 'ā', 'e': 'ē', 'i': 'ī', 'o': 'ō', 'u': 'ū'};
  for (int i = 0; i < word.length; i++) {
    final macron = macrons[word[i]];
    if (macron != null) {
      return word.substring(0, i) + macron + word.substring(i + 1);
    }
  }
  return null;
}
