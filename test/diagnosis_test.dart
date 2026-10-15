import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/diagnosis.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:yaml/yaml.dart';

const _assets = ['lib/data/latin_nouns.yaml', 'lib/data/latin_verbs.yaml'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T-diag-1 another form of the same word is recognised', () {
    for (final asset in _assets) {
      test(asset, () async {
        int checked = 0;
        for (final item in await loadPracticeItems(asset)) {
          for (int k = 0; k < item.formOrder.length; k++) {
            for (int j = 0; j < item.formOrder.length; j++) {
              if (norm(item.forms[j]) == norm(item.forms[k])) continue;
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
                    if (o != k && norm(item.forms[o]) == norm(item.forms[j]))
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
          final stem = item.derivation.stem;
          if (stem == null) continue;
          for (final formKey in item.formOrder) {
            final asked = item.derivation.forms[formKey]!;
            for (final entry
                in item.derivation.grammar.templatesByType.entries) {
              if (entry.key == item.type) continue;
              final template = entry.value[formKey];
              if (template == null) continue;
              final candidate = template.replaceAll('{stem}', stem.stem);
              // Earlier steps own these answers: they are a form of the word
              // itself, or the regular variant of an irregular form.
              if (item.forms.any((f) => norm(f) == norm(candidate))) continue;
              if (asked is IrregularForm &&
                  asked.regular != null &&
                  norm(asked.regular!.result) == norm(candidate)) {
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
              isA<WrongStem>().having((d) => d.usedStem, 'usedStem', 'xq'),
              reason: where,
            );
            expect(
              diagnose(item, formKey, 'zzz'),
              isA<NoMatch>(),
              reason: where,
            );

            final macronised = _macronise(item.forms[i]);
            if (macronised != null) {
              expect(
                diagnose(item, formKey, macronised),
                isA<OnlyDiacritics>(),
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
        nouns.firstWhere((item) => item.word == word);

    test('dominis is the dative/ablative plural, not the genitive', () {
      final result = diagnose(byWord('dominus'), 'genitive_plural', 'dominis');
      expect(
        result,
        isA<OtherFormOfWord>().having(
          (d) => d.formKeys,
          'formKeys',
          orderedEquals(['dative_plural', 'ablative_plural']),
        ),
      );
    });

    test('rosorum is an o-declension ending', () {
      final result = diagnose(byWord('rosa'), 'genitive_plural', 'rosorum');
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
        'genitive_plural',
        'dominusorum',
      );
      expect(
        result,
        isA<WrongStem>().having((d) => d.usedStem, 'usedStem', 'dominus'),
      );
    });

    test('an inherited ending names only the parent type', () async {
      final verbs = await loadPracticeItems(_assets.last);
      final item = verbs.firstWhere((i) => i.baseForm == 'amāre');
      final result = diagnose(item, 'praesens_second_person_singular', 'ames');
      expect(
        result,
        isA<EndingOfOtherType>().having(
          (d) => d.types,
          'types',
          orderedEquals(['E-Konjugation']),
        ),
      );
    });
  });
}

/// Type → the type it inherits from, for the types of one YAML file.
Future<Map<String, String>> _parentTypes(String asset) async {
  final yaml = loadYaml(await rootBundle.loadString(asset)) as YamlMap;
  return {
    for (final entry in (yaml['type_patterns'] as YamlMap).entries)
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
