import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exercise_kinds.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';

import 'support/course_providers.dart';

class _Recording implements ExerciseGenerator {
  _Recording(this.inner, this.seen);

  final ExerciseGenerator inner;
  final List<ExerciseContext> seen;

  @override
  ExerciseKind get kind => inner.kind;

  @override
  Exercise build(
    PracticeItem word,
    GrammarBundle bundle,
    ExerciseContext ctx,
    Random rng,
  ) {
    seen.add(ctx);
    return inner.build(word, bundle, ctx, rng);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a round passes the switched-off degrees into every exercise '
      'context', () async {
    final mirus = (await loadPracticeItems(
      'lib/data/latin_nouns.yaml',
    )).singleWhere((i) => i.id == 'nouns:mirus');
    final sup = mirus.formLabels.firstWhere((l) => l.features['grad'] == 'sup');
    seedSettings(
      Settings(
        courseWords: LessonRange(5, 5),
        courseGrammar: LessonRange.full,
        grammarToLinked: false,
        disabledFeatures: {
          'nouns': {
            'grad': {'komp', 'sup'},
          },
        },
      ),
    );
    final seen = <ExerciseContext>[];
    final c = ProviderContainer(
      retry: noRetry,
      overrides: [
        dataLanguageProvider.overrideWith((ref) => 'de'),
        exerciseRandomProvider.overrideWithValue(Random(17)),
        exerciseRegistryProvider.overrideWithValue([
          for (final g in exerciseGenerators) _Recording(g, seen),
        ]),
      ],
    );
    addTearDown(c.dispose);
    final topic = (await c.read(
      topicsProvider.future,
    )).firstWhere((t) => t.dataFileId == 'nouns');
    final provider = roundProvider(BlockedRound(topic.id));
    c.listen(provider, (_, _) {});
    await c.read(provider.future);
    expect(seen, isNotEmpty);
    expect(seen.map((ctx) => ctx.formPracticed(mirus, sup)).toSet(), {false});
  });
}
