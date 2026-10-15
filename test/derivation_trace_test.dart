import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:yaml/yaml.dart';

const _assets = ['lib/data/latin_nouns.yaml', 'lib/data/latin_verbs.yaml'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('T-trace-1 the trace carries the forms that are practised', () {
    for (final asset in _assets) {
      test(asset, () async {
        final items = await loadPracticeItems(asset);
        expect(items, isNotEmpty);
        for (final item in items) {
          expect(
            item.derivation.forms.keys,
            orderedEquals(item.formOrder),
            reason: item.translation,
          );
          for (int i = 0; i < item.formOrder.length; i++) {
            expect(
              item.derivation.forms[item.formOrder[i]]!.result,
              item.forms[i],
              reason: '${item.translation} ${item.formOrder[i]}',
            );
          }
        }
      });
    }
  });

  // One test over both files: only the verbs have forms that the rule can
  // generate but the data overrides, so the regular-form count is global.
  test('T-trace-2/3 every generated and irregular form is true', () async {
    int generatedCount = 0;
    int regularCount = 0;

    for (final asset in _assets) {
      final items = await loadPracticeItems(asset);
      final raw = await _rawData(asset);

      for (int n = 0; n < items.length; n++) {
        final item = items[n];
        final inferred = inferForms(
          Map<String, dynamic>.from(raw.items[n])..['type'] = item.type,
          raw.typePatterns,
          raw.formOrder,
          raw.defaultWordForm,
        );

        for (int i = 0; i < item.formOrder.length; i++) {
          final key = item.formOrder[i];
          final form = item.derivation.forms[key]!;
          final where = '${item.translation} $key';

          if (form is GeneratedForm) {
            generatedCount++;
            final stem = item.derivation.stem!.stem;
            expect(form.ending, isNotEmpty, reason: where);
            expect(norm(stem + form.ending), norm(form.result), reason: where);
            expect(norm(form.result), norm(inferred[key]!), reason: where);
          }

          if (form is IrregularForm && form.regular != null) {
            regularCount++;
            expect(form.regular!.result, item.inferredForms[i], reason: where);
            expect(
              norm(form.regular!.result),
              isNot(norm(item.forms[i])),
              reason: where,
            );
          }
        }
      }
    }

    expect(generatedCount, greaterThan(0));
    expect(regularCount, greaterThan(0));
  });

  group('T-trace-4 a shown type rule agrees with the type', () {
    for (final asset in _assets) {
      test(asset, () async {
        final items = await loadPracticeItems(asset);
        int byRule = 0;
        for (final item in items) {
          final recognition = item.derivation.recognition;
          if (recognition is! TypeByRule) continue;
          byRule++;
          expect(
            recognition.candidateTypes,
            contains(item.type),
            reason: item.translation,
          );
          expect(
            norm(recognition.sourceWord).endsWith(norm(recognition.suffix)),
            isTrue,
            reason:
                '${item.translation}: ${recognition.sourceWord} '
                '/ ${recognition.suffix}',
          );
        }
        expect(byRule, greaterThan(0));
      });
    }
  });

  group('T-trace-5 the stem chain is true', () {
    for (final asset in _assets) {
      test(asset, () async {
        final items = await loadPracticeItems(asset);
        int reconstructed = 0;
        for (final item in items) {
          final stem = item.derivation.stem;
          if (stem == null) continue;
          expect(
            norm(stem.sourceWord).endsWith(norm(stem.removedSuffix)),
            isTrue,
            reason:
                '${item.translation}: ${stem.sourceWord} '
                '/ ${stem.removedSuffix}',
          );
          if (stem.reconstructedWord == null) continue;
          reconstructed++;
          final word = stem.reconstructedWord!;
          final suffix = stem.reconstructedSuffix!;
          expect(word.endsWith(suffix), isTrue, reason: item.translation);
          expect(
            norm(word.substring(0, word.length - suffix.length)),
            stem.stem,
            reason: item.translation,
          );
        }
        if (asset.contains('verbs')) expect(reconstructed, greaterThan(0));
      });
    }
  });
}

/// The YAML fields that [inferForms] needs, in item order.
Future<
  ({
    List<Map<String, dynamic>> items,
    Map<String, dynamic> typePatterns,
    List<String> formOrder,
    String? defaultWordForm,
  })
>
_rawData(String asset) async {
  final yaml = loadYaml(await rootBundle.loadString(asset)) as YamlMap;
  final items = (yaml['items'] as YamlList)
      .map((e) => _toMap(e as YamlMap))
      .toList();
  return (
    items: items,
    typePatterns: _toMap(yaml['type_patterns'] as YamlMap),
    formOrder: (yaml['form_order'] as YamlList)
        .map((v) => v as String)
        .toList(),
    defaultWordForm: (yaml['defaults'] as YamlMap)['word_form'] as String?,
  );
}

Map<String, dynamic> _toMap(YamlMap yaml) => Map<String, dynamic>.from(
  yaml.map(
    (key, value) => MapEntry(
      key.toString(),
      value is YamlMap
          ? _toMap(value)
          : value is YamlList
          ? value.map((e) => e is YamlMap ? _toMap(e) : e).toList()
          : value,
    ),
  ),
);
