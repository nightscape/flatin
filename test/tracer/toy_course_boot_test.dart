@Tags(['tracer'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart';
import 'package:latin_practice/providers/fsrs_provider.dart';
import 'package:latin_practice/screens/exam_list_screen.dart';
import 'package:latin_practice/screens/home_screen.dart';
import 'package:latin_practice/screens/round_end_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/round_driver.dart';
import '../support/word_classification_harness.dart' show letItLoad;
import 'toy_assets.dart';

typedef TracerStep = ({
  String id,
  bool red,
  Future<void> Function(WidgetTester) run,
});

/// The app run with only the toy course. A step marked `red` is listed in
/// test/tracer/KNOWN_RED.md with its first error; it fails here either way,
/// and when it passes the failure says to unmark it.
final tracerSteps = <TracerStep>[
  (id: 'home', red: true, run: _home),
  (id: 'round', red: true, run: _round),
  (id: 'settings', red: true, run: _settings),
  (id: 'exam-import', red: true, run: _examImport),
];

const _toyFile = 'toy_words';

Future<void> _boot(WidgetTester tester) async {
  resetPracticeDataForTest();
  SharedPreferences.setMockInitialValues({});
  injectToyCourse();
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const ProviderScope(retry: noRetry, child: LatinPracticeApp()),
  );
  await letItLoad(tester);
}

/// Fails with what the screen shows when [finder] is not on it.
void _expectShown(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isNotEmpty) return;
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .take(5);
  fail('no $finder; the screen shows: ${texts.join(' | ')}');
}

Future<void> _home(WidgetTester tester) async {
  await _boot(tester);
  final due = ProviderScope.containerOf(
    tester.element(find.byType(HomeScreen)),
  ).read(dueItemsByTypeProvider);
  if (due.hasError) Error.throwWithStackTrace(due.error!, due.stackTrace!);
  expect(due.requireValue[_toyFile], hasLength(4));
}

Future<void> _round(WidgetTester tester) async {
  await _boot(tester);
  _expectShown(tester, find.byKey(const Key('home.grammar.button')));
  await tap(tester, 'home.grammar.button');
  await letItLoad(tester);
  _expectShown(tester, find.byKey(const Key('round.start.go')));
  await tap(tester, 'round.start.go');
  await letItLoad(tester);
  for (var n = 0; find.byType(RoundEndScreen).evaluate().isEmpty; n++) {
    expect(n, lessThan(100), reason: 'the round does not end');
    await answer(tester, shown(tester), right: true);
    await letItLoad(tester);
  }
}

Future<void> _settings(WidgetTester tester) async {
  await _boot(tester);
  tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  await letItLoad(tester);
  await tap(tester, 'drawer.settings');
  await letItLoad(tester);
  _expectShown(tester, find.byKey(const Key('settings.tile.$_toyFile')));
  await tap(tester, 'settings.tile.$_toyFile');
  await letItLoad(tester);
  _expectShown(tester, find.byKey(const Key('form.$_toyFile.tu.ein')));
}

Future<void> _examImport(WidgetTester tester) async {
  await _boot(tester);
  final pack = File('$toyDir/toy.exam').readAsBytesSync();
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => ExamListScreen(pickBytes: () async => pack),
        ),
      );
  await letItLoad(tester);
  await tap(tester, 'exam.import');
  await letItLoad(tester);
  final refused = find.byKey(const Key('exam.import.refused'));
  if (refused.evaluate().isNotEmpty) {
    fail('the pack is refused: ${tester.widget<Text>(refused).data}');
  }
  _expectShown(tester, find.byKey(const Key('exam.list.toy-pack')));
}

void main() {
  for (final step in tracerSteps) {
    testWidgets('the app runs the toy course: ${step.id}', (tester) async {
      await step.run(tester);
      if (step.red) {
        fail(
          '${step.id} passes: mark it green in tracerSteps and drop its '
          'line from test/tracer/KNOWN_RED.md',
        );
      }
    });
  }
}
