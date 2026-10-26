import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/lesson_range.dart';
import 'package:latin_practice/models/settings.dart';

import 'support/stored_settings.dart';
import 'support/word_classification_harness.dart' show letItLoad;

Finder _key(String key) => find.byKey(Key(key));

double _x(WidgetTester tester, int lesson) =>
    tester.getCenter(_key('kursstand.words.bar.$lesson')).dx;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('while a handle is held, a drag on the other slider, a bar tap '
      'and a chain toggle change neither the settings nor the layout', (
    tester,
  ) async {
    await openSettingsWith(
      tester,
      Settings(courseWords: LessonRange(25, 32)).toJson(),
    );
    final before = await storedSettings();
    double width() => tester.getSize(_key('kursstand.words.bar.5')).width;

    final words = tester.getCenter(_key('kursstand.words.slider')).dy;
    final held = await tester.startGesture(
      Offset(_x(tester, 32), words),
      pointer: 10,
    );
    await held.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await held.moveBy(const Offset(-20, 0));
    await tester.pumpAndSettle();
    final layout = width();

    final grammar = tester.getCenter(_key('kursstand.grammar.slider')).dy;
    final second = await tester.startGesture(
      Offset(_x(tester, 32), grammar),
      pointer: 11,
    );
    for (var i = 0; i < 10; i++) {
      await second.moveBy(const Offset(-15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await second.up();
    await tester.tap(_key('kursstand.grammar.bar.10'), warnIfMissed: false);
    await tester.tap(_key('kursstand.chain.left'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await letItLoad(tester);

    expect(await storedSettings(), before);
    expect(width(), layout);

    await held.up();
    await tester.pumpAndSettle();
    await letItLoad(tester);
    expect(await storedSettings(), before);
    expect(width(), layout);
  });
}
