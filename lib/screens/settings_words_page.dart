import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lesson_data.dart';
import '../models/course_filter.dart';
import '../models/practice_item.dart';
import '../providers/settings_provider.dart';
import 'course_scope.dart';
import 'settings_widgets.dart';

/// Every word by lesson, with a search; a word the course has not reached is
/// greyed and a tap practises it anyway.
class SettingsWordsPage extends StatefulWidget {
  const SettingsWordsPage({super.key});

  @override
  State<SettingsWordsPage> createState() => _SettingsWordsPageState();
}

class _SettingsWordsPageState extends State<SettingsWordsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      titleKey: const Key('settings.words.title'),
      title: FlutterI18n.translate(context, 'settings.wordsPage'),
      body: CourseScope(
        builder: (context, filter, items) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const Key('words.search'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: FlutterI18n.translate(
                    context,
                    'settings.searchWords',
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(child: _WordList(filter, items, _query)),
          ],
        ),
      ),
    );
  }
}

class _WordList extends ConsumerWidget {
  const _WordList(this.filter, this.items, this.query);

  final CourseFilter filter;
  final List<PracticeItem> items;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byLemma = <String, PracticeItem>{};
    for (final item in items) {
      byLemma.putIfAbsent(item.lemma, () => item);
    }
    final needle = normalizeDiacritics(query.trim()).toLowerCase();

    final rows = <Object>[];
    for (final name in filter.lessons.lessonNames) {
      final matches = [
        for (final lemma in filter.lessons.lessonWords[name]!)
          if (byLemma.containsKey(lemma) &&
              normalizeDiacritics(lemma).toLowerCase().contains(needle))
            byLemma[lemma]!,
      ];
      if (matches.isEmpty) continue;
      rows..add(name)..addAll(matches);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is String) return SectionTitle(row);
        return _wordTile(context, ref, row as PracticeItem);
      },
    );
  }

  Widget _wordTile(BuildContext context, WidgetRef ref, PracticeItem item) {
    final normalized = normalizeDiacritics(item.lemma);
    final gap = filter.wordGap(item);
    return CheckboxListTile(
      key: Key('word.$normalized'),
      dense: true,
      title: Text(
        item.lemma,
        style: TextStyle(color: rowTextColor(context, greyed: gap != null)),
      ),
      subtitle: gap == null ? null : Text(gapText(context, gap)),
      value: filter.wordPracticed(item),
      onChanged: (_) => ref
          .read(settingsProvider.notifier)
          .toggleWord(normalized, inRange: filter.wordInRange(item)),
      activeColor: settingsCheckboxColor,
      checkColor: Colors.black,
    );
  }
}
