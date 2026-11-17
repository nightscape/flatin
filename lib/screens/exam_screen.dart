import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exam.dart';
import '../data/token_lessons.dart';
import '../models/answer_description.dart';
import '../models/exam_points.dart';
import '../models/exam_units.dart';
import '../models/form_label.dart' show Axes;
import '../models/settings.dart';
import '../providers/exam_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/axis_dropdowns.dart';
import 'word_sheet.dart';

/// One exam pack: the translation in self-check units of the chosen size,
/// then the tasks: a `bestimmen` item with dropdowns is checked by the
/// screen, every other answer by the learner against the solution.
/// The axes of the grammar files, those that list the lemma of an item's
/// token first.
typedef _AxesOf = List<Axes> Function(BestimmenItem item);

class ExamScreen extends ConsumerStatefulWidget {
  final Exam exam;
  const ExamScreen({super.key, required this.exam});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  final _revealed = <String>{};
  final _moreShown = <String>{};

  /// Unit or task key -> true for "hab ich", false for "anders"; a mark is
  /// final, so the points never go down.
  final _marks = <String, bool>{};

  /// Per dropdown item (`task:<id>:<index>`): the picks, the number of wrong
  /// checks, whether it is solved, and whether the last check was wrong.
  final _picks = <String, Map<String, String?>>{};
  final _wrongChecks = <String, int>{};
  final _solved = <String>{};
  final _forfeited = <String>{};
  final _lastWrong = <String>{};
  final _tapped = <String>{};
  int? _queued;

  Exam get exam => widget.exam;

