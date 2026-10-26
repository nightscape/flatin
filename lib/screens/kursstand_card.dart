import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/curriculum.dart';
import '../data/lesson_data.dart';
import '../data/practice_data.dart';
import '../models/course_filter.dart';
import '../models/lesson_range.dart';
import '../models/practice_item.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import 'course_scope.dart';

const _wordsLabel = TextStyle(
  color: Color(0xFF8A6D1A),
  fontSize: 11,
  fontWeight: FontWeight.w700,
);
const _grammarLabel = TextStyle(
  color: terracottaDark,
  fontSize: 11,
  fontWeight: FontWeight.w700,
);

/// The course position: histograms and sliders choose the lessons, the list
/// below them flips single words and grammar topics against that choice.
class KursstandCard extends ConsumerStatefulWidget {
  const KursstandCard({super.key, required this.filter, required this.items});

  final CourseFilter filter;
  final List<PracticeItem> items;

  @override
  ConsumerState<KursstandCard> createState() => _KursstandCardState();
}

class _KursstandCardState extends ConsumerState<KursstandCard> {
  final _scroll = ScrollController();
  late final _lessons = [...widget.filter.lessons.lessonNumbers, laterLesson];
  late final _blocks = {for (final l in _lessons) l: GlobalKey()};
  late final Future<Map<String, FormMetadata>> _metadata = ref
      .read(dataLanguageProvider.future)
      .then(
        (language) async => {
          for (final id in ['nouns', 'verbs'])
            id: await getFormMetadata(
              'lib/data/latin_$id.yaml',
              language: language,
            ),
        },
      );

  CourseFilter get _filter => widget.filter;
  SettingsNotifier get _notifier => ref.read(settingsProvider.notifier);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _stop(int lesson) => lesson == laterLesson
      ? FlutterI18n.translate(context, 'settings.kursstand.later')
      : 'L$lesson';

