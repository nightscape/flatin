import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/diagnosis.dart' show diagnose;
import 'package:latin_practice/data/esel_steps.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/providers/practice_providers.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';
import 'package:latin_practice/widgets/esel_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/esel_render.dart' show isDashed;
import 'support/trace_fixtures.dart';
import 'support/explanation_harness.dart' show pickOption;
import 'support/word_classification_harness.dart';

const _gen = 'gen.pl';

Future<PracticeItem> _item(String asset, String lemma) async =>
    (await loadPracticeItems(asset)).firstWhere((i) => i.lemma == lemma);

Future<PracticeItem> _dominus() => _item('lib/data/latin_nouns.yaml', 'dominus');

Future<PracticeItem> _amare() => _item('lib/data/latin_verbs.yaml', 'amāre');

/// Pumps the practice screen of [item] and checks [wrong] (form key to wrong
/// answer); every other field stays empty.
Future<void> _pumpChecked(
  WidgetTester tester,
  PracticeItem item,
  Map<String, String> wrong,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1200, 12000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapInApp(
    PracticeScreen(item: item),
    forcedLocale: const Locale('de'),
  ));
  await letItLoad(tester);
  for (final entry in wrong.entries) {
    await tester.enterText(
      find.byType(TextField).at(item.formOrder.indexOf(entry.key)),
      entry.value,
    );
  }
  await tester.tap(find.byKey(const Key('practice.check.button')));
  await tester.pumpAndSettle();
}

List<EselStepRow> _rows(WidgetTester tester, String scope) => tester
    .widgetList<EselStepRow>(
        find.byWidgetPredicate((w) => w is EselStepRow && w.scope == scope))
    .toList();

String _scope(String formKey) => 'esel.$formKey';

Finder _panel(String formKey) => find.byKey(Key('esel.panel.$formKey'));

List<EselStep> _contract(PracticeItem item, String formKey, String answer) =>
    eselSteps(item, formKey, diagnosis: diagnose(item, formKey, answer));

int _firstQuestion(List<EselStep> steps) =>
    steps.indexWhere((s) => s.options.isNotEmpty);

