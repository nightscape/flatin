import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:latin_practice/data/exam.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/exam_units.dart';
import 'package:latin_practice/models/fsrs_card.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/screens/exam_screen.dart';
import 'package:latin_practice/services/fsrs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/exercise_invariants.dart';
import 'support/gen_exam.dart';
import 'support/gen_settings.dart';
import 'support/word_classification_harness.dart';

const _packs = 12;

typedef Pack = Map<String, dynamic>;

/// The packs the seeded loops run: the synthetic pack first, as a static
/// example, then drawn packs.
Iterable<(String, Pack)> _cases() sync* {
  yield (
    'synthetic',
    jsonDecode(
          jsonEncode(
            examToYaml(
              parseExam(
                File('test/fixtures/exam/synthetic.exam').readAsStringSync(),
              ),
            ),
          ),
        )
        as Pack,
  );
  for (var seed = 1; seed <= _packs; seed++) {
    yield (
      'seed $seed',
      jsonDecode(jsonEncode(ExamGen(Random(seed)).exam())) as Pack,
    );
  }
}

List<Pack> _saetze(Pack pack) =>
    (pack['uebersetzung']['saetze'] as List).cast<Pack>();

String _first(List<dynamic> variants) => expand(variants.first as String).first;

/// The units of [einheit], written from the pack data alone: per unit the
/// token ids it shows and the model segments it shows first.
List<({List<String> tokens, List<String> models})> _expected(
  Pack pack,
  Uebersetzungseinheit einheit,
) {
  List<String> ids(Pack s) => [for (final t in s['tokens'] as List) t['id']];
  return switch (einheit) {
    Uebersetzungseinheit.teilsatz => [
      for (final s in _saetze(pack))
        for (final c in s['teilsaetze'] as List)
          (
            tokens: (c['tokens'] as List).cast<String>(),
            models: [if ((c['de'] as List).isNotEmpty) _first(c['de'])],
          ),
    ],
    Uebersetzungseinheit.satz => [
      for (final s in _saetze(pack))
        (tokens: ids(s), models: [_first(s['de'])]),
    ],
    Uebersetzungseinheit.text => [
      if (_saetze(pack).isNotEmpty)
        (
          tokens: [for (final s in _saetze(pack)) ...ids(s)],
          models: [for (final s in _saetze(pack)) _first(s['de'])],
        ),
    ],
  };
}

Future<void> _open(
  WidgetTester tester,
  Pack pack,
  Settings settings, {
  Locale locale = const Locale('de'),
  Map<String, Object> stored = const {},
  Size size = const Size(1200, 60000),
}) async {
  SharedPreferences.setMockInitialValues({
    'practice_settings': jsonEncode(settings.toJson()),
    ...stored,
  });
  // A new scope: the settings and the screen state of a case start afresh.
  await tester.pumpWidget(const SizedBox());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapInApp(
      ExamScreen(exam: parseExam(jsonEncode(pack))),
      forcedLocale: locale,
    ),
  );
  await letItLoad(tester);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump();
}

/// Reveals every model with its variants and every task solution.
Future<void> _revealAll(WidgetTester tester, Pack pack, int units) async {
  for (var i = 0; i < units; i++) {
    await _tap(tester, find.byKey(Key('exam.unit.$i.show')));
    final more = find.byKey(Key('exam.unit.$i.more'));
    if (more.evaluate().isNotEmpty) await _tap(tester, more);
  }
  for (final t in pack['aufgaben'] as List) {
    await _tap(tester, find.byKey(Key('exam.task.${t['id']}.show')));
  }
}

Iterable<String> _keys(String prefix) => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(prefix),
    )
    .evaluate()
    .map((e) => (e.widget.key! as ValueKey<String>).value);

final _segmentKey = RegExp(r'^exam\.model\.\d+\.\d+$');

/// Every text on screen.
Iterable<String> _texts() sync* {
  for (final e in find.byType(RichText).evaluate()) {
    yield (e.widget as RichText).text.toPlainText();
  }
  for (final e in find.byType(EditableText).evaluate()) {
    yield (e.widget as EditableText).controller.text;
  }
}

/// The strings of the i18n block [prefix] in [code].
Iterable<String> _strings(String code, List<String> prefix) sync* {
  Object? node = jsonDecode(
    File('assets/flutter_i18n/$code.json').readAsStringSync(),
  );
  for (final p in prefix) {
    node = (node as Map)[p];
  }
  Iterable<String> walk(Object? n) sync* {
    if (n is String) yield n;
    if (n is Map) {
      for (final v in n.values) {
        yield* walk(v);
      }
    }
  }

  yield* walk(node);
}

