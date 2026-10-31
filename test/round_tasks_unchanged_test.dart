import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/exercise.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/providers/locale_provider.dart';
import 'package:latin_practice/providers/round_providers.dart';

import 'support/course_providers.dart';
import 'support/grammar_exercise_harness.dart';

const _golden = 'test/round_tasks_unchanged.golden.json';

Object _answerOf(ExerciseAnswer a) => switch (a) {
  ChoiceAnswer(:final options, :final right) => {
    'options': [for (final o in options) o.text],
    'right': right.text,
  },
  TypedAnswer(:final expected, :final accepted) => {
    'expected': '${expected.lexemeId} ${expected.formKey}',
    'accepted': accepted,
  },
  PartsAnswer(:final prompt, :final slots, :final given) => {
    'prompt': prompt.text,
    'slots': [for (final s in slots) '${s.name} ${s.answer.accepted}'],
    'given': [for (final g in given) '${g.at} ${g.name}'],
  },
  MatchingAnswer(:final pairs, :final agreements) => {
    'pairs': [for (final (l, r) in pairs) '${l.text} = ${r.text}'],
    'agreements': agreements,
  },
  SortingAnswer(:final groups, :final forms, :final tick) => {
    'groups': groups,
    'forms': [for (final (f, g) in forms) '${f.text} $g'],
    'tick': tick,
  },
};

/// Every task a mixed round shows when the learner answers its first three
/// tasks wrong, so retries are built too.
Future<List<Object>> _tasksOf(Settings settings, int seed) async {
  seedSettings(settings);
  final c = ProviderContainer(
    retry: noRetry,
    overrides: [
      dataLanguageProvider.overrideWith((ref) => 'de'),
      exerciseRandomProvider.overrideWithValue(Random(seed)),
    ],
  );
  final provider = roundProvider(const MixedRound());
  c.listen(provider, (_, _) {});
  var state = await c.read(provider.future);
  final tasks = <Object>[];
  for (var n = 0; !state.isOver; n++) {
    final task = state.queue.first;
    final e = task.exercise;
    tasks.add({
      'retry': task.isRetry,
      'word': task.word.id,
      'bundle': task.bundle,
      'kind': e.kind.name,
      'question': e.questionKey,
      'params': e.questionParams,
      'answer': _answerOf(e.answer),
    });
    final (right, wrong) = rightAndWrong(task.word, e);
    await c.read(provider.notifier).respond(n < 3 ? wrong : right);
    await c.pump();
    state = await c.read(provider.future);
  }
  c.dispose();
  return tasks;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the per-file kinds build the tasks of the golden for fixed seeds and '
    'fresh cards',
    () async {
      final settings = {
        'whole course': Settings(),
        'lesson 25': Settings(courseWords: LessonRange(1, 25)),
        'lesson 5': Settings(courseWords: LessonRange(1, 5)),
      };
      final actual = <String, Object>{
        for (final MapEntry(key: name, value: s) in settings.entries)
          for (var seed = 0; seed < 2; seed++)
            '$name, seed $seed': await _tasksOf(s, seed),
      };
      final text = const JsonEncoder.withIndent(' ').convert(actual);
      if (autoUpdateGoldenFiles) File(_golden).writeAsStringSync('$text\n');
      expect(text, File(_golden).readAsStringSync().trimRight());
    },
    timeout: const Timeout(Duration(minutes: 5)),
    tags: 'sweep',
  );
}
