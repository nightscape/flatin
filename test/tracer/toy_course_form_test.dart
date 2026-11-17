@Tags(['tracer'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/practice_data.dart';
import 'package:latin_practice/main.dart';
import 'package:latin_practice/screens/exam_list_screen.dart';
import 'package:latin_practice/screens/exam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/word_classification_harness.dart' show letItLoad;
import 'toy_assets.dart';

const _language = '$toyDir/toy_language.yaml';

/// Every subset of the toy language's `analyse` keys as its `form` line.
Iterable<List<String>> _forms() sync* {
  const keys = ['wortart', 'ruf', 'zal'];
  for (var mask = 0; mask < 1 << keys.length; mask++) {
    yield [
      for (var b = 0; b < keys.length; b++)
        if (mask & (1 << b) != 0) keys[b],
    ];
  }
}

void main() {
  final source = File(_language).readAsStringSync();
  assert(source.contains('form: [ruf, zal]'));
  for (final form in _forms()) {
    testWidgets('the exam screen opens the toy pack when the language forms '
        'words with $form', (tester) async {
      resetPracticeDataForTest();
      SharedPreferences.setMockInitialValues({});
      injectToyCourse(
        served: {
          _language: source.replaceFirst(
            'form: [ruf, zal]',
            'form: [${form.join(', ')}]',
          ),
        },
      );
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(retry: noRetry, child: LatinPracticeApp()),
      );
      await letItLoad(tester);
      final pack = File('$toyDir/toy.exam').readAsBytesSync();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ExamListScreen(pickBytes: () async => pack),
            ),
          );
      await letItLoad(tester);
      await tester.tap(find.byKey(const Key('exam.import')));
      await letItLoad(tester);
      await tester.tap(find.byKey(const Key('exam.list.toy-pack')));
      await letItLoad(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(ExamScreen), findsOneWidget);
      expect(find.byKey(const Key('exam.finish')), findsOneWidget);
    });
  }
}
