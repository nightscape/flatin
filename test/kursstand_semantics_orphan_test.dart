// Property: every semantics node sent to the engine hangs under the root in
// traversal order. The macOS accessibility bridge crashes on an update that
// breaks this.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/settings.dart';
import 'package:latin_practice/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/kursstand_shelf_driver.dart';
import 'support/word_classification_harness.dart';

final _children = <int, List<int>>{};
final _orphans = <String>[];
var _phase = '';

class _RecordingBuilder implements ui.SemanticsUpdateBuilder {
  final _sent = <int>[];

  @override
  ui.SemanticsUpdate build() {
    final reached = <int>{};
    void walk(int id) {
      if (!reached.add(id)) return;
      _children[id]?.forEach(walk);
    }

    walk(0);
    for (final id in _sent.where((id) => !reached.contains(id))) {
      _orphans.add('$_phase: node $id');
    }
    return ui.SemanticsUpdateBuilder().build();
  }

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #updateNode) {
      final id = i.namedArguments[#id] as int;
      _sent.add(id);
      _children[id] = (i.namedArguments[#childrenInTraversalOrder] as Int32List)
          .toList();
    }
    return null;
  }
}

class _RecordingBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      _RecordingBuilder();
}

void main() {
  _RecordingBinding();

  testWidgets('scrolling the Kursstand card away and back, dragging both '
      'ranges and tying both bounds sends no orphan semantics node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({
      'practice_settings': jsonEncode(Settings().toJson()),
    });
    tester.view.physicalSize = const Size(780, 1264);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    _phase = 'load';
    await tester.pumpWidget(
      wrapInApp(const SettingsScreen(), forcedLocale: const Locale('de')),
    );
    await letItLoad(tester);
    for (final (words, to) in [(true, 25), (false, 12)]) {
      _phase = 'drag ${words ? 'words' : 'grammar'}';
      await dragBound(tester, words: words, start: false, to: to);
      _phase = 'scroll away and back, ${words ? 'words' : 'grammar'}';
      for (var k = 0; k < 20; k++) {
        await tester.dragFrom(
          const Offset(4, 300),
          Offset(0, k < 10 ? -100 : 100),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
    }
    for (final side in ['left', 'right']) {
      _phase = 'tie or untie the $side bound';
      tester
          .widget<Semantics>(find.byKey(Key('kursstand.tie.$side')))
          .properties
          .onTap!();
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 4));
    semantics.dispose();
    expect(_orphans, isEmpty);
  });
}
