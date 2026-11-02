import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exam.dart';
import '../models/exam_units.dart';
import '../models/settings.dart';
import '../providers/exam_provider.dart';
import '../providers/settings_provider.dart';

/// One exam pack: the translation in self-check units of the chosen size,
/// then the tasks, each checked by the learner against the solution.
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
  final _tapped = <String>{};
  int? _queued;

  Exam get exam => widget.exam;

  String _t(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(context, key, translationParams: params);

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
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final units = examUnits(exam, settings.uebersetzungseinheit);
    return Scaffold(
      appBar: AppBar(title: Text(exam.titel)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (settings.punkteAnzeige) _points(units),
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
          for (final t in exam.aufgaben) _task(t, settings),
          const SizedBox(height: 16),
          if (_queued == null)
            ElevatedButton(
              key: const Key('exam.finish'),
              onPressed: () => _finish(units),
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

  Widget _points(List<ExamUnit> units) {
    final done = units.where((u) => _marks['unit:${u.id}'] == true).length;
    final translation = units.isEmpty
        ? 0
        : exam.punkteUebersetzung * done ~/ units.length;
    final tasks = exam.aufgaben
        .where((t) => _marks['task:${t.id}'] == true)
        .fold(0, (sum, t) => sum + t.punkte);
    return Text(
      _t('exam.screen.points', {
        'n': '${translation + tasks}',
        'total': '${exam.punkteGesamt}',
      }),
      key: const Key('exam.points'),
      style: Theme.of(context).textTheme.titleMedium,
    );
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
          return Padding(
            key: const Key('exam.sheet'),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.la, style: Theme.of(context).textTheme.headlineSmall),
                Text(_t('exam.sheet.lemma', {'lemma': t.lemma})),
                if (meaning != null)
                  Text(_t('exam.sheet.meaning', {'meaning': meaning})),
                if (hilfe != null)
                  Text(_t('exam.sheet.entry', {'angabe': hilfe.angabe})),
                Text(
                  _t('exam.sheet.analysis', {'analysis': _analysis(t.analyse)}),
                ),
              ],
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

  Widget _task(ExamTask t, Settings settings) {
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
            const SizedBox(height: 8),
            if (!_revealed.contains(key))
              OutlinedButton(
                key: Key('$prefix.show'),
                onPressed: () => setState(() => _revealed.add(key)),
                child: Text(_t('exam.screen.showSolution')),
              )
            else ...[
              for (final (k, line) in _solution(t).indexed)
                Text(line, key: Key('$prefix.solution.$k')),
              const SizedBox(height: 8),
              _markRow(key, prefix),
            ],
          ],
        ),
      ),
    );
  }

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

  Future<void> _finish(List<ExamUnit> units) async {
    final helped = {
      ..._tapped,
      for (final u in units)
        if (_marks['unit:${u.id}'] == false)
          for (final line in u.lines)
            for (final t in line)
              if (t is WordToken) t.lemma,
      for (final t in exam.aufgaben.whereType<ItemTask>())
        if (_marks['task:${t.id}'] == false)
          for (final i in t.items)
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
