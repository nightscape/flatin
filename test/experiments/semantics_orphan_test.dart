// Property: every semantics node sent to the engine hangs under the root in
// traversal order. The macOS accessibility bridge crashes on an update that
// breaks this.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/experiments/kursstand_chain.dart';
import 'package:latin_practice/theme.dart';

import '../support/preloaded_i18n.dart';

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

late final LocalizationsDelegate<FlutterI18n> _i18n;

void main() {
  setUpAll(() async => _i18n = await preloadedI18n());
  _RecordingBinding();

  testWidgets('switching tabs, scrolling and dragging sends no orphan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(780, 1264);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final variants = kursstandVariants();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [_i18n],
          theme: romanTheme,
          home: DefaultTabController(
            length: variants.length,
            child: Scaffold(
              appBar: AppBar(
                bottom: TabBar(
                  isScrollable: true,
                  tabs: [for (final n in variants.keys) Tab(text: n)],
                ),
              ),
              body: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: variants.values.toList(),
              ),
            ),
          ),
        ),
      ),
    );
    for (final name in variants.keys) {
      _phase = 'tab $name';
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      _phase = 'scroll $name';
      for (var k = 0; k < 12; k++) {
        await tester.drag(
          find.byType(ListView).last,
          Offset(0, k < 6 ? -37 : 37),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      _phase = 'drag $name';
      final r = tester.getRect(find.byType(RangeSlider).first);
      final g = await tester.startGesture(
        Offset(r.left + r.width * 0.6, r.center.dy),
      );
      for (var i = 0; i < 20; i++) {
        await g.moveBy(const Offset(-8, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 4));
    expect(_orphans, isEmpty);
  });
}