  String _t(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(context, key, translationParams: params);

  late final _clauseOf = {
    for (final s in exam.saetze)
      for (final c in s.teilsaetze)
        for (final id in c.tokens) id: c,
  };

  late final _tokens = {
    for (final s in exam.saetze)
      for (final t in s.tokens) t.id: t,
  };

  @override
  Widget build(BuildContext context) {
    final settings = switch (ref.watch(settingsProvider)) {
      AsyncData(:final value) => value,
      AsyncError(:final error) => throw error,
      _ => null,
    };
    final byFile = switch (ref.watch(examAxesProvider)) {
      AsyncData(:final value) => value,
      AsyncError(:final error) => throw error,
      _ => null,
    };
    final words = switch (ref.watch(examWordsProvider)) {
      AsyncData(:final value) => value,
      AsyncError(:final error) => throw error,
      _ => null,
    };
    if (settings == null || byFile == null || words == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    List<Axes> axes(BestimmenItem i) {
      final own = {
        for (final f
            in words[(_tokens[i.token]! as WordToken).lemma]?.files ??
                const <WordFile>[])
          f.dataFileId,
      };
      return [
        for (final e in byFile.entries)
          if (own.contains(e.key)) e.value,
        for (final e in byFile.entries)
          if (!own.contains(e.key)) e.value,
      ];
    }

    final units = examUnits(exam, settings.uebersetzungseinheit);
    return Scaffold(
      appBar: AppBar(title: Text(exam.titel)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (settings.punkteAnzeige) _points(units, axes),
          Text(
            _t('exam.screen.translation'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final (i, u) in units.indexed) _unit(i, u),
          const SizedBox(height: 16),
          if (exam.aufgaben.isNotEmpty)
            Text(
              _t('exam.screen.tasks'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          for (final t in exam.aufgaben) _task(t, settings, axes),
          const SizedBox(height: 16),
          if (_queued == null)
            ElevatedButton(
              key: const Key('exam.finish'),
              onPressed: () => _finish(units, axes),
              child: Text(_t('exam.screen.finish')),
            )
          else
            Text(
              _t('exam.screen.finished', {'n': '$_queued'}),
              key: const Key('exam.finished'),
            ),
        ],
      ),
    );
  }

  Widget _points(List<ExamUnit> units, _AxesOf axes) {
    final done = units.where((u) => _marks['unit:${u.id}'] == true).length;
    final translation = units.isEmpty
        ? 0
        : exam.punkteUebersetzung * done ~/ units.length;
    final tasks = exam.aufgaben.fold(0, (sum, t) => sum + _earned(t, axes));
    return Text(
      _t('exam.screen.points', {
        'n': '${translation + tasks}',
        'total': '${exam.punkteGesamt}',
      }),
      key: const Key('exam.points'),
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  /// The merkmale of [i] that have a dropdown.
  List<String> _asked(BestimmenItem i, _AxesOf axes) =>
      AnswerDescription.askable(
        axes(i),
        (_tokens[i.token]! as WordToken).analyse.codes,
        i.merkmale,
      );

  /// Whether the task has an item that only the task mark decides.
  bool _hasSelfMarked(ExamTask t, _AxesOf axes) => switch (t) {
    ItemTask(art: ItemArt.bestimmen, :final items) =>
      items.cast<BestimmenItem>().any((i) => _asked(i, axes).isEmpty),
    _ => true,
  };

  int _earned(ExamTask t, _AxesOf axes) {
    final marked = _marks['task:${t.id}'] == true;
    return switch (t) {
      ItemTask(art: ItemArt.bestimmen, :final items) => [
        for (final (j, i) in items.cast<BestimmenItem>().indexed)
          itemPoints(
            i.punkte,
            asked: _asked(i, axes).length,
            selfOk: marked,
            solved: _solved.contains('task:${t.id}:$j'),
            forfeited: _forfeited.contains('task:${t.id}:$j'),
            wrongChecks: _wrongChecks['task:${t.id}:$j'] ?? 0,
          ),
      ].fold(0, (a, b) => a + b),
      _ => marked ? t.punkte : 0,
    };
  }

  Widget _unit(int i, ExamUnit u) {
    final key = 'unit:${u.id}';
    final revealed = _revealed.contains(key);
    final more = _moreShown.contains(key);
    return Card(
      key: Key('exam.unit.$i'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in u.lines) _line(line),
            const SizedBox(height: 8),
            TextField(
              key: Key('exam.unit.$i.input'),
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: _t('exam.screen.yourTranslation'),
              ),
            ),
            const SizedBox(height: 8),
            if (!revealed)
              OutlinedButton(
                key: Key('exam.unit.$i.show'),
                onPressed: () => setState(() => _revealed.add(key)),
                child: Text(_t('exam.screen.showModel')),
              )
            else ...[
              for (final (j, s) in u.segments.indexed) ...[
                Text(
                  s.shown,
                  key: Key('exam.model.$i.$j'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (more)
                  for (final (k, o) in s.others.indexed)
                    Text(o, key: Key('exam.model.$i.$j.other.$k')),
              ],
              if (!more && u.segments.any((s) => s.others.isNotEmpty))
                TextButton(
                  key: Key('exam.unit.$i.more'),
                  onPressed: () => setState(() => _moreShown.add(key)),
                  child: Text(_t('exam.screen.moreVariants')),
                ),
              const SizedBox(height: 4),
              for (final a in u.alignment) _aligned(a),
              const SizedBox(height: 8),
              _markRow(key, 'exam.unit.$i'),
            ],
          ],
        ),
      ),
    );
  }

  /// A punctuation mark joins the word before it, an opening quote the word
  /// after it, and an enclitic the word before it without its hyphen.
  Widget _line(List<ExamToken> tokens) {
    final groups = <List<ExamToken>>[];
    var joinNext = false;
    for (final t in tokens) {
      final joinsBefore =
          !joinNext &&
          groups.isNotEmpty &&
          (t is PunctuationToken && !_opening.contains(t.la) ||
              t.la.startsWith('-'));
      if (joinNext || joinsBefore) {
        groups.last.add(t);
      } else {
        groups.add([t]);
      }
      joinNext = t is PunctuationToken && _opening.contains(t.la);
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final g in groups)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final t in g) _token(t)],
          ),
      ],
    );
  }

  static const _opening = {'„', '(', '‚'};

  Widget _token(ExamToken t) {
    final style = Theme.of(context).textTheme.titleLarge;
    final text = t.la.startsWith('-') ? t.la.substring(1) : t.la;
    return switch (t) {
      PunctuationToken() => Text(
        text,
        key: Key('exam.token.${t.id}'),
        style: style,
      ),
      WordToken() => InkWell(
        key: Key('exam.token.${t.id}'),
        onTap: () => _help(t),
        child: Text(
          text,
          style: style?.copyWith(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
          ),
        ),
      ),
    };
  }

  Widget _aligned(AlignedWords a) {
    final la = [for (final id in a.tokens) _tokens[id]!.la].join(' ');
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: la,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: ' → ${a.de}'),
        ],
      ),
    );
  }

  Widget _markRow(String key, String prefix) => switch (_marks[key]) {
    null => Row(
      children: [
        FilledButton(
          key: Key('$prefix.habIch'),
          onPressed: () => setState(() => _marks[key] = true),
          child: Text(_t('exam.screen.habIch')),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          key: Key('$prefix.anders'),
          onPressed: () => setState(() => _marks[key] = false),
          child: Text(_t('exam.screen.anders')),
        ),
      ],
    ),
    final done => Chip(
      key: Key('$prefix.mark'),
      label: Text(_t(done ? 'exam.screen.done' : 'exam.screen.open')),
    ),
  };

  void _help(WordToken t) {
    setState(() => _tapped.add(t.lemma));
    final hilfe = exam.hilfen.where((h) => h.lemma == t.lemma).firstOrNull;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final meaning =
              hilfe?.de ??
              ref.watch(examWordsProvider).value?[t.lemma]?.meaning;
          final lessons = switch (ref.watch(lessonLookupProvider)) {
            AsyncData(:final value) => value.of(t, _clauseOf[t.id]!),
            AsyncError(:final error) => throw error,
            _ => null,
          };
          return Padding(
            key: const Key('exam.sheet'),
            padding: const EdgeInsets.all(16),
            child: WordSheet(
              spelling: t.la,
              lemma: t.lemma,
              meaning: meaning,
              entry: hilfe?.angabe,
              analysis: _analysis(t.analyse),
              lessons: lessons,
            ),
          );
        },
      ),
    );
  }

  String _code(String field, Object code) => _t('exam.analyse.$field.$code');

  String _analysis(Analyse a) => [
    for (final MapEntry(:key, :value) in a.codes.entries) _code(key, value),
  ].join(', ');

  Widget _task(ExamTask t, Settings settings, _AxesOf axes) {
    final key = 'task:${t.id}';
    final prefix = 'exam.task.${t.id}';
    return Card(
      key: Key(prefix),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.punkteAnzeige
                  ? '${t.titel} (${_t('exam.screen.taskPoints', {'n': '${t.punkte}'})})'
                  : t.titel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(_plain(t.frage)),
            for (final line in _prompts(t)) Text('• $line'),
            if (t case ItemTask(art: ItemArt.bestimmen, :final items))
              for (final (j, i) in items.cast<BestimmenItem>().indexed)
                if (_asked(i, axes).isNotEmpty) _askedItem(t, j, i, axes),
            const SizedBox(height: 8),
            if (!_revealed.contains(key))
              OutlinedButton(
                key: Key('$prefix.show'),
                onPressed: () => setState(() {
                  _revealed.add(key);
                  _forfeit(t, axes);
                }),
                child: Text(_t('exam.screen.showSolution')),
              )
            else ...[
              for (final (k, line) in _solution(t).indexed)
                Text(line, key: Key('$prefix.solution.$k')),
              if (_hasSelfMarked(t, axes)) ...[
                const SizedBox(height: 8),
                _markRow(key, prefix),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _askedItem(ExamTask t, int j, BestimmenItem i, _AxesOf axes) {
    final word = _tokens[i.token]!;
    final description = AnswerDescription.ofToken(
      axes(i),
      (word as WordToken).analyse.codes,
      i.merkmale,
    );
    final k = 'task:${t.id}:$j';
    final prefix = 'exam.task.${t.id}.item.$j';
    final picks =
        _picks[k] ?? {for (final s in description.selectors.sections) s: null};
    final solved = _solved.contains(k);
    final locked = solved || _forfeited.contains(k);
    final wrong = _lastWrong.contains(k);
    return Container(
      key: Key(prefix),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: solved
              ? Colors.green
              : wrong
              ? Colors.red
              : Theme.of(context).dividerColor,
          width: solved || wrong ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(word.la, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          AxisDropdowns(
            selectors: description.selectors,
            keyPrefix: prefix,
            picks: picks,
            isMobile: MediaQuery.of(context).size.width < 600,
            onPick: locked
                ? null
                : (section, value) => setState(() {
                    _picks[k] = {...picks, section: value};
                    _lastWrong.remove(k);
                  }),
          ),
          if (!locked) ...[
            const SizedBox(height: 8),
            FilledButton(
              key: Key('$prefix.check'),
              onPressed: description.selectors.isComplete(picks)
                  ? () => _check(k, description, picks)
                  : null,
              child: Text(_t('wordClassification.check')),
            ),
          ],
          if (solved || wrong)
            Text(
              _t(
                solved ? 'wordClassification.correct' : 'exam.screen.tryAgain',
              ),
              key: Key('$prefix.feedback'),
            ),
        ],
      ),
    );
  }

  /// A dropdown item still unsolved when its task is revealed earns nothing:
  /// copying the shown answer is no retry.
  void _forfeit(ExamTask t, _AxesOf axes) {
    if (t case ItemTask(art: ItemArt.bestimmen, :final items)) {
      for (final (j, i) in items.cast<BestimmenItem>().indexed) {
        final k = 'task:${t.id}:$j';
        if (_asked(i, axes).isNotEmpty && !_solved.contains(k)) {
          _forfeited.add(k);
        }
      }
    }
  }

  void _check(String k, AnswerDescription d, Map<String, String?> picks) =>
      setState(() {
        if (d.accepts(picks)) {
          _solved.add(k);
          _lastWrong.remove(k);
        } else {
          _wrongChecks[k] = (_wrongChecks[k] ?? 0) + 1;
          _lastWrong.add(k);
        }
      });

  String _plain(String s) => s.replaceAll('`', '');

  List<String> _prompts(ExamTask t) => switch (t) {
    OrdnenTask(:final elemente) => [
      ...elemente,
    ]..shuffle(Random(t.id.hashCode)),
    ItemTask(art: ItemArt.wissenMc, :final items) => [
      for (final i in items.cast<WissenMcItem>()) ...[
        i.frage,
        i.optionen.join(' / '),
      ],
    ],
    _ => const [],
  };

  /// The answer from the annotation where the pack gives one, else the lines
  /// of the PDF solution.
  List<String> _solution(ExamTask t) => switch (t) {
    ItemTask(art: ItemArt.bestimmen, :final items) => [
      for (final i in items.cast<BestimmenItem>()) _bestimmt(i),
    ],
    ItemTask(art: ItemArt.stammformen, :final items) => [
      for (final i in items.cast<StammformenItem>()) i.stammformen.join(' – '),
    ],
    ItemTask(art: ItemArt.vokabel, :final items) => [
      for (final i in items.cast<VokabelItem>())
        '${i.la}: ${expand(i.de.first).first}',
    ],
    _ => [for (final line in t.loesung) _plain(line)],
  };

  String _bestimmt(BestimmenItem i) {
    final t = _tokens[i.token]!;
    if (t is! WordToken) {
      assert(i.merkmale.isEmpty, 'a punctuation mark has no features');
      return t.la;
    }
    final codes = t.analyse.codes;
    final features = [
      for (final m in i.merkmale)
        switch (m) {
          'lemma' => t.lemma,
          'bezug' => _t('exam.solution.bezug', {'word': _tokens[t.bezug]!.la}),
          _ => _code(m, codes[m]!),
        },
    ];
    return '${t.la}: ${features.join(', ')}';
  }

  /// A marked-"anders" item, or a dropdown item that had a wrong check.
  bool _needsHelp(ItemTask t, int j, TaskItem i, _AxesOf axes) =>
      (_marks['task:${t.id}'] == false &&
          (i is! BestimmenItem || _asked(i, axes).isEmpty)) ||
      (_wrongChecks['task:${t.id}:$j'] ?? 0) > 0 ||
      _forfeited.contains('task:${t.id}:$j');

  Future<void> _finish(List<ExamUnit> units, _AxesOf axes) async {
    final helped = {
      ..._tapped,
      for (final u in units)
        if (_marks['unit:${u.id}'] == false)
          for (final line in u.lines)
            for (final t in line)
              if (t is WordToken) t.lemma,
      for (final t in exam.aufgaben.whereType<ItemTask>())
        for (final (j, i) in t.items.indexed)
          if (_needsHelp(t, j, i, axes))
            ?switch (i) {
              BestimmenItem(:final token) => switch (_tokens[token]!) {
                WordToken(:final lemma) => lemma,
                PunctuationToken() => null,
              },
              StammformenItem(:final lemma) => lemma,
              VokabelItem(:final la) => la,
              _ => null,
            },
    };
    final queued = await queueHelpedLemmas(ref, helped);
    if (mounted) setState(() => _queued = queued);
  }
}
