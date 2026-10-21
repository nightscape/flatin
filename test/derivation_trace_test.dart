import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/asset_text.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/grammar/engine.dart';
import 'package:latin_practice/grammar/schema.dart';
import 'package:latin_practice/models/derivation.dart';
import 'package:latin_practice/models/practice_item.dart';

import 'support/german_particle_verb.dart';

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

/// Type name → the file that declares it; a type may be used across files.
Map<String, GrammarFile> _typeOwners(Iterable<GrammarFile> files) => {
  for (final file in files)
    for (final name in file.declaredTypes.keys) name: file,
};

/// S6 restated: the first type of [typeName]'s chain that declares [key].
String _declaringType(
  Map<String, GrammarFile> owners,
  String typeName,
  FormKey key,
) {
  var name = typeName;
  while (true) {
    final declared = owners[name]!.declaredTypes[name]!;
    if (declared.forms.containsKey(key)) return name;
    name = declared.inheritsFrom!;
  }
}

/// Every (declaring type, shown ending) that the item's own type or one of
/// its delegates could have written for [key]; a deponent key is also looked
/// up under the passive key it was moved from (S10).
Set<(String, String)> _endingSources(
  Map<String, GrammarFile> owners,
  GrammarFile file,
  PracticeItem item,
  FormKey key,
) {
  final axes = file.axes;
  final wanted = {
    key,
    if (item.derivation.deponentKeys.contains(key))
      axes.formatKey({...axes.parseKey(key), 'genus_verbi': 'pass'}),
  };
  final type = file.type(item.type);
  final sources = <(String, String)>{};
  for (final own in wanted) {
    final templates = type.forms[own];
    if (templates != null) {
      sources.add((
        _declaringType(owners, item.type, own),
        templates.first.ending,
      ));
    }
  }
  for (final delegate in type.delegates) {
    final target = owners[delegate.type]!;
    for (final entry in target.type(delegate.type).forms.entries) {
      final moved = axes.formatKey({
        ...target.axes.parseKey(entry.key),
        ...delegate.set,
      });
      if (!wanted.contains(moved)) continue;
      sources.add((
        _declaringType(owners, delegate.type, entry.key),
        entry.value.first.ending,
      ));
    }
  }
  return sources;
}

/// The spelling a part reads before its own seam fires: the shown stem for an
/// affix, the shown form for a lexeme part.
String _beforeSeam(Derivation item, FormPart part) => switch (part) {
  AffixPart(:final stemName) => item.stems[stemName]!.stem,
  LexemeFormPart(:final derivation) => derivation.result,
};

/// The affix at [p] of [parts] goes through the same S16 function the engine
/// used, unless its seam takes no sandhi (S18).
void _expectAffixSeam(
  Derivation derivation,
  String lemma,
  List<SandhiRuleSpec> rules,
  List<FormPart> parts,
  int p,
  String at,
) {
  final part = parts[p] as AffixPart;
  final stem = derivation.stems[part.stemName];
  expect(stem, isNotNull, reason: '$at: no stem ${part.stemName}');
  if (!part.sandhi) {
    expect(norm(part.text), norm(stem!.stem), reason: at);
    expect(part.sandhiRule, isNull, reason: at);
    return;
  }
  final last = p == parts.length - 1;
  final seam = sandhiSeam(
    rules,
    stem!.stem,
    last ? '' : _beforeSeam(derivation, parts[p + 1]),
    wordFinal: last,
    lemma: lemma,
  ).first;
  expect(norm(part.text), norm(seam.text), reason: at);
  expect(part.sandhiRule?.id, seam.rule?.id, reason: at);
}

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
    int affixPartCount = 0;
    int lexemePartCount = 0;
    final files = await _grammarFiles();
    final owners = _typeOwners(files.values);

    for (final asset in _assets) {
      final items = await loadPracticeItems(asset);

      for (int n = 0; n < items.length; n++) {
        final item = items[n];
        final file = files[item.dataFileId]!;
        final rules = _rulesOf(file, item.type);

        /// Rebuilds [form] from what it records and compares; a seam form goes
        /// through the same S16 function the engine used.
        void recompute(FormDerivation form, String where) {
          switch (form) {
            case GeneratedForm(:final stemName, :final ending):
              final stem = item.derivation.stems[stemName]!.stem;
              final Seam seam = form.sandhiRule == null
                  ? (text: stem, right: ending, rule: null)
                  : sandhiSeam(
                      rules,
                      stem,
                      ending,
                      wordFinal: true,
                      lemma: item.lemma,
                    ).first;
              expect(
                norm(seam.text + seam.right),
                norm(form.result),
                reason: where,
              );
              expect(
                _endingSources(owners, file, item, form.formKey),
                contains((form.endingType, ending)),
                reason: where,
              );
            case ComposedForm(:final parts):
              expect(norm(form.joinedText), norm(form.result), reason: where);
              for (int p = 0; p < parts.length; p++) {
                final part = parts[p];
                final at = '$where part $p';
                switch (part) {
                  case AffixPart():
                    affixPartCount++;
                    _expectAffixSeam(
                      item.derivation,
                      item.lemma,
                      rules,
                      parts,
                      p,
                      at,
                    );
                  case LexemeFormPart(:final key, :final derivation):
                    lexemePartCount++;
                    expect(derivation.formKey, key, reason: at);
                }
              }
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
    // arms above fails here instead of thinning the check. The esse compounds
    // add 216 generated participle forms: 144 future (four compounds) and 72
    // present (absēns, praesēns).
    expect(
      [generatedCount, generatedSeamCount, composedCount, regularCount],
      [74988, 3583, 7030, 90],
    );
    expect(
      [regularPlainCount, regularSeamCount, regularComposedCount],
      [84, 1, 5],
    );
    expect(
      regularPlainCount + regularSeamCount + regularComposedCount,
      regularCount,
    );
    expect([affixPartCount, lexemePartCount], [172, 13898]);
  });

  test('T-trace-6 an affix whose seam takes no sandhi keeps its spelling', () {
    final files = mitteilenFiles();
    final file = files.single;
    final derivation = GrammarEngine(files).of('german_verbs', 'mitteilen');
    final rules = _rulesOf(file, 'schwach');
    var withoutSandhi = 0;
    for (final form in derivation.forms.values.whereType<ComposedForm>()) {
      for (var p = 0; p < form.parts.length; p++) {
        final part = form.parts[p];
        if (part is! AffixPart) continue;
        if (!part.sandhi) withoutSandhi++;
        _expectAffixSeam(
          derivation,
          file.item('mitteilen').lemma,
          rules,
          form.parts,
          p,
          '${form.formKey} part $p',
        );
      }
    }
    expect(withoutSandhi, 6);
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
