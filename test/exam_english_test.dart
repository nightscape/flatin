import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/languages/language.dart';
import 'package:latin_practice/main.dart' show noRetry;
import 'package:latin_practice/models/course.dart';
import 'package:latin_practice/providers/course_provider.dart';
import 'package:latin_practice/providers/exam_provider.dart';
import 'package:latin_practice/widgets/exam/gap_check.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

import 'support/gen_exam.dart';

final _en = Language.parse(
  File('lib/data/languages/en.yaml').readAsStringSync(),
);

const _packs = 200;

/// A drawn pack: every kind of task is in each pack that [seed] rotates
/// through, so that every break applies somewhere.
Map<String, Object> _pack(int seed) => EnglishExamGen(Random(seed)).exam(
  include: {
    for (final (i, k) in EnglishExamGen.kinds.indexed)
      if ((seed >> i).isOdd || seed % 5 == 0) k,
  },
);

Map<String, dynamic> _copy(Map<String, Object> pack) =>
    jsonDecode(jsonEncode(pack)) as Map<String, dynamic>;

List<String> _errors(Map<String, dynamic> pack) {
  try {
    parseExam(jsonEncode(pack), _en);
    return [];
  } on ExamRejected catch (e) {
    return [for (final x in e.errors) '${x.rule.id} ${x.path}'];
  }
}

Set<String> _keyPaths(Object? node, [String prefix = '']) => switch (node) {
  Map() => {
    for (final MapEntry(:key, :value) in node.entries) ...{
      '$prefix.$key',
      ..._keyPaths(value, '$prefix.$key'),
    },
  },
  List() => {for (final x in node) ..._keyPaths(x, '$prefix[]')},
  _ => {},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a drawn schema 2 English pack reads and writes without a change '
      'and the generator reaches every feature', () {
    // Generators: EnglishExamGen over seeds 0..199, tasks of every kind.
    final reach = <String, int>{};
    for (var seed = 0; seed < _packs; seed++) {
      final gen = EnglishExamGen(Random(seed));
      final pack = gen.exam(
        include: {
          for (final (i, k) in EnglishExamGen.kinds.indexed)
            if ((seed >> i).isOdd || seed % 5 == 0) k,
        },
      );
      gen.reach.forEach((k, v) => reach[k] = (reach[k] ?? 0) + v);
      final exam = parseExam(jsonEncode(pack), _en);
      final written = jsonDecode(serializeExam(exam));
      expect(written, equals(_copy(pack)), reason: 'seed $seed');
      expect(
        jsonDecode(serializeExam(parseExam(serializeExam(exam), _en))),
        equals(written),
        reason: 'seed $seed again',
      );
    }
    expect([
      for (final k in EnglishExamGen.reachKeys)
        if (!reach.containsKey(k)) k,
    ], isEmpty);
  });

  test('the English fixture reads and writes without a change and has '
      'every key that the generator draws', () {
    // Generators: the fixture is one fixed file; the keys are those of
    // EnglishExamGen over seeds 0..199.
    const path = 'test/fixtures/exam/synthetic_en.exam';
    final source = File(path).readAsStringSync();
    final written = jsonDecode(serializeExam(parseExam(source, _en)));
    expect(written, equals(jsonDecode(jsonEncode(loadYaml(source)))));
    final drawn = {
      for (var seed = 0; seed < _packs; seed++) ..._keyPaths(_pack(seed)),
    };
    expect(drawn.difference(_keyPaths(written)), isEmpty);
  });

  test('a broken English pack is refused with its rule id and path, once', () {
    // Generators: EnglishExamGen over seeds 0..199, one EnglishBreak each.
    final reached = <EnglishBreak>{};
    for (final how in EnglishBreak.values) {
      for (var seed = 0; seed < _packs; seed++) {
        final broken = _copy(_pack(seed));
        final hit = breakEnglish(how, broken, Random(seed));
        if (hit == null) continue;
        reached.add(how);
        final (rule, path) = hit;
        expect(_errors(broken), [
          '${rule.id} $path',
        ], reason: '$how seed $seed');
      }
    }
    expect(EnglishBreak.values.toSet().difference(reached), isEmpty);
    expect(
      {for (final b in EnglishBreak.values) b.name}.length,
      EnglishBreak.values.length,
    );
  });

  test('the answer of a gap is right with the spacing, the first-letter case '
      'and the apostrophe that en.yaml allows, and wrong with any other '
      'change', () {
    // Generators: EnglishExamGen.answer (the readings come from its own
    // construction, not from expand) over seeds 0..299.
    for (var seed = 0; seed < 300; seed++) {
      final r = Random(seed);
      final gen = EnglishExamGen(r);
      final (variant, readings) = gen.answer();
      final item = LueckeItem([variant], null, 1, null);
      for (final reading in readings) {
        String space(String s) => s.split(' ').join(' ' * (1 + r.nextInt(3)));
        final first = reading[0];
        final flipped = first == first.toLowerCase()
            ? first.toUpperCase()
            : first.toLowerCase();
        for (final (how, input) in [
          ('same', reading),
          ('spaces', ' ${space(reading)}\t'),
          ('first letter', '$flipped${reading.substring(1)}'),
          ('apostrophe', reading.replaceAll("'", '’')),
        ]) {
          expect(
            gapAccepts(_en, item, input),
            isTrue,
            reason: '$how "$input" of $variant',
          );
        }
        final last = reading.length - 1;
        for (final (how, input) in [
          ('more', '${reading}x'),
          ('fewer', reading.substring(0, last)),
          (
            'last letter case',
            '${reading.substring(0, last)}${reading[last].toUpperCase()}',
          ),
        ]) {
          if (readings.any((x) => x.toLowerCase() == input.toLowerCase())) {
            continue;
          }
          expect(
            gapAccepts(_en, item, input),
            isFalse,
            reason: '$how "$input" of $variant',
          );
        }
      }
    }
  });

  test('the importer accepts an English pack on the English course and '
      'refuses it on the Latin course at the header', () async {
    // Generators: EnglishExamGen over seeds 0..19 with the course set.
    for (var seed = 0; seed < 20; seed++) {
      final pack = _copy(_pack(seed))..['course'] = 'englisch';
      final source = jsonEncode(pack);
      Future<ProviderContainer> on(String course) async {
        SharedPreferences.setMockInitialValues({activeCourseKey: course});
        final c = ProviderContainer(retry: noRetry);
        addTearDown(c.dispose);
        await c.read(courseProvider.future);
        return c;
      }

      final english = await on('englisch');
      await english.read(examPacksProvider.future);
      await english.read(examPacksProvider.notifier).import(source);
      expect(
        [for (final e in await english.read(examPacksProvider.future)) e.id],
        [pack['id']],
        reason: 'seed $seed',
      );

      final latin = await on('latein');
      await latin.read(examPacksProvider.future);
      await expectLater(
        latin.read(examPacksProvider.notifier).import(source),
        throwsA(
          isA<ExamRejected>().having(
            (e) => [for (final x in e.errors) x.path],
            'paths',
            [pack.containsKey('language') ? 'exam.language' : 'exam.course'],
          ),
        ),
        reason: 'seed $seed',
      );
      expect(await latin.read(examPacksProvider.future), isEmpty);
    }
  });
}