void main() {
  testWidgets('[E] for every unit setting the screen shows each token once, '
      'in its unit, and each model segment once', (tester) async {
    for (final (name, pack) in _cases()) {
      for (final einheit in Uebersetzungseinheit.values) {
        final why = '$name, ${einheit.name}';
        final units = _expected(pack, einheit);
        await _open(tester, pack, Settings(uebersetzungseinheit: einheit));
        await _revealAll(tester, pack, units.length);
        final allTokens = [
          for (final s in _saetze(pack))
            for (final t in s['tokens'] as List) 'exam.token.${t['id']}',
        ];
        expect(
          _keys('exam.token.').toList()..sort(),
          [...allTokens]..sort(),
          reason: '$why: each token once',
        );
        for (final (i, u) in units.indexed) {
          for (final id in u.tokens) {
            expect(
              find.descendant(
                of: find.byKey(Key('exam.unit.$i')),
                matching: find.byKey(Key('exam.token.$id')),
              ),
              findsOneWidget,
              reason: '$why: $id in unit $i',
            );
          }
          for (final (j, model) in u.models.indexed) {
            expect(
              tester.widget<Text>(find.byKey(Key('exam.model.$i.$j'))).data,
              model,
              reason: '$why: model $j of unit $i',
            );
          }
        }
        expect(
          _keys('exam.model.').where(_segmentKey.hasMatch).length,
          units.fold(0, (n, u) => n + u.models.length),
          reason: '$why: each model segment once',
        );
      }
    }
  });

  testWidgets('[E] at 360x640 the exam screen lays out every pack and unit '
      'setting without overflow, scrolled from top to end', (tester) async {
    for (final (name, pack) in _cases()) {
      for (final einheit in Uebersetzungseinheit.values) {
        await _open(
          tester,
          pack,
          Settings(uebersetzungseinheit: einheit, punkteAnzeige: true),
          size: const Size(360, 640),
        );
        for (var step = 0; step < 40; step++) {
          expect(tester.takeException(), isNull, reason: '$name, $einheit');
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pump();
        }
        expect(find.byKey(const Key('exam.finish')), findsOneWidget);
      }
    }
  });

  // Real texts: the wording rule applies to the words each language shows.
  testWidgets('[E] no text of the exam screen says an attempt failed, for '
      'any pack, settings, marks and language, with points off and on', (
    tester,
  ) async {
    for (final code in ['de', 'en']) {
      for (final s in _strings(code, ['exam'])) {
        expect(failureWord.hasMatch(s), isFalse, reason: '$code: "$s"');
      }
    }
    var seed = 0;
    for (final (name, pack) in _cases()) {
      for (final points in [false, true]) {
        final rng = Random(++seed);
        final settings = drawSettings(
          rng,
          exam: true,
        ).copyWith(punkteAnzeige: points);
        final locale = Locale(rng.nextBool() ? 'de' : 'en');
        final why = '$name, points $points, ${locale.languageCode}';
        final units = _expected(pack, settings.uebersetzungseinheit).length;
        await _open(tester, pack, settings, locale: locale);
        await _revealAll(tester, pack, units);
        final marks = [
          for (var i = 0; i < units; i++) 'exam.unit.$i',
          for (final t in pack['aufgaben'] as List) 'exam.task.${t['id']}',
        ];
        for (final m in marks) {
          await _tap(
            tester,
            find.byKey(Key('$m.${rng.nextBool() ? 'habIch' : 'anders'}')),
          );
        }
        expect(
          find.byKey(const Key('exam.points')),
          points ? findsOneWidget : findsNothing,
          reason: why,
        );
        for (final text in _texts()) {
          expect(failureWord.hasMatch(text), isFalse, reason: '$why: "$text"');
        }
        final words = _keys('exam.token.').where((k) {
          final id = k.substring('exam.token.'.length);
          return _saetze(pack).any(
            (s) => (s['tokens'] as List).any(
              (t) => t['id'] == id && t.containsKey('lemma'),
            ),
          );
        }).toList();
        if (words.isEmpty) continue;
        await _tap(tester, find.byKey(Key(words[rng.nextInt(words.length)])));
        await letItLoad(tester);
        expect(find.byKey(const Key('exam.sheet')), findsOneWidget);
        for (final text in _texts()) {
          expect(failureWord.hasMatch(text), isFalse, reason: '$why: "$text"');
        }
      }
    }
  });

  testWidgets('[E] at the end the helped words, and only they, are queued as '
      'normal word cards', (tester) async {
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
    final words = [
      for (final s in _saetze(pack))
        for (final t in s['tokens'] as List)
          if (t.containsKey('lemma')) t as Pack,
    ];
    for (var seed = 0; seed < 6; seed++) {
      final rng = Random(seed);
      final einheit = Uebersetzungseinheit.values[seed % 3];
      final units = _expected(pack, einheit);
      await _open(
        tester,
        pack,
        Settings(uebersetzungseinheit: einheit),
        stored: {'fsrs_cards': stored},
      );
      final helped = <String>{};
      for (final t in words) {
        if (!rng.nextBool()) continue;
        helped.add(t['lemma']);
        await _tap(tester, find.byKey(Key('exam.token.${t['id']}')));
        await tester.tapAt(const Offset(5, 5));
        await letItLoad(tester);
      }
      for (final (i, u) in units.indexed) {
        await _tap(tester, find.byKey(Key('exam.unit.$i.show')));
        final anders = seed == 0 || rng.nextBool();
        await _tap(
          tester,
          find.byKey(Key('exam.unit.$i.${anders ? 'anders' : 'habIch'}')),
        );
        if (!anders) continue;
        for (final t in words) {
          if (u.tokens.contains(t['id'])) helped.add(t['lemma']);
        }
      }
      await _tap(tester, find.byKey(const Key('exam.finish')));
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
      await letItLoad(tester);
      expect(find.byKey(const Key('exam.finished')), findsOneWidget);
      final cards = (await tester.runAsync(FsrsStorage.loadCards))!;
      final queuedIds = {
        for (final item in items)
          if (helped.contains(item.lemma)) item.id,
      };
      expect(queuedIds, isNotEmpty, reason: 'seed $seed');
      for (final item in items) {
        final due = cards[item.id]!.due;
        if (queuedIds.contains(item.id)) {
          expect(due.isBefore(later), isTrue, reason: '${item.id} queued');
          expect(
            due.difference(DateTime.now().toUtc()).inHours,
            lessThanOrEqualTo(24),
            reason: '${item.id} comes back tomorrow',
          );
        } else {
          expect(due, later, reason: '${item.id} untouched');
        }
      }
      for (final card in cards.values) {
        expect(
          card.lastReview,
          isNull,
          reason: '${card.itemId}: no card is reviewed',
        );
      }
    }
  });
}
