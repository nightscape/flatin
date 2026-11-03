import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/data/esel_steps.dart';
import 'package:latin_practice/models/practice_item.dart';
import 'package:latin_practice/widgets/esel_panel.dart';

import 'support/esel_render.dart';
import 'support/key_echo_i18n.dart';
import 'support/trace_fixtures.dart';

const _nouns = 'lib/data/latin_nouns.yaml';
const _verbs = 'lib/data/latin_verbs.yaml';

String _row(String kind, String status, String shown) =>
    '${keyEcho('esel.kind.$kind.letter')} ${keyEcho('esel.kind.$kind.name')} '
    '| $status | $shown';

const _show = '[esel.show]';
final _noRule = keyEcho('esel.noRule');
final _absent = keyEcho('esel.absentLabel');
String _absentOf(String kind) => '$_absent / ${keyEcho('esel.absent.$kind')}';

typedef _Case = ({
  String name,
  Future<PracticeItem> Function() item,
  String formKey,
  String wrong,
  List<String> pinned,
  List<String> missing,
});

final _dominorum = (
  name: 'dominorum',
  item: () => loadItem(_nouns, 'dominus'),
  formKey: 'gen.pl',
  wrong: 'dominis',
  pinned: [
    _row('stamm', 'done', 'domin-'),
    _row('endung', 'done', '-ōrum'),
    _row('lautregel', 'pending', _show),
    _row(
      'lautregel',
      'open',
      '${keyEcho('esel.question.lautregel', {'label': 'Genitiv Plural'})}'
          ' | Optionen: $_noRule ; ${keyEcho('esel.soundChanges')} | $_show',
    ),
    _row('lautregel', 'done', _noRule),
  ],
  missing: <String>[],
);
final _amo = (
  name: 'amo',
  item: () => loadItem(_verbs, 'amāre'),
  formKey: 'ind.praes.akt.1.sg',
  wrong: 'amat',
  pinned: [
    _row('lautregel', 'pending', _show),
    _row(
      'lautregel',
      'open',
      '${keyEcho('esel.question.lautregel', {'label': 'Präsens: 1. Person Singular'})}'
          ' | Optionen: $_noRule ; ā fällt vor Vokal aus | $_show',
    ),
    _row('lautregel', 'done', 'ā fällt vor Vokal aus'),
  ],
  missing: <String>[],
);
final _amatusEssem = (
  name: 'amatus_essem',
  item: () => loadItem(_verbs, 'amāre'),
  formKey: 'konj.plusq.pass.1.sg',
  wrong: 'zzz',
  pinned: [
    _row('stamm', 'done (gestrichelt)', _absentOf('stamm')),
    _row('endung', 'done (gestrichelt)', _absentOf('endung')),
    _row('verbinden', 'pending', _show),
    _row(
      'verbinden',
      'open',
      '${keyEcho('esel.question.verbinden', {'label': 'Konjunktiv Plusquamperfekt Passiv: 1. Person Singular'})}'
          ' | Optionen: amātus + eram ; amātus + essem ; amātus + sim | $_show',
    ),
    _row('verbinden', 'done', 'amātus + essem'),
  ],
  missing: <String>[],
);
final _possem = (
  name: 'possem',
  item: () => loadItem(_verbs, 'posse'),
  formKey: 'konj.impf.akt.1.sg',
  wrong: 'zzz',
  pinned: [_row('stamm', 'done', 'pos-'), _row('endung', 'done', '-sem')],
  missing: [keyEcho('esel.kind.merken.name')],
);
final _dic = (
  name: 'dic',
  item: () => loadItem(_verbs, 'dīcere'),
  formKey: 'imp.praes.akt.2.sg',
  wrong: 'zzz',
  pinned: [
    _row(
      'merken',
      'done',
      '${keyEcho('esel.question.merken', {'label': 'Imperativ Präsens: 2. Person Singular'})}'
          ' / ${keyEcho('esel.answer.merken', {'form': 'dīc'})} / ~dīce~',
    ),
  ],
  missing: <String>[],
);
final _issem = (
  name: 'issem',
  item: () => loadItem(_verbs, 'īre'),
  formKey: 'konj.plusq.akt.1.sg',
  wrong: 'zzz',
  pinned: [
    _row(
      'merken',
      'done',
      '${keyEcho('esel.question.merken', {'label': 'Konjunktiv Plusquamperfekt: 1. Person Singular'})}'
          ' / ${keyEcho('esel.answer.merken', {'form': 'īssem'})} / ~iissem~',
    ),
  ],
  missing: <String>[],
);
final _fortioris = (
  name: 'fortioris',
  item: () => loadItem(_nouns, 'fortis'),
  formKey: 'gen.sg.m.komp',
  wrong: 'zzz',
  pinned: [
    _row('stamm', 'done', 'forti-'),
    _row('endung', 'done', '-ōris (Komparativendung)'),
  ],
  missing: <String>[],
);
final _given = (
  name: 'given',
  item: () async => givenItem(),
  formKey: 'ind.perf.akt.1.sg',
  wrong: 'zzz',
  pinned: [
    _row('stamm', 'done (gestrichelt)', _absentOf('stamm')),
    _row('endung', 'done (gestrichelt)', _absentOf('endung')),
    _row('lautregel', 'done (gestrichelt)', _absentOf('lautregel')),
    _row(
      'merken',
      'done',
      '${keyEcho('esel.question.given', {'label': 'Perfekt: 1. Person Singular', 'result': 'abiī'})} / abiī',
    ),
  ],
  missing: <String>[],
);
final _dictionaryForm = (
  name: 'dictionary_form',
  item: () => loadItem(_nouns, 'rēx'),
  formKey: 'nom.sg',
  wrong: 'zzz',
  pinned: [
    _row('stamm', 'done (gestrichelt)', _absentOf('stamm')),
    _row(
      'merken',
      'done',
      '${keyEcho('esel.question.given', {'label': 'Nominativ Singular', 'result': 'rēx'})}'
          ' / ${keyEcho('esel.dictionaryForm')}',
    ),
  ],
  missing: <String>[],
);

