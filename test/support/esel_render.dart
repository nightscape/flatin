/// Pumps the practice screen with wrong answers and prints the rendered ESEL
/// step rows as plain text. Run with ESEL_GOLDEN_UPDATE=1 to rewrite the
/// goldens under test/golden/.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/esel_steps.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/screens/practice_screen.dart';
import 'package:latin_practice/screens/word_classification_screen.dart';
import 'package:latin_practice/widgets/esel_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'word_classification_harness.dart';

Future<PracticeItem> loadItem(String asset, String lemma) async =>
    (await loadPracticeItems(asset)).firstWhere((i) => i.lemma == lemma);

/// Pumps the practice screen of [item] and checks [wrong] (form key to wrong
/// answer); every other field stays empty.
Future<void> pumpChecked(
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

/// Pumps the classification screen on [formKey] and answers every selector
/// with the value of the form's label, except the last one the label names,
/// which gets another value, and the axes it does not name, which get their
/// first value: the explanation box shows after a wrong answer only.
Future<void> pumpClassified(
  WidgetTester tester,
  PracticeItem item,
  String formKey,
) async {
  await seedNothingDue({});
  tester.view.physicalSize = const Size(1200, 4800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapInApp(
    WordClassificationScreen(item: item, formKey: formKey),
    forcedLocale: const Locale('de'),
  ));
  await letItLoad(tester);

  final label = item.formLabels[item.formOrder.indexOf(formKey)];
  final shown = [
    for (final axis in label.axes.axes)
      if (find.byKey(Key('classification.0.${axis.id}')).evaluate().isNotEmpty)
        axis,
  ];
  final lastAsked = shown.lastWhere((a) => label.features.containsKey(a.id));
  for (final axis in shown) {
    final String? right = label.features[axis.id];
    final String code = axis == lastAsked
        ? axis.values.map((v) => v.$1).firstWhere((c) => c != right)
        : right ?? axis.values.first.$1;
    final dropdown = find.byKey(Key('classification.0.${axis.id}'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(axis.values.firstWhere((v) => v.$1 == code).$2).last);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('wordClassification.check.button')));
  await tester.pumpAndSettle();
}

List<EselStepRow> stepRows(WidgetTester tester, String scope) => tester
    .widgetList<EselStepRow>(
        find.byWidgetPredicate((w) => w is EselStepRow && w.scope == scope))
    .toList();

Finder stepRow(String scope, EselKind kind) =>
    find.byKey(Key('$scope.${kind.name}'));

/// Whether the border of a step row is drawn dashed; the painter is private.
bool isDashed(WidgetTester tester, Finder row) =>
    (tester.widget<CustomPaint>(row).painter! as dynamic).dashed as bool;

/// One line per step: letter, name, state, then what the row shows. Options
/// are sorted, so the golden does not depend on the shuffle.
String renderSteps(WidgetTester tester, String scope) {
  final lines = <String>[];
  for (final row in stepRows(tester, scope)) {
    final finder = stepRow(scope, row.step.kind);
    List<Text> inside(Finder matching) => tester
        .widgetList<Text>(find.descendant(of: finder, matching: matching))
        .toList();
    final texts = inside(find.byType(Text));
    final badge = inside(find.descendant(
        of: find.byType(EselBadge), matching: find.byType(Text)));
    final buttonTexts = inside(find.descendant(
        of: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        matching: find.byType(Text)));
    final optionTexts = inside(find.descendant(
        of: find.byType(OutlinedButton), matching: find.byType(Text)));

    final letter = badge.single.data!;
    final name = texts[1].data!;
    final shown = [
      for (final text in texts.skip(2))
        if (!buttonTexts.contains(text))
          text.style?.decoration == TextDecoration.lineThrough
              ? '~${text.data}~'
              : text.data!,
    ];
    final options = [for (final text in optionTexts) text.data!]..sort();
    final show = [
      for (final text in buttonTexts)
        if (!optionTexts.contains(text)) text.data!,
    ];

    lines.add([
      '$letter $name',
      row.status.name + (isDashed(tester, finder) ? ' (gestrichelt)' : ''),
      if (shown.isNotEmpty) shown.join(' / '),
      if (options.isNotEmpty) 'Optionen: ${options.join(' ; ')}',
      if (show.isNotEmpty) '[${show.join()}]',
    ].join(' | '));
  }
  return '${lines.join('\n')}\n';
}

void expectGolden(String name, String actual) {
  final file = File('test/golden/esel_$name.txt');
  if (Platform.environment['ESEL_GOLDEN_UPDATE'] == '1') {
    file.writeAsStringSync(actual);
    return;
  }
  expect(actual, file.readAsStringSync(), reason: 'golden ${file.path}');
}
