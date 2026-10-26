import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const stepShots = bool.fromEnvironment('STEP_SHOTS');

final _runDir =
    'build/step_shots/'
    '${DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}';
var _counter = 0;

const _transliteration = {'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss'};

String _slug(String text) {
  final slug = text
      .toLowerCase()
      .replaceAllMapped(RegExp('[äöüß]'), (m) => _transliteration[m[0]]!)
      .replaceAll(RegExp('[^a-z0-9]+'), '-');
  final cut = slug.replaceAll(RegExp(r'^-|-$'), '');
  return (cut.length > 40 ? cut.substring(0, 40) : cut).replaceAll(
    RegExp(r'-$'),
    '',
  );
}

/// `<counter, 4 digits>-<feature>-<scenario>-<step>[-FAILED].png`; the step
/// text loses its Gherkin keyword.
String stepShotName(
  int counter,
  String feature,
  String scenario,
  String step, {
  bool failed = false,
}) {
  final text = step.replaceFirst(RegExp(r'^(Given|When|Then|And|But) '), '');
  return '${counter.toString().padLeft(4, '0')}-${_slug(feature)}-'
      '${_slug(scenario)}-${_slug(text)}${failed ? '-FAILED' : ''}.png';
}

/// Runs one Cucumber step; with `--dart-define=STEP_SHOTS=true` it saves the
/// screen after the step, also when the step throws.
Future<void> step(
  WidgetTester tester,
  String feature,
  String scenario,
  String text,
  Future<void> running,
) async {
  if (!stepShots) return running;
  final counter = ++_counter;
  try {
    await running;
  } catch (_) {
    await _save(
      tester,
      stepShotName(counter, feature, scenario, text, failed: true),
    );
    rethrow;
  }
  await _save(tester, stepShotName(counter, feature, scenario, text));
}

Future<void> _save(WidgetTester tester, String name) async {
  await tester.pump();
  final boundaries = find.byType(RepaintBoundary);
  final bytes = await tester.runAsync(() async {
    final ui.Image image;
    if (boundaries.evaluate().isEmpty) {
      // Before the app runs there is no screen: a blank picture keeps the
      // one-picture-per-step numbering.
      final size = tester.view.physicalSize;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(const Color(0xFFFFFFFF), BlendMode.src);
      image = await recorder.endRecording().toImage(
        size.width.round(),
        size.height.round(),
      );
    } else {
      image = await tester
          .renderObject<RenderRepaintBoundary>(boundaries.first)
          .toImage();
    }
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  });
  File('$_runDir/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}