final List<_Case> _all = [
  _dominorum,
  _amo,
  _amatusEssem,
  _possem,
  _dic,
  _issem,
  _fortioris,
  _given,
  _dictionaryForm,
];

String _scope(_Case c) => 'esel.${c.formKey}';

/// Pumps [c], then taps Zeigen on the open step until none is left. Each tap
/// must finish that step and open the next step that has a question.
/// Returns the rendering before and after every tap.
Future<List<String>> _walk(WidgetTester tester, _Case c) async {
  await pumpChecked(tester, await c.item(), {c.formKey: c.wrong});
  final scope = _scope(c);
  final snapshots = ['Start\n${renderSteps(tester, scope)}'];
  while (true) {
    final before = stepRows(tester, scope);
    final index = before.indexWhere((r) => r.status == EselStepStatus.open);
    if (index < 0) break;
    final kind = before[index].step.kind;
    await tester.tap(find.byKey(Key('$scope.${kind.name}.show')));
    await tester.pumpAndSettle();

    final after = stepRows(tester, scope);
    expect(after[index].status, EselStepStatus.done, reason: '${c.name} $kind');
    final next = after.indexWhere(
      (r) => r.step.options.isNotEmpty && r.status != EselStepStatus.done,
    );
    expect(
      after
          .where((r) => r.status == EselStepStatus.open)
          .map((r) => r.step.kind),
      next < 0 ? isEmpty : [after[next].step.kind],
      reason: '${c.name} after Zeigen on $kind',
    );
    snapshots.add('Zeigen ${kind.name}\n${renderSteps(tester, scope)}');
  }
  return snapshots;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final c in _all) {
    testWidgets('${c.name}: rendered steps and Zeigen walk', (tester) async {
      final snapshots = await _walk(tester, c);
      final lines = snapshots.expand((s) => s.split('\n')).toList();
      expect(lines, containsAll(c.pinned), reason: c.name);
      for (final text in c.missing) {
        expect(
          lines.where((line) => line.contains(text)),
          isEmpty,
          reason: '${c.name} shows "$text"',
        );
      }
      expectGolden(c.name, snapshots.join('\n'));
    });
  }

  for (final c in [_dic, _issem]) {
    testWidgets('${c.name}: Merken is done from the start, without options', (
      tester,
    ) async {
      await pumpChecked(tester, await c.item(), {c.formKey: c.wrong});
      final merken = stepRow(_scope(c), EselKind.merken);
      expect(
        find.descendant(of: merken, matching: find.byType(ButtonStyleButton)),
        findsNothing,
      );
      expect(stepRows(tester, _scope(c)).last.status, EselStepStatus.done);
      expect(renderSteps(tester, _scope(c)), contains(c.pinned.single));
    });
  }

  for (final c in [_dominorum, _dic]) {
    testWidgets('${c.name}: classification shows all steps done', (
      tester,
    ) async {
      await pumpClassified(tester, await c.item(), c.formKey);
      final rows = stepRows(tester, 'esel.classification');
      expect(rows, isNotEmpty);
      expect(rows.map((r) => r.status).toSet(), {EselStepStatus.done});
      expect(
        find.descendant(
          of: find.byType(EselStaticSteps),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsNothing,
      );
      final rendered = renderSteps(tester, 'esel.classification');
      expect(rendered, isNot(contains('Optionen')));
      expect(rendered, isNot(contains(_show)));
      expectGolden('classification_${c.name}', rendered);
    });
  }

  testWidgets('dic: the static panel gives the reason, not the question', (
    tester,
  ) async {
    await pumpClassified(tester, await _dic.item(), _dic.formKey);
    final rendered = renderSteps(tester, 'esel.classification');
    // The form and its regular twin are vocabulary data, not UI text.
    expect(
      rendered,
      contains(
        '${keyEcho('esel.kind.merken.letter')} '
        '${keyEcho('esel.kind.merken.name')} | done | '
        '${keyEcho('esel.answer.merken', {'form': 'dīc'})} / ~dīce~',
      ),
    );
    expect(rendered, isNot(contains('esel.question.')));
  });
}
