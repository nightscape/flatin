import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/experiments/kursstand_chain.dart';
import 'package:latin_practice/theme.dart';

Future<void> _loadIcons() async {
  final loader = FontLoader('MaterialIcons')
    ..addFont(
      File(
        '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  await loader.load();
}

void main() {
  setUpAll(_loadIcons);

  for (final shelf in [false, true]) {
    testWidgets('after the thumb enters a book, the widths hold while it stays '
        'there: holding 5 s, fine drags, release${shelf ? ' (shelf)' : ''}', (
      tester,
    ) async {
      late BookScale scale;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: romanTheme,
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 366,
                child: BookSliders(
                  key: key,
                  focus: BookFocus.idle,
                  words: (from: 25, to: 32),
                  grammar: (from: 1, to: 32),
                  links: (left: false, right: true),
                  shelf: shelf,
                  onScale: (s) => scale = s,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(find.byKey(key));
      final before = scale.widths;
      expect(before[0], lessThan(before[1]), reason: 'Agite 1 starts squeezed');

      // The word start leaves Agite 2 to the left in 4 px steps.
      var x = scale.x(25);
      final gesture = await tester.startGesture(origin + Offset(x, 76));
      while (scale.lessonAt(x) > 20) {
        x -= 4;
        await gesture.moveTo(origin + Offset(x, 76));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      final entered = scale.widths;
      expect(entered[0], greaterThan(before[0]), reason: 'Agite 1 opens');

      void expectHeld(String when) {
        expect(scale.widths, entered, reason: when);
        expect(scale.lessonAt(x), lessThanOrEqualTo(20), reason: when);
      }

      for (var t = 0; t < 50; t++) {
        await tester.pump(const Duration(milliseconds: 100));
        expectHeld('holding, ${t * 100} ms');
      }
      for (final dx in [-3.0, -3.0, 3.0, -2.0]) {
        x += dx;
        await gesture.moveTo(origin + Offset(x, 76));
        for (var f = 0; f < 20; f++) {
          await tester.pump(const Duration(milliseconds: 16));
          expectHeld('fine drag by $dx, frame $f');
        }
      }
      await gesture.up();
      for (var t = 0; t < 35; t++) {
        await tester.pump(const Duration(milliseconds: 100));
        expectHeld('released, ${t * 100} ms');
      }
    });
  }
}
