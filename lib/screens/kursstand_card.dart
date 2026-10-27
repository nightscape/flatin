import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/curriculum.dart';
import '../data/lesson_data.dart';
import '../data/practice_data.dart';
import '../models/course_filter.dart';
import '../models/lesson_range.dart';
import '../models/settings.dart';
import '../models/practice_item.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import 'course_scope.dart';
import 'kursstand_sliders.dart';

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

  void _onCourse(Settings next) {
    final old = _filter.settings;
    _notifier.setCourse(next);
    for (final (before, after) in [
      (old.courseWords, next.courseWords),
      (old.courseGrammar, next.courseGrammar),
    ]) {
      if (before == after) continue;
      final movedStart = after.from != before.from;
      _reveal(movedStart ? after.from : after.to, start: movedStart);
      return;
    }
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

  /// The count and range of the words over the shelf, or of the grammar
  /// topics under it.
  Widget _summary(List<CourseTopic> topics, {required bool words}) {
    final settings = _filter.settings;
    final r = words ? settings.courseWords : settings.courseGrammar;
    final count = words
        ? _tr('wordCount', {'count': '${_filter.summary(widget.items).words}'})
        : _tr('topicCount', {
            'count': '${topics.where(_filter.topicInRange).length}',
          });
    return Text(
      '$count  ·  ${_stop(r.from)} – ${_stop(r.to)}',
      key: Key('kursstand.summary.${words ? 'words' : 'grammar'}'),
      style: (words ? _wordsLabel : _grammarLabel).copyWith(fontSize: 14),
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
    final inRange = _filter.courseReaches(t);
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
        settings.courseGrammar.contains(lesson);
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
            _summary(topics, words: true),
            KursstandSliders(
              settings: settings,
              bookStarts: _filter.lessons.bookStarts,
              onCourse: _onCourse,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _summary(topics, words: false),
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
