import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/screens/exam_screen.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/gen_exam.dart';
import 'support/latin_course.dart' show latinLastLesson;
import 'support/word_classification_harness.dart';

typedef Pack = Map<String, dynamic>;

/// One `bestimmen` item of a pack with the dropdown merkmale the spec gives
/// it: the merkmale that are `form` keys of the language.
typedef Asked = ({
  String task,
  int index,
  String lemma,
  int punkte,
  List<String> sections,
  Map<String, dynamic> codes,
});

const _packs = 8;

/// The synthetic pack first, as a static example, then drawn packs that have
/// at least one dropdown item.
Iterable<(String, Pack)> _cases() sync* {
  yield (
    'synthetic',
    jsonDecode(
          jsonEncode(
            examToYaml(
              parseExam(
                File('test/fixtures/exam/synthetic.exam').readAsStringSync(),
                latinLang,
              ),
            ),
          ),
        )
        as Pack,
  );
  for (var seed = 1; seed <= _packs; seed++) {
    yield (
      'seed $seed',
      jsonDecode(jsonEncode(ExamGen(Random(seed)).examWithDropdowns())) as Pack,
    );
  }
}

/// Every `bestimmen` item of [pack], with its dropdown sections (empty for an
/// item with none).
List<Asked> _items(Pack pack) {
  final tokens = {
    for (final s in pack['uebersetzung']['saetze'] as List)
      for (final t in s['tokens'] as List) t['id'] as String: t as Pack,
  };
  return [
    for (final t in pack['aufgaben'] as List)
      if (t['art'] == 'bestimmen')
        for (final (j, i) in (t['items'] as List).indexed)
          (
            task: t['id'] as String,
            index: j,
            lemma: tokens[i['token']]!['lemma'] as String,
            punkte: i['punkte'] as int,
            sections: [
              for (final m in i['merkmale'] as List)
                if (latinLang.form.contains(m)) m as String,
            ],
            codes: tokens[i['token']]!['analyse'] as Map<String, dynamic>,
          ),
  ];
}

/// The cases with the lemma of every word token replaced by a word that no
/// data file of the app lists.
Iterable<(String, Pack)> _unknownLemmas() sync* {
  final aux = latinLang.rules.compound!.aux;
  for (final (name, pack) in _cases()) {
    final uebersetzung = pack['uebersetzung'] as Pack;
    for (final t in [
      ...uebersetzung['hilfen'] as List,
      for (final s in uebersetzung['saetze'] as List) ...s['tokens'] as List,
    ]) {
      if (t['lemma'] case final String l when l != aux) t['lemma'] = 'ignot$l';
    }
    yield ('$name, unknown lemmas', pack);
  }
}

Iterable<Asked> _asked(Pack pack) =>
    _items(pack).where((i) => i.sections.isNotEmpty);

String _prefix(Asked i) => 'exam.task.${i.task}.item.${i.index}';

Key _dropdown(Asked i, String section) => Key('${_prefix(i)}.$section');

Future<void> _open(
  WidgetTester tester,
  Pack pack, {
  Map<String, Object> stored = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'practice_settings': jsonEncode(
      Settings(lastLesson: latinLastLesson, punkteAnzeige: true).toJson(),
    ),
    ...stored,
  });
  await tester.pumpWidget(const SizedBox());
  tester.view.physicalSize = const Size(1200, 60000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapInApp(
      ExamScreen(exam: parseExam(jsonEncode(pack), latinLang)),
      forcedLocale: const Locale('de'),
    ),
  );
  await letItLoad(tester);
}

Future<void> _pick(
  WidgetTester tester,
  Asked i,
  String section,
  String code,
) async {
  await tester.tap(find.byKey(_dropdown(i, section)));
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .byWidgetPredicate(
          (w) => w is DropdownMenuItem<String> && w.value == code,
        )
        .last,
  );
  await tester.pumpAndSettle();
}

Future<void> _answer(
  WidgetTester tester,
  Asked i,
  Map<String, String> picks,
) async {
  for (final MapEntry(:key, :value) in picks.entries) {
    await _pick(tester, i, key, value);
  }
  await tester.tap(find.byKey(Key('${_prefix(i)}.check')));
  await tester.pump();
}

Map<String, String> _right(Asked i) => {
  for (final s in i.sections) s: '${i.codes[s]}',
};

bool _solved(Asked i) =>
    find.byKey(Key('${_prefix(i)}.check')).evaluate().isEmpty;

int _points(WidgetTester tester) => int.parse(
  RegExp(r'\d+').firstMatch(
    tester.widget<Text>(find.byKey(const Key('exam.points'))).data!,
  )![0]!,
);

