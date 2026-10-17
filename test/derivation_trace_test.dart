import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/asset_text.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart';

const _assets = ['lib/data/latin_nouns.yaml', 'lib/data/latin_verbs.yaml'];

/// The sandhi library of each data file, by data file id. The engine keeps
/// its rules to itself, so the recompute reads them from a second parse.
Future<Map<String, GrammarFile>> _grammarFiles() async => {
  for (final file in parseGrammarFiles({
    for (final asset in _assets) asset: await loadAssetText(asset),
  }))
    file.dataFileId: file,
};

List<SandhiRuleSpec> _rulesOf(GrammarFile file, String typeName) => [
  for (final id in file.type(typeName).sandhi) file.sandhi[id]!,
];

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
    int generatedSeamCount = 0;
    int composedCount = 0;
    int regularCount = 0;
    int regularPlainCount = 0;
    int regularSeamCount = 0;
    int regularComposedCount = 0;
    final files = await _grammarFiles();

    for (final asset in _assets) {
      final items = await loadPracticeItems(asset);

      for (int n = 0; n < items.length; n++) {
        final item = items[n];
        final rules = _rulesOf(files[item.dataFileId]!, item.type);

        /// Rebuilds [form] from what it records and compares; a seam form goes
        /// through the same S16 function the engine used.
        void recompute(FormDerivation form, String where) {
          switch (form) {
            case GeneratedForm(:final stemName, :final ending):
              final stem = item.derivation.stems[stemName]!.stem;
              final left = form.sandhiRule == null
                  ? stem
                  : sandhiSeam(
                      rules,
                      stem,
                      ending,
                      wordFinal: true,
                      lemma: item.lemma,
                    ).first.text;
              expect(norm(left + ending), norm(form.result), reason: where);
            case ComposedForm(:final parts, :final join):
              expect(
                norm([for (final part in parts) part.text].join(join)),
                norm(form.result),
                reason: where,
              );
            default:
              fail('$where: $form is not rebuildable');
          }
        }

        for (int i = 0; i < item.formOrder.length; i++) {
          final key = item.formOrder[i];
          final form = item.derivation.forms[key]!;
          final where = '${item.translation} $key';

          // Exhaustive over the sealed FormDerivation vocabulary, so a new
          // kind breaks the build here instead of passing unchecked.
          switch (form) {
            case GeneratedForm():
              generatedCount++;
              if (form.sandhiRule != null) generatedSeamCount++;
              recompute(form, where);
            case ComposedForm():
              composedCount++;
              recompute(form, where);
            case GivenForm():
              break;
            case IrregularForm(:final regular?):
              regularCount++;
              expect(regular.result, item.inferredForms[i], reason: where);
              switch (regular) {
                case GeneratedForm(sandhiRule: null):
                  regularPlainCount++;
                case GeneratedForm():
                  regularSeamCount++;
                case ComposedForm():
                  regularComposedCount++;
                default:
                  fail('$where: the rule form is $regular');
              }
              // The Derivation assert covers the practised forms only, so the
              // rule form behind an override is recomputed here.
              recompute(regular, where);
            case IrregularForm():
              break;
          }
        }
      }
    }

    // Pinned, so that a derivation change that drops a case from one of the
    // arms above fails here instead of thinning the check.
    expect(
      [generatedCount, generatedSeamCount, composedCount, regularCount],
      [74480, 3867, 6715, 87],
    );
    expect(
      [regularPlainCount, regularSeamCount, regularComposedCount],
      [81, 1, 5],
    );
    expect(
      regularPlainCount + regularSeamCount + regularComposedCount,
      regularCount,
    );
  });

  group('T-trace-4 a shown type rule agrees with the type', () {
    const byRuleCounts = {
      'lib/data/latin_nouns.yaml': 157,
      'lib/data/latin_verbs.yaml': 250,
    };
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
        expect(byRule, byRuleCounts[asset]);
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
