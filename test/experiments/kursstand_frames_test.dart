// Frame captures and measurements for the Kursstand book tabs, not a
// regression test. Frames run only when writing goldens:
// flutter test test/experiments/kursstand_frames_test.dart --update-goldens
// Measurements run only with --dart-define=OUT=<file>.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/experiments/kursstand_chain.dart';
import 'package:latin_practice/theme.dart';

import '../support/preloaded_i18n.dart';

const _fonts = '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';
const _out = String.fromEnvironment('OUT');

const _tabs = {
  BookFocus.thumbs: 'griffe',
  BookFocus.dragged: 'gezogen',
  BookFocus.shrinkAfterRelease: 'schrumpft',
  BookFocus.idle: 'ruhezeit',
  BookFocus.draggedOnRelease: 'nach-loslassen',
};

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(
      File('$_fonts/$f').readAsBytes().then((b) => ByteData.sublistView(b)),
    );
  }
  await loader.load();
}

final _finger = ValueNotifier<Offset?>(null);
final _scales = <String, BookScale>{};

Future<void> _pumpBooks(WidgetTester tester, BookFocus focus) async {
  tester.view.physicalSize = const Size(780, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: [_i18n],
      debugShowCheckedModeBanner: false,
      theme: romanTheme,
      home: Scaffold(
        body: Stack(
          children: [
            BooksDemo(focus: focus, onScale: (c, s) => _scales[c] = s),
            IgnorePointer(
              child: ValueListenableBuilder(
                valueListenable: _finger,
                builder: (_, f, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _FingerPainter(f),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FingerPainter extends CustomPainter {
  _FingerPainter(this.at);
  final Offset? at;
  @override
  void paint(Canvas canvas, Size size) {
    if (at == null) return;
    final p = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1;
    canvas
      ..drawLine(at! - const Offset(0, 30), at! + const Offset(0, 30), p)
      ..drawCircle(at!, 3, p);
  }

  @override
  bool shouldRepaint(_FingerPainter old) => true;
}

/// A drag on the word slider of [card], in global coordinates.
class _Drag {
  _Drag(this.tester, this.card);

  final WidgetTester tester;
  final String card;
  late final Rect slider = tester.getRect(
    find
        .descendant(
          of: find.byKey(Key(card)),
          matching: find.byType(RangeSlider),
        )
        .first,
  );
  late TestGesture _gesture;
  late double x;

  BookScale get scale => _scales[card]!;
  double xOf(int lesson) => slider.left + scale.x(lesson);
  int get lesson => scale.lessonAt(x - slider.left);

  /// Grabs the thumb at [lesson] and moves past the drag slop and back, so
  /// the next move already drags.
  Future<void> down(int lesson) async {
    x = xOf(lesson);
    _gesture = await tester.startGesture(Offset(x, slider.center.dy));
    _finger.value = Offset(x, slider.center.dy);
    await _gesture.moveBy(const Offset(20, 0));
    await _gesture.moveTo(Offset(x, slider.center.dy));
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// Moves 4 px per 16 ms frame towards [to] until there, or until [stop].
  Future<void> moveTo(double to, {bool Function()? stop}) async {
    while (x != to && !(stop?.call() ?? false)) {
      x = to < x ? max(x - 4, to) : min(x + 4, to);
      await _gesture.moveTo(Offset(x, slider.center.dy));
      _finger.value = Offset(x, slider.center.dy);
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> up() async {
    await _gesture.up();
    _finger.value = null;
    await tester.pump(const Duration(milliseconds: 16));
  }
}

late final LocalizationsDelegate<FlutterI18n> _i18n;

void main() {
  setUpAll(() async => _i18n = await preloadedI18n());
  setUpAll(() async {
    await _load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']);
    await _load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  for (final MapEntry(key: focus, value: tab) in _tabs.entries) {
    group(tab, () {
      const card = 'Grammatik ab L1';
      var frame = 0;
      Future<void> shot(WidgetTester tester, String scene, String label) =>
          expectLater(
            find.byKey(const Key(card)),
            matchesGoldenFile(
              'frames/$tab-$scene-${(frame++).toString().padLeft(2, '0')}-'
              '$label.png',
            ),
          );

      for (final scene in ['a1-ende', 'a1-anfang']) {
        testWidgets(
          'word start from Agite 2 to $scene and back',
          (tester) async {
            frame = 0;
            await _pumpBooks(tester, focus);
            final d = _Drag(tester, card);
            Future<void> hold(String label) async {
              var held = 0;
              for (final ms in [0, 100, 150]) {
                await tester.pump(Duration(milliseconds: ms));
                held += ms;
                await shot(tester, scene, '$label-${held}ms');
              }
            }

            await shot(tester, scene, 'start');
            await d.down(25);
            await d.moveTo(d.slider.left, stop: () => d.lesson <= 20);
            await hold('grenze-gehalten');
            if (scene == 'a1-anfang') {
              await d.moveTo(d.slider.left);
              await hold('anfang-gehalten');
            }
            await d.moveTo(d.slider.right, stop: () => d.lesson >= 25);
            await hold('zurueck-ab-L25-gehalten');
            await d.up();
            await tester.pumpAndSettle();
            await shot(tester, scene, 'losgelassen');
            await tester.pump(const Duration(milliseconds: 3500));
            await tester.pumpAndSettle();
            await shot(tester, scene, 'nach-3-5s');
          },
          skip: !autoUpdateGoldenFiles,
        );
      }

      testWidgets('fine drag of word end inside Agite 2', (tester) async {
        frame = 0;
        await _pumpBooks(tester, focus);
        final d = _Drag(tester, card);
        await shot(tester, 'fein', 'start');
        await d.down(32);
        for (var l = 33; l <= 36; l++) {
          await d.moveTo(d.xOf(l));
          await tester.pump(const Duration(milliseconds: 300));
          await shot(tester, 'fein', 'gehalten-L$l');
        }
        await d.up();
        await tester.pumpAndSettle();
        await shot(tester, 'fein', 'losgelassen');
        await tester.pump(const Duration(seconds: 4));
      }, skip: !autoUpdateGoldenFiles);
    });
  }

  testWidgets('idle: widths hold still after entering Agite 1', (tester) async {
    const card = 'Grammatik ab L1';
    var frame = 0;
    Future<void> shot(String label) => expectLater(
      find.byKey(const Key(card)),
      matchesGoldenFile(
        'frames/ruhezeit-a1-5s-fein-'
        '${(frame++).toString().padLeft(2, '0')}-$label.png',
      ),
    );

    await _pumpBooks(tester, BookFocus.idle);
    final d = _Drag(tester, card);
    await shot('start');
    await d.down(25);
    await d.moveTo(d.slider.left, stop: () => d.lesson <= 20);
    await shot('grenze-0ms');
    await tester.pump(const Duration(milliseconds: 300));
    await shot('grenze-300ms');
    final entered = [...d.scale.widths];
    var held = 300;
    for (final ms in [700, 2000, 2000]) {
      await tester.pump(Duration(milliseconds: ms));
      held += ms;
      await shot('gehalten-${held}ms');
      expect(d.scale.widths, entered);
    }
    for (var step = 1; step <= 3; step++) {
      await d.moveTo(d.x - d.scale.cell(1));
      await tester.pump(const Duration(milliseconds: 300));
      await shot('fein-$step-L${d.lesson}');
      expect(d.scale.widths, entered);
    }
    await d.up();
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();
    await shot('losgelassen-nach-3-5s');
    expect(d.scale.widths, entered);
  }, skip: !autoUpdateGoldenFiles);

  testWidgets('px per lesson of Agite 1 and 2', (tester) async {
    final lines = <String>['Tab\tKarte\tZustand\tAgite 1 px/L\tAgite 2 px/L'];
    String perLesson(BookScale s, int book) =>
        (s.widths[book] / 20).toStringAsFixed(1);
    void row(String tab, String card, String state, BookScale s) => lines.add(
      '$tab\t$card\t$state\t${perLesson(s, 0)}\t${perLesson(s, 1)}',
    );

    for (final MapEntry(key: focus, value: tab) in _tabs.entries) {
      for (final card in ['Grammatik ab L1', 'Grammatik in Agite 1']) {
        await _pumpBooks(tester, focus);
        final d = _Drag(tester, card);
        row(tab, card, 'Ruhe', d.scale);
        await d.down(32);
        await d.moveTo(d.xOf(34));
        await tester.pump(const Duration(milliseconds: 300));
        expect(d.lesson, inInclusiveRange(21, 40), reason: 'left Agite 2');
        row(tab, card, 'Wort-Ende zieht in Agite 2', d.scale);
        await d.up();
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpWidget(const SizedBox());
      }
    }

    lines.addAll([
      '',
      'Wort-Anfang L25 nach links, Finger hält an, sobald die Lektion '
          '≤ L20 ist; dann nach rechts, hält an, sobald ≥ L25 (Karte '
          '„Grammatik ab L1“). Lektion unter dem stillen Finger '
          '(der Griff selbst endet höchstens beim Wort-Ende L32):',
      'Tab\tüber Grenze\t+250 ms\tzurück\t+250 ms',
    ]);
    for (final MapEntry(key: focus, value: tab) in _tabs.entries) {
      await _pumpBooks(tester, focus);
      final d = _Drag(tester, 'Grammatik ab L1');
      final seen = <int>[];
      Future<void> hold() async {
        seen.add(d.lesson);
        await tester.pump(const Duration(milliseconds: 250));
        seen.add(d.lesson);
      }

      await d.down(25);
      await d.moveTo(d.slider.left, stop: () => d.lesson <= 20);
      await hold();
      await d.moveTo(d.slider.right, stop: () => d.lesson >= 25);
      await hold();
      lines.add([tab, for (final l in seen) 'L$l'].join('\t'));
      await d.up();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    }
    File(_out).writeAsStringSync('${lines.join('\n')}\n');
  }, skip: _out.isEmpty);
}
