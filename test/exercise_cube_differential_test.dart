import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_bestimmen.dart';
import 'package:latin_practice/data/exercise_build.dart';
import 'package:latin_practice/data/exercise_finderror.dart';
import 'package:latin_practice/data/exercise_match.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/exercise_spec.dart';
import 'package:latin_practice/data/exercise_oddone.dart';
import 'package:latin_practice/data/exercise_transform.dart';
import 'package:latin_practice/data/exercise_translate.dart';
import 'package:latin_practice/data/german_forms.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';

import 'support/exercise_invariants.dart';

/// Compares the spec kinds with the generators they replace, over every pair
/// in both UI languages. It takes hours in one process; run it in shards:
///   flutter test --tags differential --run-skipped \
///     --dart-define=SHARDS=8 --dart-define=SHARD=<i> \
///     test/exercise_cube_differential_test.dart
const _seeds = 20;
const _shards = int.fromEnvironment('SHARDS', defaultValue: 1);
const _shard = int.fromEnvironment('SHARD');

/// Comma-separated kind names to compare; all when empty.
const _only = String.fromEnvironment('KINDS');
const _report = 'target/differential-raw-$_shard.md';

const List<ExerciseGenerator> _old = [
  LatDeChoiceGenerator(),
  DeLatChoiceGenerator(),
  DeLatTypeGenerator(),
  BuildFormGenerator(),
  OddOneOutGenerator(),
  TransformGenerator(),
  FindErrorGenerator(),
  BestimmenGenerator(),
  MatchGenerator(),
  FormChainGenerator(),
];

/// Builds with [g] for every seed; the exercises and the distinct reasons of
/// the seeds that did not build.
(List<Exercise>, Set<String>) _buildAll(
  ExerciseGenerator g,
  PracticeItem word,
  GrammarBundle bundle,
  ExerciseContext ctx,
) {
  final built = <Exercise>[];
  final reasons = <String>{};
  for (var seed = 1; seed <= _seeds; seed++) {
    try {
      built.add(g.build(word, bundle, ctx, Random(seed)));
    } on CannotBuild catch (e) {
      reasons.add(e.reason);
    }
  }
  return (built, reasons);
}

/// The accepted answers of each typed prompt among [built].
Map<String, Set<String>> _acceptedByPrompt(List<Exercise> built) => {
  for (final e in built)
    '${e.questionParams}': (e.answer as TypedAnswer).accepted.toSet(),
};

/// The German view frames a subjunctive text, which the old matching did not.
bool _isSubjunctiveFraming(String objection) =>
    objection.contains('does not show') && objection.contains('@konj.');

/// Whether more than one form of [word] reads [start].
bool _syncreticStart(PracticeItem word, String start) =>
    word.acceptedForms.where((texts) => texts.contains(start)).length > 1;

String _show(Exercise e) => switch (e.answer) {
  ChoiceAnswer(:final options, :final right) =>
    '${e.questionParams} [${options.map((o) => o == right ? '*${o.text}' : o.text).join(' | ')}]',
  TypedAnswer(:final accepted) => '${e.questionParams} → $accepted',
  MatchingAnswer() => '${e.questionParams}',
};

void main() {
  late List<PracticeItem> items;
  late GermanForms german;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    items = await loadAllPracticeItems();
    final container = ProviderContainer(
      overrides: [dataLanguageProvider.overrideWith((ref) => 'de')],
    );
    german = await container.read(germanFormsProvider.future);
    container.dispose();
  });

  test('the spec kinds build where the old generators do, admit their '
      'exercises and build only valid ones', () {
    final pools = {
      for (final id in {for (final i in items) i.dataFileId})
        id: items.where((i) => i.dataFileId == id).toList(),
    };
    final buildability = <String>[];
    final notAdmitted = <String>[];
    final invalid = <String>[];
    final widened = <String>[];
    final unexplained = <String>[];
    var pairs = 0;
    for (final (locale, forms) in [('de', german), ('en', const NoForms())]) {
      for (final (i, word) in items.indexed) {
        if (i % _shards != _shard) continue;
        for (final bundle in {
          for (final key in word.formOrder) bundleOf(word, key),
        }) {
          pairs++;
          for (final spec in specGenerators) {
            if (_only.isNotEmpty &&
                !_only.split(',').contains(spec.kind.name)) {
              continue;
            }
            final ctx = ExerciseContext(
              unlocked: unlockedFor(spec.spec, word, bundle),
              pool: pools[word.dataFileId]!,
              german: forms,
            );
            final old = generatorFor(spec.kind, _old);
            final pair = '$locale ${spec.kind.name} ${word.id} / $bundle';
            final (oldBuilt, oldWhy) = _buildAll(old, word, bundle, ctx);
            final (newBuilt, newWhy) = _buildAll(spec, word, bundle, ctx);
            if (oldBuilt.isEmpty != newBuilt.isEmpty) {
              final uncoveredGerman =
                  oldBuilt.isEmpty &&
                  oldWhy.every((r) => r.contains('no German form'));
              if (spec.kind == ExerciseKind.formenKette ||
                  spec.kind == ExerciseKind.zuordnen && !uncoveredGerman) {
                unexplained.add('$pair: buildability differs');
              }
              buildability.add(
                '$pair: old ${oldBuilt.isEmpty ? 'never builds ($oldWhy)' : 'builds'}, '
                'new ${newBuilt.isEmpty ? 'never builds ($newWhy)' : 'builds'}',
              );
            }
            for (final e in oldBuilt) {
              final why = spec.objections(e, word, bundle, ctx);
              if (why.isNotEmpty) {
                final line = '$pair: ${_show(e)}: ${why.toSet()}';
                notAdmitted.add(line);
                if (spec.kind == ExerciseKind.zuordnen &&
                    !why.every(_isSubjunctiveFraming)) {
                  unexplained.add(line);
                }
              }
            }
            if (spec.spec.answer is Typed) {
              final ours = _acceptedByPrompt(newBuilt);
              for (final e in oldBuilt) {
                final key = '${e.questionParams}';
                final value = (e.answer as TypedAnswer).accepted.toSet();
                final new_ = ours[key];
                if (new_ != null && !setEquals(new_, value)) {
                  final line = '$pair: $key: old $value, new $new_';
                  widened.add(line);
                  if (spec.spec.select is AxisPath &&
                      !_syncreticStart(word, e.questionParams['start']!)) {
                    unexplained.add(line);
                  }
                }
              }
            }
            for (final e in newBuilt) {
              final why = violations(e, spec.spec, word, bundle, ctx);
              if (why.isNotEmpty) invalid.add('$pair: ${_show(e)}: $why');
            }
          }
        }
      }
    }
    File(_report)
      ..createSync(recursive: true)
      ..writeAsStringSync(
        [
          '# Differential old vs spec kinds ($pairs pairs, $_seeds seeds)',
          '## Buildability (${buildability.length})',
          ...buildability,
          '## Old exercises the spec does not admit (${notAdmitted.length})',
          ...notAdmitted.toSet(),
          '## Invalid spec exercises (${invalid.length})',
          ...invalid,
          '## Typed prompts with other accepted answers (${widened.toSet().length})',
          ...widened.toSet(),
          '## Unexplained (${unexplained.length})',
          ...unexplained,
        ].join('\n'),
      );
    expect(invalid, isEmpty);
    expect(unexplained, isEmpty);
  }, tags: 'differential');
}