  String _tr(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(
        context,
        'settings.kursstand.$key',
        translationParams: params,
      );

  void _reveal(int lesson, {required bool start}) {
    final target = start
        ? _lessons.firstWhere((l) => l >= lesson)
        : _lessons.lastWhere((l) => l <= lesson);
    _scroll.position.ensureVisible(
      _blocks[target]!.currentContext!.findRenderObject()!,
      duration: const Duration(milliseconds: 150),
      alignmentPolicy: start
          ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
          : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  void _move(
    LessonRange old,
    LessonRange next,
    Future<void> Function(LessonRange) set,
  ) {
    set(next);
    final movedStart = next.from != old.from;
    _reveal(movedStart ? next.from : next.to, start: movedStart);
  }

  /// The words never reach "Später", though their slider and histogram share
  /// the grammar scale.
  void _moveWords(LessonRange next) => _move(
    _filter.settings.courseWords,
    LessonRange(min(next.from, lastLesson), min(next.to, lastLesson)),
    _notifier.setWordRange,
  );

  void _moveGrammar(LessonRange next) =>
      _move(_filter.settings.courseGrammar, next, _notifier.setGrammarRange);

  /// A tap on a grammar bar while linked moves the words, which the grammar
  /// follows.
  void _tapGrammarBar(int lesson) {
    final settings = _filter.settings;
    if (settings.grammarFollowsWords) {
      _moveWords(_nearest(settings.courseWords, lesson));
    } else {
      _moveGrammar(_nearest(settings.courseGrammar, lesson));
    }
  }

  /// The range with the handle nearer to [lesson] moved onto it.
  LessonRange _nearest(LessonRange r, int lesson) {
    final moveStart =
        lesson < r.from || (lesson <= r.to && lesson - r.from <= r.to - lesson);
    return moveStart ? LessonRange(lesson, r.to) : LessonRange(r.from, lesson);
  }

  /// The words a lesson introduces; a word listed twice or again in a later
  /// lesson belongs to its first.
  List<String> _wordsOf(String name) => {
    for (final w in _filter.lessons.lessonWords[name]!)
      if (_filter.lessons.wordToLesson[w] == name) w,
  }.toList();

  bool _wordOn(String lemma, int lesson) => _filter.settings
      .overrideOfWord(lemma)
      .verdict(inRange: _filter.settings.courseWords.contains(lesson));

  Widget _histogram({
    required Key Function(int) keyOf,
    required Map<int, int> total,
    required Map<int, int> off,
    required bool Function(int) inRange,
    required int lessons,
    required String tooltipUnit,
    required void Function(int) onTap,
    required Color color,
    bool down = false,
  }) {
    final peak = total.values.reduce(max);
    const radius = Radius.circular(2);
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          crossAxisAlignment: down
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            for (var l = 1; l <= lessons; l++)
              Expanded(
                child: GestureDetector(
                  key: keyOf(l),
                  onTap: () => onTap(l),
                  child: Tooltip(
                    message: '${_stop(l)}: ${total[l] ?? 0} $tooltipUnit',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: 3 + 44 * (total[l] ?? 0) / peak,
                      decoration: BoxDecoration(
                        color: !inRange(l)
                            ? outlineColor
                            : (off[l] ?? 0) > 0
                            ? color.withAlpha(110)
                            : color,
                        borderRadius: BorderRadius.vertical(
                          top: down ? Radius.zero : radius,
                          bottom: down ? radius : Radius.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _wordsHistogram() {
    final lessons = _filter.lessons;
    final total = <int, int>{}, off = <int, int>{};
    for (final name in lessons.lessonNames) {
      final lesson = lessonNumber(name);
      final words = _wordsOf(name);
      total.update(
        lesson,
        (n) => n + words.length,
        ifAbsent: () => words.length,
      );
      final switchedOff = words.where((w) => !_wordOn(w, lesson)).length;
      off.update(lesson, (n) => n + switchedOff, ifAbsent: () => switchedOff);
    }
    return _histogram(
      keyOf: (l) => Key('kursstand.words.bar.$l'),
      total: total,
      off: off,
      inRange: _filter.settings.courseWords.contains,
      lessons: laterLesson,
      tooltipUnit: _tr('words'),
      onTap: (l) => _moveWords(_nearest(_filter.settings.courseWords, l)),
      color: gold,
    );
  }

  Widget _grammarHistogram(List<CourseTopic> topics) {
    final total = <int, int>{}, off = <int, int>{};
    for (final t in topics) {
      total.update(t.lesson, (n) => n + 1, ifAbsent: () => 1);
      if (!_filter.topicInRange(t)) {
        off.update(t.lesson, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return _histogram(
      keyOf: (l) => Key('kursstand.grammar.bar.$l'),
      total: total,
      off: off,
      inRange: _filter.settings.effectiveGrammar.contains,
      lessons: laterLesson,
      tooltipUnit: _tr('grammar'),
      onTap: _tapGrammarBar,
      color: terracotta,
      down: true,
    );
  }

  Widget _tag(String text, TextStyle style) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: marble.withAlpha(210),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: style),
  );

  Widget _slider(
    String key,
    LessonRange range,
    int max,
    Color color,
    void Function(LessonRange)? onChanged,
  ) => SliderTheme(
    data: SliderTheme.of(context).copyWith(
      disabledActiveTrackColor: color,
      disabledInactiveTrackColor: color.withAlpha(60),
      disabledThumbColor: color,
    ),
    child: RangeSlider(
      key: Key(key),
      activeColor: color,
      inactiveColor: color.withAlpha(60),
      min: 1,
      max: max.toDouble(),
      divisions: max - 1,
      values: RangeValues(range.from.toDouble(), range.to.toDouble()),
      labels: RangeLabels(_stop(range.from), _stop(range.to)),
      onChanged: onChanged == null
          ? null
          : (v) => onChanged(LessonRange(v.start.round(), v.end.round())),
    ),
  );

  Widget _chain(bool linked) => Positioned.fill(
    child: Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        key: const Key('kursstand.chain'),
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        icon: Icon(linked ? Icons.link : Icons.link_off),
        color: linked ? ink : mutedText,
        tooltip: _tr(linked ? 'chainClosed' : 'chainOpen'),
        onPressed: () => _notifier.setGrammarFollowsWords(!linked),
      ),
    ),
  );

  Widget _summary(List<CourseTopic> topics) {
    final settings = _filter.settings;
    final words = _tr('wordCount', {
      'count': '${_filter.summary(widget.items).words}',
    });
    final themes = _tr('topicCount', {
      'count': '${topics.where(_filter.topicInRange).length}',
    });
    String range(LessonRange r) => '${_stop(r.from)} – ${_stop(r.to)}';
    final linked = settings.grammarFollowsWords;
    return Text.rich(
      key: const Key('kursstand.summary'),
      TextSpan(
        style: const TextStyle(fontWeight: FontWeight.w600),
        children: [
          if (linked) TextSpan(text: '${range(settings.courseWords)}:  '),
          TextSpan(
            text: linked ? words : '$words (${range(settings.courseWords)})',
            style: _wordsLabel.copyWith(fontSize: 14),
          ),
          const TextSpan(text: '  ·  '),
          TextSpan(
            text: linked
                ? themes
                : '$themes (${range(settings.effectiveGrammar)})',
            style: _grammarLabel.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _wordChip(String lemma, int lesson) {
    final inRange = _filter.settings.courseWords.contains(lesson);
    final on = _wordOn(lemma, lesson);
    return FilterChip(
      key: Key('kursstand.word.$lemma'),
      label: Text(lemma),
      selected: on,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      selectedColor: gold.withAlpha(inRange ? 150 : 90),
      shape: StadiumBorder(
        side: BorderSide(color: inRange ? gold : outlineColor),
      ),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: inRange || on ? ink : mutedText,
        decoration: inRange && !on ? TextDecoration.lineThrough : null,
      ),
      onSelected: (_) => _notifier.toggleWord(lemma, inRange: inRange),
    );
  }

  Widget _topicChip(CourseTopic t, Map<String, FormMetadata> metadata) {
    final inRange = _filter.settings.effectiveGrammar.contains(t.lesson);
    final on = _filter.topicInRange(t);
    return FilterChip(
      key: Key('kursstand.topic.${t.key}'),
      avatar: Icon(
        t.dataFileId == 'nouns' ? Icons.account_balance : Icons.directions_run,
        size: 16,
        color: inRange || on ? terracottaDark : mutedText,
      ),
      label: Text(t.name(metadata[t.dataFileId]!)),
      selected: on,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      shape: StadiumBorder(
        side: BorderSide(color: inRange ? terracotta : outlineColor),
      ),
      selectedColor: terracotta.withAlpha(inRange ? 70 : 40),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: inRange || on ? ink : mutedText,
        decoration: inRange && !on ? TextDecoration.lineThrough : null,
      ),
      onSelected: (_) => _notifier.toggleTopic(t.key, inRange: inRange),
    );
  }

  Widget _chips(List<Widget> chips) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Wrap(spacing: 6, runSpacing: 6, children: chips),
  );

  Widget _block(
    int lesson,
    List<CourseTopic> topics,
    Map<String, FormMetadata> metadata,
  ) {
    final settings = _filter.settings;
    final lit =
        settings.courseWords.contains(lesson) ||
        settings.effectiveGrammar.contains(lesson);
    final ownTopics = topics.where((t) => t.lesson == lesson).toList();
    return Column(
      key: _blocks[lesson],
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: lit ? gold.withAlpha(60) : sand,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            lesson == laterLesson
                ? _tr('later')
                : _tr('lesson', {'lesson': '$lesson'}),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: lit ? ink : mutedText,
            ),
          ),
        ),
        if (ownTopics.isNotEmpty)
          _chips([for (final t in ownTopics) _topicChip(t, metadata)]),
        for (final name in _filter.lessons.lessonNames)
          if (lessonNumber(name) == lesson)
            _chips([for (final w in _wordsOf(name)) _wordChip(w, lesson)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _metadata,
    builder: (context, snapshot) {
      if (snapshot.hasError) return loadErrorText(context, snapshot.error!);
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return _card(snapshot.data!);
    },
  );

  Widget _card(Map<String, FormMetadata> metadata) {
    final topics = _filter.curriculum.courseTopics;
    final settings = _filter.settings;
    return Card(
      key: const Key('kursstand.card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr('title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                _wordsHistogram(),
                Positioned(
                  top: 0,
                  left: 24,
                  child: _tag(_tr('words'), _wordsLabel),
                ),
              ],
            ),
            Stack(
              children: [
                Column(
                  children: [
                    _slider(
                      'kursstand.words.slider',
                      settings.courseWords,
                      laterLesson,
                      gold,
                      _moveWords,
                    ),
                    _slider(
                      'kursstand.grammar.slider',
                      settings.effectiveGrammar,
                      laterLesson,
                      terracotta,
                      settings.grammarFollowsWords ? null : _moveGrammar,
                    ),
                  ],
                ),
                _chain(settings.grammarFollowsWords),
              ],
            ),
            Stack(
              children: [
                _grammarHistogram(topics),
                Positioned(
                  bottom: 0,
                  left: 24,
                  child: _tag(_tr('grammar'), _grammarLabel),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _summary(topics),
            ),
            SizedBox(
              height: 320,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: outlineColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    children: [
                      for (final l in _lessons) _block(l, topics, metadata),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('kursstand.reset'),
                onPressed: _notifier.clearOverrides,
                child: Text(_tr('reset')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