Finder _option(String formKey, EselKind kind, EselOption option) =>
    find.byKey(Key('${_scope(formKey)}.${kind.name}.option.${option.identity}'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('(a) panel under wrong forms', () {
    testWidgets('only wrong forms get one, the first is open', (tester) async {
      final item = await _dominus();
      await _pumpChecked(tester, item, {
        'gen.sg': 'domino',
        _gen: 'dominis',
        'nom.sg': 'dominus',
      });

      expect(_panel('gen.sg'), findsOneWidget);
      expect(_panel(_gen), findsOneWidget);
      expect(_panel('nom.sg'), findsNothing);
      expect(find.byType(EselPanel), findsNWidgets(2));
      expect(_rows(tester, _scope('gen.sg')), isNotEmpty);
      expect(_rows(tester, _scope(_gen)), isEmpty);

      await tester.tap(find.byKey(Key('${_scope(_gen)}.toggle')));
      await tester.pumpAndSettle();
      expect(_rows(tester, _scope(_gen)), isNotEmpty);
    });
  });

  group('(b) choosing an option', () {
    testWidgets('right opens the next step, wrong keeps it open',
        (tester) async {
      final item = await _dominus();
      await _pumpChecked(tester, item, {_gen: 'dominis'});
      final steps = _contract(item, _gen, 'dominis');
      final index = _firstQuestion(steps);
      final step = steps[index];
      final wrong = step.options.firstWhere((o) => !o.isRight);
      final right = step.options.firstWhere((o) => o.isRight);

      expect(_rows(tester, _scope(_gen))[index].status, EselStepStatus.open);

      await tester.tap(_option(_gen, step.kind, wrong));
      await tester.pumpAndSettle();
      var row = _rows(tester, _scope(_gen))[index];
      expect(row.status, EselStepStatus.open);
      expect(row.wrongPicks, {wrong.identity});
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(_option(_gen, step.kind, right));
      await tester.pumpAndSettle();
      final rows = _rows(tester, _scope(_gen));
      expect(rows[index].status, EselStepStatus.done);
      final next = steps.indexWhere((s) => s.options.isNotEmpty, index + 1);
      expect(rows[next].status, EselStepStatus.open);
    });
  });

  group('(c) Zeigen', () {
    testWidgets('reveals the step and opens the next', (tester) async {
      final item = await _dominus();
      await _pumpChecked(tester, item, {_gen: 'dominis'});
      final steps = _contract(item, _gen, 'dominis');
      final index = _firstQuestion(steps);

      await tester.tap(
          find.byKey(Key('${_scope(_gen)}.${steps[index].kind.name}.show')));
      await tester.pumpAndSettle();

      final rows = _rows(tester, _scope(_gen));
      expect(rows[index].status, EselStepStatus.done);
      final next = steps.indexWhere((s) => s.options.isNotEmpty, index + 1);
      expect(rows[next].status, EselStepStatus.open);
    });
  });

  group('(d) initial state follows the contract', () {
    testWidgets('count, order, done and pending for noun and verb',
        (tester) async {
      for (final (item, key, answer) in [
        (await _dominus(), _gen, 'dominis'),
        (await _amare(), 'ind.praes.akt.3.sg', 'amet'),
      ]) {
        await _pumpChecked(tester, item, {key: answer});
        final steps = _contract(item, key, answer);
        final rows = _rows(tester, _scope(key));
        expect(rows.map((r) => r.step.kind), steps.map((s) => s.kind));
        final open = _firstQuestion(steps);
        for (var i = 0; i < steps.length; i++) {
          final expected = steps[i].options.isEmpty
              ? EselStepStatus.done
              : i == open
                  ? EselStepStatus.open
                  : EselStepStatus.pending;
          expect(rows[i].status, expected, reason: '${item.lemma} step $i');
        }
        final lautregel = rows.singleWhere((r) => r.step.kind == EselKind.lautregel);
        expect(lautregel.step.options, isNotEmpty);
      }
    });

    testWidgets('an absent step is done, dashed and says entfällt',
        (tester) async {
      final (item, key) = [
        for (final item in [await _dominus(), await _amare()])
          for (final key in item.formOrder)
            if (eselSteps(item, key).any((s) => s.absent)) (item, key),
      ].first;
      await _pumpChecked(tester, item, {key: 'zzz'});
      final steps = _contract(item, key, 'zzz');
      final rows = _rows(tester, _scope(key));
      expect(rows.map((r) => r.step.kind), steps.map((s) => s.kind));
      expect(rows.where((r) => r.step.absent), isNotEmpty);
      for (final row in rows) {
        final finder = find.byKey(Key('${_scope(key)}.${row.step.kind.name}'));
        expect(isDashed(tester, finder), row.step.absent,
            reason: '${row.step.kind}');
        if (!row.step.absent) continue;
        expect(row.status, EselStepStatus.done);
        expect(
          find.descendant(of: finder, matching: find.text('entfällt')),
          findsOneWidget,
        );
      }
    });
  });

  group('(e) a new check resets the panel', () {
    testWidgets('the steps start over on a new check', (tester) async {
      final item = await _dominus();
      await _pumpChecked(tester, item, {_gen: 'dominis'});
      final steps = _contract(item, _gen, 'dominis');
      final index = _firstQuestion(steps);
      final step = steps[index];

      await tester.tap(_option(_gen, step.kind, step.options.firstWhere((o) => o.isRight)));
      await tester.pumpAndSettle();
      expect(_rows(tester, _scope(_gen))[index].status, EselStepStatus.done);

      ProviderScope.containerOf(tester.element(find.byType(PracticeScreen)))
          .read(practiceProvider(item).notifier)
          .hideAnswers();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('practice.check.button')));
      await tester.pumpAndSettle();
      expect(_rows(tester, _scope(_gen))[index].status, EselStepStatus.open);
    });
  });

  group('(f) legend', () {
    testWidgets('the info button lists all six names', (tester) async {
      final item = await _dominus();
      final texts = await germanTexts();
      await _pumpChecked(tester, item, {_gen: 'dominis'});

      await tester.tap(find.byKey(Key('${_scope(_gen)}.info')));
      await tester.pumpAndSettle();

      for (final kind in EselKind.values) {
        final row = find.byKey(Key('esel.legend.${kind.name}'));
        expect(row, findsOneWidget);
        expect(
          find.descendant(
              of: row,
              matching: find.text(texts['esel.kind.${kind.name}.name']!)),
          findsOneWidget,
        );
        expect(
          find.descendant(
              of: row,
              matching:
                  find.text(texts['esel.legend.meaning.${kind.name}']!)),
          findsOneWidget,
        );
      }
    });
  });

  group('(g) classification', () {
    testWidgets('all steps done, no options, no Zeigen', (tester) async {
      await seedNothingDue({});
      final item = await _dominus();
      tester.view.physicalSize = const Size(1200, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrapInApp(
        WordClassificationScreen(item: item, formKey: _gen),
        forcedLocale: const Locale('de'),
      ));
      await letItLoad(tester);
      await pickOption(tester, 0, 'Genitiv');
      await pickOption(tester, 1, 'Singular');
      await tester.tap(find.byKey(const Key('wordClassification.check.button')));
      await tester.pumpAndSettle();

      final rows = _rows(tester, 'esel.classification');
      final steps = eselSteps(item, _gen);
      expect(rows.map((r) => r.step.kind), steps.map((s) => s.kind));
      expect(rows.map((r) => r.status).toSet(), {EselStepStatus.done});
      expect(
        find.descendant(
            of: find.byType(EselStaticSteps), matching: find.byType(OutlinedButton)),
        findsNothing,
      );
      expect(
        find.descendant(
            of: find.byType(EselStaticSteps), matching: find.byType(TextButton)),
        findsNothing,
      );
    });
  });

  group('(h) semantics', () {
    testWidgets('every badge reads "<letter> <name>"', (tester) async {
      final handle = tester.ensureSemantics();
      final item = await _dominus();
      final texts = await germanTexts();
      await _pumpChecked(tester, item, {_gen: 'dominis'});

      final badges = find.descendant(
          of: _panel(_gen), matching: find.byType(EselBadge));
      final rows = _rows(tester, _scope(_gen));
      expect(badges, findsNWidgets(rows.length));
      for (var i = 0; i < rows.length; i++) {
        final kind = rows[i].step.kind.name;
        expect(
          tester.getSemantics(badges.at(i)).label,
          '${texts['esel.kind.$kind.letter']} ${texts['esel.kind.$kind.name']}',
        );
      }
      handle.dispose();
    });
  });

  group('panel width', () {
    testWidgets('fills the content width, options inside it with whole labels',
        (tester) async {
      final item = await _dominus();
      await _pumpChecked(tester, item, {_gen: 'dominis'});
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();

      final panel = tester.getRect(_panel(_gen));
      expect(panel.width, 360 - 2 * 16);
      final steps = _contract(item, _gen, 'dominis');
      final step = steps[_firstQuestion(steps)];
      for (final option in step.options) {
        expect(
          tester.getRect(_option(_gen, step.kind, option)).right,
          lessThanOrEqualTo(panel.right),
        );
        final label = find.descendant(
            of: _option(_gen, step.kind, option), matching: find.byType(Text));
        final text = tester.widget<Text>(label);
        expect(text.maxLines, isNull);
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
            isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('touch targets', () {
    double minimumHeight(WidgetTester tester, Finder button) => tester
        .widget<ButtonStyleButton>(button)
        .style!
        .minimumSize!
        .resolve({})!
        .height;

    testWidgets('option buttons ask for 44 px and get them', (tester) async {
      final item = await _dominus();
      await _pumpChecked(tester, item, {_gen: 'dominis'});
      final steps = _contract(item, _gen, 'dominis');
      final step = steps[_firstQuestion(steps)];
      for (final option in step.options) {
        final button = _option(_gen, step.kind, option);
        expect(minimumHeight(tester, button), 44);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('Zeigen buttons ask for 44 px', (tester) async {
      final item = await _dominus();
      await _pumpChecked(tester, item, {_gen: 'dominis'});
      final shows = find.descendant(
          of: find.byType(EselPanel), matching: find.byType(TextButton));
      expect(shows, findsWidgets);
      for (final show in shows.evaluate()) {
        expect(minimumHeight(tester, find.byWidget(show.widget)), 44);
      }
    });

    testWidgets('the panel header asks for 44 px', (tester) async {
      final item = await _dominus();
      await _pumpChecked(tester, item, {_gen: 'dominis'});
      final header = find.descendant(
        of: find.byKey(Key('${_scope(_gen)}.toggle')),
        matching: find.byType(ConstrainedBox),
      );
      expect(
        header.evaluate().map((e) => (e.widget as ConstrainedBox).constraints.minHeight),
        contains(44.0),
      );
    });
  });

  test('every esel key the screens use exists in de.json and en.json',
      () async {
    final used = <String>{};
    for (final path in [
      'lib/screens/practice_screen.dart',
      'lib/screens/word_classification_screen.dart',
      'lib/widgets/esel_panel.dart',
    ]) {
      final source = File(path).readAsStringSync();
      for (final match
          in RegExp(r"translate\(\s*context,\s*'(esel\.[^']+)'").allMatches(source)) {
        final key = match.group(1)!;
        if (key.contains(r'${kind.name}')) {
          for (final kind in EselKind.values) {
            used.add(key.replaceAll(r'${kind.name}', kind.name));
          }
        } else {
          used.add(key);
        }
      }
    }
    expect(used, containsAll(['esel.show', 'esel.panel.title', 'esel.absentLabel']));
    for (final texts in [await germanTexts(), await englishTexts()]) {
      expect(used.where((k) => !texts.containsKey(k)), isEmpty);
    }
  });
}
