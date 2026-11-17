import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/settings.dart';

import 'support/latin_course.dart' show latinLastLesson;
import 'support/stored_settings.dart';

void main() {
  testWidgets('the settings screen shows the stored stem marking and stores '
      'each chosen one; zeigen stays unwritten', (tester) async {
    final rng = Random(4183);
    await openSettingsWith(
      tester,
      Settings(lastLesson: latinLastLesson).toJson(),
    );
    SegmentedButton<StemMarking> segments() =>
        tester.widget(find.byKey(const Key('settings.stemMarking')));
    expect(segments().selected, {StemMarking.zeigen});
    for (var i = 0; i < 12; i++) {
      final mode = StemMarking.values[rng.nextInt(StemMarking.values.length)];
      final label = find.byKey(Key('settings.stemMarking.${mode.name}'));
      await tester.ensureVisible(label);
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(segments().selected, {mode});
      final stored = await tester.runAsync(storedSettings);
      expect(
        stored!['stemMarking'],
        mode == StemMarking.zeigen ? isNull : mode.name,
      );
      expect(
        Settings.fromJson(stored, lastLesson: latinLastLesson).stemMarking,
        mode,
      );
    }
  });
}
