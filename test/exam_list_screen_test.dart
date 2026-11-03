import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/screens/exam_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_exam.dart';
import 'support/word_classification_harness.dart';

const _cases = 15;

/// A pick of the learner: a pack text, valid or with one broken rule, or
/// bytes that are not UTF-8 text.
typedef Pick = ({Uint8List bytes, ImportRefusal? refused});

Pick _valid(String source) => (bytes: utf8.encode(source), refused: null);

const _latin1Letters = [0xE4, 0xF6, 0xFC, 0xDF];

/// [source] with one Latin-1 letter between two of its characters.
Pick _latin1(String source, int at, int letter) => (
  bytes: Uint8List.fromList([
    ...utf8.encode(source.substring(0, at)),
    letter,
    ...utf8.encode(source.substring(at)),
  ]),
  refused: NotUtf8Text(),
);

/// Random bytes with a 0xFF, which never occurs in UTF-8.
Pick _binary(Random rng) {
  final bytes = [for (var i = 0; i < rng.nextInt(64); i++) rng.nextInt(256)];
  bytes.insert(rng.nextInt(bytes.length + 1), 0xFF);
  return (bytes: Uint8List.fromList(bytes), refused: NotUtf8Text());
}

Pick _notText(Random rng) {
  if (rng.nextBool()) return _binary(rng);
  final source = jsonEncode(ExamGen(rng).exam());
  return _latin1(
    source,
    rng.nextInt(source.length + 1),
    _latin1Letters[rng.nextInt(_latin1Letters.length)],
  );
}

Pick _broken(Map<String, Object> pack, Random rng) {
  final rules = [...ExamRule.values]..shuffle(rng);
  for (final rule in rules) {
    final copy = jsonDecode(jsonEncode(pack)) as Map<String, dynamic>;
    final String source;
    if (rule == ExamRule.yaml) {
      source = breakYaml(blockYaml(pack), rng).$1;
    } else if (breakRule(rule, copy, rng) != null) {
      source = jsonEncode(copy);
    } else {
      continue;
    }
    try {
      parseExam(source);
    } on ExamRejected catch (e) {
      return (
        bytes: utf8.encode(source),
        refused: PackRejected(e.errors.first),
      );
    }
  }
  throw StateError('no rule breaks the pack');
}

Future<Map<String, String>> _stored() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('exam_packs');
  return stored == null
      ? {}
      : (jsonDecode(stored) as Map<String, dynamic>).cast<String, String>();
}

void main() {
  testWidgets('[E] a valid pack is stored and listed; a broken pack shows its '
      'first error with the path and stores nothing; delete removes a pack', (
    tester,
  ) async {
    final synthetic = File(
      'test/fixtures/exam/synthetic.exam',
    ).readAsStringSync();
    // Real German text: this test also checks the refusal of a broken pack,
    // which interpolates path and rule, so one app shows real texts for both
    // refusals.
    final notText =
        ((jsonDecode(File('assets/flutter_i18n/de.json').readAsStringSync())
                    as Map<String, dynamic>)['exam']
                as Map<String, dynamic>)['list']['not_text']
            as String;
    for (var seed = 0; seed <= _cases; seed++) {
      final rng = Random(seed);
      final picks = <Pick>[
        if (seed == 0) ...[
          _valid(synthetic),
          _latin1(synthetic, synthetic.length, 0xFC),
          (
            bytes: Uint8List.fromList([
              ...'%PDF'.codeUnits,
              0xFF,
              0xFE,
              0,
              0xC3,
            ]),
            refused: NotUtf8Text(),
          ),
        ],
        for (var i = 0; i < 1 + rng.nextInt(4); i++)
          switch (rng.nextInt(3)) {
            0 => _valid(jsonEncode(ExamGen(rng).exam())),
            1 => _broken(ExamGen(rng).exam(), rng),
            _ => _notText(rng),
          },
      ];
      SharedPreferences.setMockInitialValues({
        'practice_settings': jsonEncode(Settings().toJson()),
      });
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      var next = 0;
      await tester.pumpWidget(
        wrapInApp(
          ExamListScreen(pickBytes: () async => picks[next++].bytes),
          forcedLocale: const Locale('de'),
        ),
      );
      await letItLoad(tester);
      final want = <String, String>{};
      for (final pick in picks) {
        await tester.tap(find.byKey(const Key('exam.import')));
        await letItLoad(tester);
        final refused = find.byKey(const Key('exam.import.refused'));
        switch (pick.refused) {
          case PackRejected(:final error):
            final text = tester.widget<Text>(refused).data!;
            expect(text, contains(error.path), reason: 'seed $seed');
            expect(text, contains(error.rule.id), reason: 'seed $seed');
          case NotUtf8Text():
            expect(
              tester.widget<Text>(refused).data,
              notText,
              reason: 'seed $seed',
            );
          case null:
            expect(refused, findsNothing, reason: 'seed $seed');
            final source = utf8.decode(pick.bytes);
            final exam = parseExam(source);
            want
              ..remove(exam.id)
              ..[exam.id] = source;
        }
        expect(
          await tester.runAsync(_stored),
          want,
          reason: 'seed $seed: only the valid packs are stored',
        );
        for (final id in want.keys) {
          expect(find.byKey(Key('exam.list.$id')), findsOneWidget);
        }
      }
      if (want.isEmpty) {
        expect(find.byKey(const Key('exam.list.empty')), findsOneWidget);
        continue;
      }
      final gone = want.keys.elementAt(rng.nextInt(want.length));
      await tester.tap(find.byKey(Key('exam.delete.$gone')));
      await letItLoad(tester);
      want.remove(gone);
      expect(await tester.runAsync(_stored), want, reason: 'seed $seed');
      expect(find.byKey(Key('exam.list.$gone')), findsNothing);
    }
  });
  testWidgets('[E] a picked file that is not UTF-8 text shows a refusal and '
      'stores nothing', (tester) async {
    // The synthetic pack with a comment line in Latin-1, read as pickExamFile
    // reads a picked file.
    final bytes = Uint8List.fromList([
      ...utf8.encode(
        File('test/fixtures/exam/synthetic.exam').readAsStringSync(),
      ),
      ...'# Pr'.codeUnits,
      0xFC,
      ...'fung\n'.codeUnits,
    ]);
    SharedPreferences.setMockInitialValues({
      'practice_settings': jsonEncode(Settings().toJson()),
    });
    await tester.pumpWidget(
      wrapInApp(
        ExamListScreen(pickBytes: () async => bytes),
        forcedLocale: const Locale('de'),
      ),
    );
    await letItLoad(tester);
    await tester.tap(find.byKey(const Key('exam.import')));
    await letItLoad(tester);
    expect(find.byKey(const Key('exam.import.refused')), findsOneWidget);
    expect(await tester.runAsync(_stored), isEmpty);
  });
}