List<DropdownMenuItem<String>> _menu(WidgetTester tester, Finder f) => tester
    .widget<DropdownButton<String>>(
      find.descendant(of: f, matching: find.byType(DropdownButton<String>)),
    )
    .items!;

/// The label and the option texts a dropdown shows.
({String label, List<String> options}) _shown(WidgetTester tester, Finder f) {
  final d = tester.widget<DropdownButtonFormField<String>>(f);
  return (
    label: d.decoration.labelText!,
    options: [
      for (final item in _menu(tester, f))
        if (item.value != null) ((item.child as Text).data!),
    ],
  );
}

void main() {
  testWidgets('a dropdown item shows exactly the dropdowns of its merkmale, '
      'worded as the practice dropdowns, and its right values pass at the '
      'first check', (tester) async {
    final axes = (await tester.runAsync(
      () => loadGrammarFile('verbs', language: 'de'),
    ))!.axes;
    final nounAxes = (await tester.runAsync(
      () => loadGrammarFile('nouns', language: 'de'),
    ))!.axes;
    final fileOf = {
      for (final p in (await tester.runAsync(loadAllPracticeItems))!)
        p.lemma: p.dataFileId,
    };
    var seen = 0;
    for (final (name, pack) in _cases()) {
      await _open(tester, pack);
      for (final i in _items(pack)) {
        final shown = {
          for (final k
              in find
                  .byWidgetPredicate(
                    (w) =>
                        w.key is ValueKey<String> &&
                        (w.key! as ValueKey<String>).value.startsWith(
                          '${_prefix(i)}.',
                        ) &&
                        w is DropdownButtonFormField<String>,
                  )
                  .evaluate())
            ((k.widget.key! as ValueKey<String>).value).substring(
              _prefix(i).length + 1,
            ),
        };
        expect(shown, i.sections.toSet(), reason: '$name ${i.task}.${i.index}');
        final classAxes =
            fileOf[i.lemma] == 'verbs' ||
                i.sections.any(
                  (m) => const [
                    'person',
                    'tempus',
                    'modus',
                    'genus_verbi',
                  ].contains(m),
                )
            ? axes
            : nounAxes;
        final onScreen = [...i.sections]
          ..sort((a, b) {
            final pa = tester.getTopLeft(find.byKey(_dropdown(i, a)));
            final pb = tester.getTopLeft(find.byKey(_dropdown(i, b)));
            return pa.dy != pb.dy
                ? pa.dy.compareTo(pb.dy)
                : pa.dx.compareTo(pb.dx);
          });
        expect(
          onScreen,
          [
            for (final a in classAxes.axes)
              if (i.sections.contains(a.id)) a.id,
          ],
          reason:
              '$name ${i.task}.${i.index}: practice order of the word class',
        );
        for (final s in i.sections) {
          final expected = Selectors.forAxes(axes, i.sections);
          final dropdown = _shown(tester, find.byKey(_dropdown(i, s)));
          expect(dropdown.label, axes.byId(s).name, reason: name);
          final analyse = [for (final c in latinLang.analyse[s]!) '$c'];
          expect(dropdown.options, [
            for (final c in expected.options[s]!)
              if (analyse.contains(c)) expected.optionText(s, c),
          ], reason: name);
        }
      }
      for (final i in _asked(pack)) {
        seen++;
        await _answer(tester, i, _right(i));
        expect(_solved(i), isTrue, reason: '$name ${i.task}.${i.index}');
      }
      expect(
        _points(tester),
        _asked(pack).fold(0, (sum, i) => sum + i.punkte),
        reason: '$name: a first-try right answer earns the item points',
      );
    }
    expect(
      seen,
      greaterThan(_packs),
      reason: 'the draw reaches dropdown items',
    );
  });

  testWidgets('points never go down over any answer sequence, and a first-try '
      'answer earns at least as much as one that needed retries', (
    tester,
  ) async {
    for (final (name, pack) in _cases()) {
      final asked = _asked(pack).toList();
      await _open(tester, pack);
      for (final i in asked) {
        await _answer(tester, i, _right(i));
      }
      final firstTry = _points(tester);

      final rng = Random(name.hashCode);
      await _open(tester, pack);
      var last = _points(tester);
      for (final i in asked) {
        for (var round = rng.nextInt(3); round >= 0 && !_solved(i); round--) {
          final section = i.sections[rng.nextInt(i.sections.length)];
          final options = _menu(tester, find.byKey(_dropdown(i, section)))
              .map((e) => e.value)
              .nonNulls
              .where((c) => c != '${i.codes[section]}')
              .toList();
          await _answer(tester, i, {
            ..._right(i),
            section: options[rng.nextInt(options.length)],
          });
          expect(_solved(i), isFalse, reason: '$name: a wrong pick is refused');
          expect(_points(tester), greaterThanOrEqualTo(last), reason: name);
          last = _points(tester);
        }
        await _answer(tester, i, _right(i));
        expect(_solved(i), isTrue, reason: name);
        expect(_points(tester), greaterThanOrEqualTo(last), reason: name);
        last = _points(tester);
      }
      expect(
        last,
        lessThanOrEqualTo(firstTry),
        reason: '$name: retries earn less',
      );
    }
  });

  testWidgets('a wrong check marks the item for the review queue, a first-try '
      'right one does not', (tester) async {
    final (_, pack) = _cases().first;
    final items = (await tester.runAsync(loadAllPracticeItems))!;
    final later = DateTime.now().toUtc().add(const Duration(days: 30));
    final stored = jsonEncode({
      'version': '2.0',
      'cards': [
        for (final item in items)
          PracticeItemCard(
            itemId: item.id,
            card: fsrs.Card(cardId: item.id.hashCode),
            due: later,
          ).toMap(),
      ],
    });
    final asked = _asked(pack).toList();
    for (var seed = 0; seed < 4; seed++) {
      final rng = Random(seed);
      await _open(tester, pack, stored: {'fsrs_cards': stored});
      final helped = <String>{};
      final revealed = <String>{};
      for (final i in asked) {
        if (revealed.contains(i.task)) {
          helped.add(i.lemma);
          continue;
        }
        if (seed == 0 || rng.nextBool()) {
          final section = i.sections.first;
          final wrong = _menu(tester, find.byKey(_dropdown(i, section)))
              .map((e) => e.value)
              .nonNulls
              .firstWhere((c) => c != '${i.codes[section]}');
          await _answer(tester, i, {..._right(i), section: wrong});
          helped.add(i.lemma);
        }
        if (seed == 1 || rng.nextInt(4) == 0) {
          await tester.tap(find.byKey(Key('exam.task.${i.task}.show')));
          await tester.pump();
          revealed.add(i.task);
          helped.add(i.lemma);
        } else {
          await _answer(tester, i, _right(i));
        }
      }
      await tester.tap(find.byKey(const Key('exam.finish')));
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await letItLoad(tester);
      final cards = (await tester.runAsync(FsrsStorage.loadCards))!;
      final queued = {
        for (final item in items)
          if (cards[item.id]!.due.isBefore(later)) item.lemma,
      };
      expect(
        queued,
        items.map((e) => e.lemma).toSet().intersection(helped),
        reason: 'seed $seed',
      );
      if (seed == 0) expect(helped, isNotEmpty);
    }
  });

  testWidgets('the practice screen words its dropdowns as the exam does', (
    tester,
  ) async {
    final axes = (await tester.runAsync(
      () => loadGrammarFile('verbs', language: 'de'),
    ))!.axes;
    final items = [
      for (final i in (await tester.runAsync(loadAllPracticeItems))!)
        if (i.dataFileId == 'verbs') i,
    ];
    final rng = Random(7);
    await seedNothingDue({});
    for (var n = 0; n < 5; n++) {
      final item = items[rng.nextInt(items.length)];
      final key = item.formOrder[rng.nextInt(item.formOrder.length)];
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapInApp(
          WordClassificationScreen(item: item, formKey: key),
          forcedLocale: const Locale('de'),
        ),
      );
      await letItLoad(tester);
      final practice = selectorsFor(item.formLabels);
      final exam = Selectors.forAxes(axes, practice.sections);
      for (final s in practice.sections) {
        final shown = _shown(tester, find.byKey(Key('classification.0.$s')));
        expect(shown.label, axes.byId(s).name);
        final texts = shown.options.where((t) => t != '—').toList();
        expect(texts, [
          for (final c in practice.options[s]!)
            if (c != absentValue) exam.optionText(s, c),
        ]);
        final offered = [
          for (final c in exam.options[s]!) exam.optionText(s, c),
        ];
        var from = 0;
        for (final t in texts) {
          final at = offered.indexOf(t, from);
          expect(at, isNonNegative, reason: '$s: "$t" in order among $offered');
          from = at + 1;
        }
      }
    }
  });

  testWidgets('every task keeps its self-mark row after the reveal, except a '
      'bestimmen task whose items all have dropdowns', (tester) async {
    for (final (name, pack) in _cases()) {
      await _open(tester, pack);
      final asked = {for (final i in _asked(pack)) '${i.task}.${i.index}'};
      for (final t in pack['aufgaben'] as List) {
        final id = t['id'] as String;
        await tester.tap(find.byKey(Key('exam.task.$id.show')));
        await tester.pump();
        final allAsked =
            t['art'] == 'bestimmen' &&
            [
              for (var j = 0; j < (t['items'] as List).length; j++) '$id.$j',
            ].every(asked.contains);
        expect(
          find.byKey(Key('exam.task.$id.habIch')),
          allAsked ? findsNothing : findsOneWidget,
          reason: '$name task $id (${t['art']})',
        );
      }
    }
  });
  testWidgets('an item whose solution is shown before it is solved earns '
      'nothing and is locked; solved items keep their points', (tester) async {
    for (final (name, pack) in _cases()) {
      final rng = Random(name.hashCode);
      await _open(tester, pack);
      var expected = 0;
      final byTask = <String, List<Asked>>{};
      for (final i in _asked(pack)) {
        byTask.putIfAbsent(i.task, () => []).add(i);
      }
      for (final MapEntry(:key, value: items) in byTask.entries) {
        final solvedFirst = List.generate(items.length, (_) => rng.nextBool());
        for (final (n, i) in items.indexed) {
          if (!solvedFirst[n]) continue;
          await _answer(tester, i, _right(i));
          expected += i.punkte;
        }
        await tester.tap(find.byKey(Key('exam.task.$key.show')));
        await tester.pump();
        for (final (n, i) in items.indexed) {
          if (solvedFirst[n]) continue;
          for (final s in i.sections) {
            expect(
              tester
                  .widget<DropdownButtonFormField<String>>(
                    find.byKey(_dropdown(i, s)),
                  )
                  .onChanged,
              isNull,
              reason: '$name ${i.task}.${i.index}: locked after the reveal',
            );
          }
          if (find.byKey(Key('${_prefix(i)}.check')).evaluate().isNotEmpty) {
            await _answer(tester, i, _right(i));
          }
        }
        expect(_points(tester), expected, reason: '$name task $key');
      }
    }
  });

  testWidgets('a task marked hab ich after its dropdown items are solved at '
      'the first check queues no lemma', (tester) async {
    final items = (await tester.runAsync(loadAllPracticeItems))!;
    final lemmas = {for (final item in items) item.lemma};
    final later = DateTime.now().toUtc().add(const Duration(days: 30));
    final stored = jsonEncode({
      'version': '2.0',
      'cards': [
        for (final item in items)
          PracticeItemCard(
            itemId: item.id,
            card: fsrs.Card(cardId: item.id.hashCode),
            due: later,
          ).toMap(),
      ],
    });
    var selfMarked = 0;
    for (final (name, pack) in _cases()) {
      await _open(tester, pack, stored: {'fsrs_cards': stored});
      for (final i in _asked(pack)) {
        await _answer(tester, i, _right(i));
      }
      final asked = {for (final i in _asked(pack)) '${i.task}.${i.index}'};
      selfMarked += _items(
        pack,
      ).where((i) => i.sections.isEmpty && lemmas.contains(i.lemma)).length;
      for (final t in pack['aufgaben'] as List) {
        final id = t['id'] as String;
        await tester.tap(find.byKey(Key('exam.task.$id.show')));
        await tester.pump();
        final allAsked =
            t['art'] == 'bestimmen' &&
            [
              for (var j = 0; j < (t['items'] as List).length; j++) '$id.$j',
            ].every(asked.contains);
        if (allAsked) continue;
        await tester.tap(find.byKey(Key('exam.task.$id.habIch')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('exam.finish')));
      await tester.pump();
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await letItLoad(tester);
      final cards = (await tester.runAsync(FsrsStorage.loadCards))!;
      expect(
        {
          for (final item in items)
            if (cards[item.id]!.due.isBefore(later)) item.lemma,
        },
        isEmpty,
        reason: name,
      );
    }
    expect(selfMarked, greaterThan(0));
  });

  testWidgets('an item whose lemma no data file lists shows a dropdown for '
      'each of its form merkmale', (tester) async {
    var seen = 0;
    for (final (name, pack) in _unknownLemmas()) {
      await _open(tester, pack);
      for (final i in _asked(pack)) {
        for (final s in i.sections) {
          seen++;
          expect(
            find.byKey(_dropdown(i, s)),
            findsOneWidget,
            reason: '$name ${i.task}.${i.index} $s',
          );
        }
      }
    }
    expect(seen, greaterThan(0));
  });

  test('every code of the language analyse that the Latin data files teach '
      'has a value in the grammar axis of that key', () async {
    final gaps = <String>[];
    for (final file in ['nouns', 'verbs']) {
      final grammar = await loadGrammarFile(file, language: 'de');
      for (final axis in grammar.axes.axes) {
        if (!latinLang.form.contains(axis.id)) continue;
        for (final code in latinLang.analyse[axis.id]!) {
          if (!axis.codes.contains('$code')) gaps.add('$file ${axis.id} $code');
        }
      }
    }
    expect(gaps, isEmpty);
  });
}
