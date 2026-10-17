import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/derivation.dart';

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

      for (int n = 0; n < items.length; n++) {
        final item = items[n];
        for (int i = 0; i < item.formOrder.length; i++) {
          final key = item.formOrder[i];
          final form = item.derivation.forms[key]!;
          final where = '${item.translation} $key';

          if (form is GeneratedForm) {
            generatedCount++;
            final stem = item.derivation.stems[form.stemName]!.stem;
            if (form.sandhiRule == null) {
              expect(norm(stem + form.ending), norm(form.result), reason: where);
            }
          }

          if (form is IrregularForm && form.regular != null) {
            regularCount++;
            expect(form.regular!.result, item.inferredForms[i], reason: where);
            expect(form.regular!.result, isNot(item.forms[i]), reason: where);
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
        for (final item in items) {
          final stem = item.derivation.stems.values.singleOrNull;
          if (stem is! StemFromPart) continue;
          final where =
              '${item.translation}: ${stem.sourceWord} / ${stem.removedSuffix}';
          expect(
            stem.sourceWord.endsWith(stem.removedSuffix),
            isTrue,
            reason: where,
          );
          expect(
            norm(
              stem.sourceWord.substring(
                0,
                stem.sourceWord.length - stem.removedSuffix.length,
              ),
            ),
            norm(stem.stem),
            reason: where,
          );
        }
      });
    }
  });
}
