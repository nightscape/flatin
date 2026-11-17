import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../data/token_lessons.dart';

/// What the course knows about one word in one form: the spelling, its base
/// word, meaning and form, and the lessons that teach it. A part that is
/// null or empty is not shown.
class WordSheet extends StatelessWidget {
  final String spelling;
  final String lemma;
  final String? meaning;

  /// The dictionary entry an exam gives for the word.
  final String? entry;

  /// The text that names the form.
  final String? analysis;
  final TokenLessons? lessons;

  const WordSheet({
    super.key,
    required this.spelling,
    required this.lemma,
    this.meaning,
    this.entry,
    this.analysis,
    this.lessons,
  });

  @override
  Widget build(BuildContext context) {
    String t(String key, [Map<String, String>? params]) =>
        FlutterI18n.translate(context, key, translationParams: params);

    Widget line(String kind, int lesson, {String? topic}) => Text(
      t('exam.sheet.lesson.$kind', {
        'lesson': '$lesson',
        if (topic != null) 'topic': t('exam.$topic'),
      }),
      key: Key('exam.sheet.lesson.${topic ?? kind}.$lesson'),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(spelling, style: Theme.of(context).textTheme.headlineSmall),
        Text(t('exam.sheet.lemma', {'lemma': lemma})),
        if (meaning case final m? when m.isNotEmpty)
          Text(t('exam.sheet.meaning', {'meaning': m})),
        if (entry case final e? when e.isNotEmpty)
          Text(t('exam.sheet.entry', {'angabe': e})),
        if (analysis case final a? when a.isNotEmpty)
          Text(t('exam.sheet.analysis', {'analysis': a})),
        if (lessons case final l?) ...[
          for (final n in l.word) line('word', n),
          for (final n in l.typeAndForm) line('typeAndForm', n),
          for (final n in l.type) line('type', n),
          for (final n in l.form) line('form', n),
          for (final MapEntry(:key, :value) in l.syntax.entries)
            line('syntax', value, topic: key),
        ],
      ],
    );
  }
}
