import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lesson_data.dart';
import '../models/course_filter.dart';
import '../models/lesson_range.dart';
import '../models/practice_item.dart';
import '../providers/settings_provider.dart';

/// The course position: what the class has reached, and what that practises.
class KursstandCard extends ConsumerWidget {
  const KursstandCard({super.key, required this.filter, required this.items});

  final CourseFilter filter;
  final List<PracticeItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = filter.settings;
    final notifier = ref.read(settingsProvider.notifier);
    final summary = filter.summary(items);

    return Card(
      key: const Key('kursstand.card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FlutterI18n.translate(context, 'settings.kursstand.title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            _RangeRow(
              rowKey: 'kursstand.words',
              title: FlutterI18n.translate(context, 'settings.kursstand.words'),
              lessons: filter.lessons,
              range: settings.courseWords,
              max: lastLesson,
              onChanged: notifier.setWordRange,
            ),
            SwitchListTile(
              key: const Key('kursstand.follow'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                FlutterI18n.translate(context, 'settings.kursstand.follow'),
              ),
              value: settings.grammarFollowsWords,
              onChanged: notifier.setGrammarFollowsWords,
            ),
            _RangeRow(
              rowKey: 'kursstand.grammar',
              title: FlutterI18n.translate(
                context,
                'settings.kursstand.grammar',
              ),
              lessons: filter.lessons,
              range: settings.effectiveGrammar,
              max: laterLesson,
              onChanged: settings.grammarFollowsWords
                  ? null
                  : notifier.setGrammarRange,
            ),
            const SizedBox(height: 8),
            Text(
              FlutterI18n.translate(
                context,
                'settings.kursstand.summary',
                translationParams: {
                  'words': '${summary.words}',
                  'nounForms': '${summary.nounForms}',
                  'verbForms': '${summary.verbForms}',
                },
              ),
              key: const Key('kursstand.summary'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('kursstand.reset'),
                onPressed: notifier.clearOverrides,
                child: Text(
                  FlutterI18n.translate(context, 'settings.kursstand.reset'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.rowKey,
    required this.title,
    required this.lessons,
    required this.range,
    required this.max,
    required this.onChanged,
  });

  final String rowKey;
  final String title;
  final LessonData lessons;
  final LessonRange range;
  final int max;
  final void Function(LessonRange)? onChanged;

  String _stop(BuildContext context, int lesson) => lesson == laterLesson
      ? FlutterI18n.translate(context, 'settings.kursstand.later')
      : 'L$lesson';

  String _volume(BuildContext context, int lesson) => ' (${FlutterI18n.translate(context, 'settings.kursstand.volume', translationParams: {'book': '${lessons.bookOf(lesson)}'})})';

  String _label(BuildContext context) {
    final from = range.from, to = range.to;
    final first = _stop(context, from) +
        (from == laterLesson ? '' : _volume(context, from));
    final sameVolume = from == laterLesson ||
        to == laterLesson ||
        lessons.bookOf(from) == lessons.bookOf(to);
    final last = _stop(context, to) + (sameVolume ? '' : _volume(context, to));
    return '$first - $last';
  }

  @override
  Widget build(BuildContext context) {
    final label = _label(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Text(label, key: Key('$rowKey.label')),
            ],
          ),
        ),
        RangeSlider(
          key: Key('$rowKey.slider'),
          min: 1,
          max: max.toDouble(),
          divisions: max - 1,
          values: RangeValues(range.from.toDouble(), range.to.toDouble()),
          labels: RangeLabels(
            _stop(context, range.from),
            _stop(context, range.to),
          ),
          onChanged: onChanged == null
              ? null
              : (v) => onChanged!(LessonRange(v.start.round(), v.end.round())),
        ),
      ],
    );
  }
}
