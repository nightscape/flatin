import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/token_lessons.dart';
import '../providers/exam_provider.dart';
import '../providers/lookup_provider.dart';
import 'word_sheet.dart';

/// A text field and, for the spelling typed, one sheet per reading of it.
class LookupScreen extends ConsumerStatefulWidget {
  const LookupScreen({super.key});

  @override
  ConsumerState<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends ConsumerState<LookupScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = FlutterI18n.translate;
    return Scaffold(
      appBar: AppBar(title: Text(t(context, 'lookup.title'))),
      body: switch ((
        ref.watch(formIndexProvider),
        ref.watch(lessonLookupProvider),
      )) {
        (AsyncData(value: final index), AsyncData(value: final lookup)) =>
          _body(context, index.find(_query), lookup),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => throw error,
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(
    BuildContext context,
    List<WordAnalysis> readings,
    LessonLookup lookup,
  ) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        TextField(
          key: const Key('lookup.field'),
          autofocus: true,
          decoration: InputDecoration(
            hintText: FlutterI18n.translate(context, 'lookup.hint'),
          ),
          onChanged: (text) => setState(() => _query = text),
        ),
        const SizedBox(height: 16),
        if (_query.trim().isNotEmpty && readings.isEmpty)
          Text(
            FlutterI18n.translate(context, 'lookup.notFound'),
            key: const Key('lookup.notFound'),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: readings.length,
            separatorBuilder: (_, _) => const Divider(height: 24),
            itemBuilder: (context, i) {
              final r = readings[i];
              return WordSheet(
                key: Key('lookup.result.$i'),
                spelling: r.spelling,
                lemma: r.lemma,
                note: r.note,
                meaning: r.meaning,
                analysis: r.formName,
                lessons: lookup.lessonsOf(r.wordKey, [r.file], (_) => r.form),
              );
            },
          ),
        ),
      ],
    ),
  );
}
