import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/form_label.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/test_axes.dart';

const _yamlFiles = ['lib/data/latin_nouns.yaml', 'lib/data/latin_verbs.yaml'];

Set<String> _leafKeys(Map<String, dynamic> json, [String prefix = '']) {
  final keys = <String>{};
  json.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      keys.addAll(_leafKeys(value, path));
    } else {
      keys.add(path);
    }
  });
  return keys;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Derivation contract', () {
    for (final assetPath in _yamlFiles) {
      test(
        '$assetPath: forms cover formOrder with the item\'s own values',
        () async {
          final items = await loadPracticeItems(assetPath);
          expect(items, isNotEmpty);

          for (final item in items) {
            final label = item.lemma;

            expect(
              item.derivation.forms.keys.toList(),
              item.formOrder,
              reason: '$label: derivation keys must equal formOrder',
            );
            expect(item.derivation.type, item.type, reason: label);

            for (int i = 0; i < item.formOrder.length; i++) {
              final key = item.formOrder[i];
              final form = item.derivation.forms[key]!;
              expect(
                form.result,
                item.forms[i],
                reason: '$label / $key: trace must match the answer',
              );
              expect(
                form.variants.first,
                form.result,
                reason: '$label / $key: the first variant is the shown one',
              );
              expect(
                item.acceptedForms[i],
                form.variants,
                reason: '$label / $key: the item accepts what the trace gives',
              );
            }
          }
        },
      );

      test(
        '$assetPath: filterForms returns the keys of the kept rows',
        () async {
          final items = await loadPracticeItems(assetPath);

          for (final item in items) {
            final label = item.lemma;

            expect(
              item.filterForms(item.formOrder.toSet()).keys,
              item.formOrder,
              reason: '$label: all forms enabled',
            );

            final someKeys = item.formOrder.take(2).toSet();
            final filtered = item.filterForms(someKeys);
            expect(filtered.keys, someKeys.toList(), reason: label);
            expect(filtered.forms.length, filtered.keys.length, reason: label);
            expect(filtered.labels.length, filtered.keys.length, reason: label);
          }
        },
      );
    }
  });

  group('describeLabels', () {
    test('merges labels that differ only in the merge axis', () {
      expect(
        describeLabels([nounLabel('dat', 'pl'), nounLabel('abl', 'pl')]),
        'Dativ/Ablativ Plural',
      );
    });

    test('keeps tenses apart', () {
      expect(
        describeLabels([
          verbLabel('praes', '3', 'sg'),
          verbLabel('perf', '3', 'sg'),
        ]),
        'Präsens: 3. Person Singular, Perfekt: 3. Person Singular',
      );
    });

    test('a single label reads like its displayName', () {
      final label = nounLabel('gen', 'pl');
      expect(describeLabels([label]), label.displayName);
    });
  });

  // The L6 engine must be able to state these three cases; the loader of this
  // lane produces none of them yet.
  group('the derivation types carry the cases the engine must express', () {
    final praesensStem = StemFromPart(
      name: 'praesens',
      display: 'Präsensstamm',
      variants: ['amā'],
      part: 'Infinitiv',
      sourceWord: 'amāre',
      removedSuffix: 're',
    );

    Derivation derivationOf(Map<FormKey, FormDerivation> forms) => Derivation(
      type: 'A-Konjugation',
      recognition: const TypeDeclared(),
      stems: {praesensStem.name: praesensStem},
      forms: forms,
      grammar: const Grammar({}, {}, {}, 'de'),
    );

    test('an ending may be empty', () {
      final form = GeneratedForm(
        formKey: 'imp.2.sg',
        variants: ['amā'],
        stemName: 'praesens',
        ending: '',
        endingType: 'A-Konjugation',
      );
      expect(derivationOf({'imp.2.sg': form}).forms['imp.2.sg'], same(form));
    });

    test('a sandhi rule carries a seam the spelling does not show', () {
      // amā + ō = amō, so only the rule makes stem and ending agree with the
      // result; without it the I2 assertion would fire.
      final form = GeneratedForm(
        formKey: 'praes.1.sg',
        variants: ['amō'],
        stemName: 'praesens',
        ending: 'ō',
        endingType: 'A-Konjugation',
        sandhiRule: const SandhiRule(
          id: 'a_ausfall',
          explain: 'ā fällt vor Vokal aus',
        ),
      );
      expect(
        derivationOf({'praes.1.sg': form}).forms['praes.1.sg']!.result,
        'amō',
      );
    });

    test('an irregular form may hold a composed regular form', () {
      final composed = ComposedForm(
        formKey: 'perf.1.sg',
        variants: ['amātus sum'],
        parts: [
          AffixPart(stemName: 'ppp', text: 'amātus'),
          LexemeFormPart(
            lexemeId: 'verbs:esse',
            key: 'praes.1.sg',
            derivation: GivenForm(formKey: 'praes.1.sg', variants: ['sum']),
          ),
        ],
        join: ' ',
      );
      final irregular = IrregularForm(
        formKey: 'perf.1.sg',
        variants: ['amāvī'],
        regular: composed,
      );

      expect(
        derivationOf({'perf.1.sg': irregular}).forms['perf.1.sg'],
        same(irregular),
      );
      expect(
        composed.parts.map((p) => p.text).join(composed.join),
        composed.result,
      );
    });
  });

  test('de.json and en.json have the same keys', () {
    Set<String> keysOf(String path) => _leafKeys(
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
    );

    final de = keysOf('assets/flutter_i18n/de.json');
    final en = keysOf('assets/flutter_i18n/en.json');

    expect(de.difference(en), isEmpty, reason: 'keys missing in en.json');
    expect(en.difference(de), isEmpty, reason: 'keys missing in de.json');
    expect(de, contains('explain.diag.noMatch'));
  });
}
