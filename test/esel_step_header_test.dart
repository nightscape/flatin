import 'dart:io';
import 'dart:typed_data' show ByteData;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/diagnosis.dart' show diagnose;
import 'package:latin_practice/data/esel_steps.dart';

import 'package:latin_practice/models/practice_item.dart';

import 'support/esel_render.dart';

const _gen = 'gen.pl';
const _fonts = '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts';

// The test font Ahem has fixed glyph widths; real label widths need Roboto.
Future<void> _loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final file in ['Regular', 'Medium', 'Bold']) {
    final bytes = await File('$_fonts/Roboto-$file.ttf').readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRoboto);

  late PracticeItem item;
  late EselStep step;

  Future<void> pump360(WidgetTester tester) async {
    item = await loadItem('lib/data/latin_nouns.yaml', 'dominus');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpChecked(tester, item, {_gen: 'dominis'});
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    step = eselSteps(
      item,
      _gen,
      diagnosis: diagnose(item, _gen, 'dominis'),
    ).firstWhere((s) => s.options.isNotEmpty);
  }

  Finder card() => find.byKey(Key('esel.$_gen.${step.kind.name}'));
  Finder option(EselOption o) =>
      find.byKey(Key('esel.$_gen.${step.kind.name}.option.${o.identity}'));

  testWidgets('360 dp: each answer label is one line, none is clipped', (
    tester,
  ) async {
    await pump360(tester);
    expect(step.options.length, greaterThan(1));
    for (final o in step.options) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: option(o), matching: find.byType(RichText)).first,
      );
      expect(
        paragraph.size.height,
        paragraph.getMinIntrinsicHeight(double.infinity),
        reason: '${o.identity} is one line',
      );
      expect(paragraph.didExceedMaxLines, isFalse, reason: o.identity);
      expect(
        tester.getRect(option(o)).right,
        lessThanOrEqualTo(tester.getRect(card()).right),
        reason: o.identity,
      );
    }
  });

  testWidgets('360 dp: Zeigen ends the header row, answers lie below it', (
    tester,
  ) async {
    await pump360(tester);
    final rect = tester.getRect(card());
    final show = tester.getRect(
      find.byKey(Key('esel.$_gen.${step.kind.name}.show')),
    );
    final name = tester.getRect(
      find.descendant(of: card(), matching: find.byType(Text)).at(1),
    );
    expect(show.center.dy, closeTo(name.center.dy, 4));
    expect(show.right, lessThanOrEqualTo(rect.right));
    expect(show.right, greaterThan(rect.right - 16));
    expect(show.height, greaterThanOrEqualTo(44));
    for (final o in step.options) {
      final button = tester.getRect(option(o));
      expect(
        button.top,
        greaterThanOrEqualTo(show.bottom - 1),
        reason: o.identity,
      );
      expect(button.height, greaterThanOrEqualTo(44), reason: o.identity);
    }
  });
}
