// Screenshots of the "Buch" tab, not a regression test. Runs only with
// --dart-define=SHOTS=<dir>; writes <PREFIX>-*.png of tab <BUCH> there.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/experiments/kursstand_chain.dart';
import 'package:latin_practice/theme.dart';

const _fonts = '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';
const _dir = String.fromEnvironment('SHOTS');
const _variant = String.fromEnvironment('BUCH', defaultValue: 'Buch');
const _prefix = String.fromEnvironment('PREFIX', defaultValue: 'buch');

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(File('$_fonts/$f').readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']);
    await _load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  testWidgets('Buch screenshots', skip: _dir.isEmpty, (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: romanTheme.copyWith(
          textTheme: romanTheme.textTheme.apply(fontFamily: 'Roboto'),
        ),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: 'Roboto'),
              child: kursstandVariants()[_variant]!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> shoot(String card, String name) async {
      final rect = tester.getRect(find.byKey(Key(card)));
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 3);
        final recorder = ui.PictureRecorder();
        final src = Rect.fromLTRB(
          rect.left * 3,
          rect.top * 3,
          rect.right * 3,
          rect.bottom * 3,
        );
        Canvas(
          recorder,
        ).drawImageRect(image, src, Offset.zero & src.size, Paint());
        final cropped = await recorder.endRecording().toImage(
          src.width.round(),
          src.height.round(),
        );
        final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
        File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    await shoot('Beide verbunden', '$_prefix-a2-verbunden');
    await shoot('Rechts verbunden', '$_prefix-a1-kette-offen');
    await shoot('Beide offen', '$_prefix-beide-offen');
    await shoot('Wörter bis Später', '$_prefix-bis-spaeter');

    // Word end from L32 into A3: A3 opens, A2 goes half open.
    final slider = tester.getRect(
      find
          .descendant(
            of: find.byKey(const Key('Beide verbunden')),
            matching: find.byType(RangeSlider),
          )
          .first,
    );
    var x = slider.left + slider.width * 0.61;
    final gesture = await tester.startGesture(Offset(x, slider.center.dy));
    for (var i = 0; i < 12; i++) {
      x += 4;
      await gesture.moveTo(Offset(x, slider.center.dy));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shoot('Beide verbunden', '$_prefix-oeffnen-1');
    await tester.pump(const Duration(milliseconds: 60));
    await shoot('Beide verbunden', '$_prefix-oeffnen-2');
    await tester.pump(const Duration(milliseconds: 60));
    await shoot('Beide verbunden', '$_prefix-oeffnen-3');
    await tester.pumpAndSettle();
    await shoot('Beide verbunden', '$_prefix-gezogen-a3');
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
  });
}
