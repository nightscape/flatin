import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import 'course_scope.dart';
import 'kursstand_card.dart';
import 'settings_grammar_page.dart';
import 'settings_input_page.dart';
import 'settings_widgets.dart';
import 'settings_words_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      titleKey: const Key('settings.title'),
      title: FlutterI18n.translate(context, 'settings.title'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CourseScope(
            builder: (context, filter, items) => Column(
              key: const Key('settings.section.kursstand'),
              children: [KursstandCard(filter: filter, items: items)],
            ),
          ),
          const SizedBox(height: 16),
          _tile(context, 'words', 'settings.wordsPage',
              const SettingsWordsPage()),
          _tile(context, 'nouns', 'settings.nouns',
              const SettingsGrammarPage(dataFileId: 'nouns')),
          _tile(context, 'verbs', 'settings.verbs',
              const SettingsGrammarPage(dataFileId: 'verbs')),
          _tile(context, 'input', 'settings.inputPage',
              const SettingsInputPage()),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String id, String titleKey, Widget page) {
    return ListTile(
      key: Key('settings.tile.$id'),
      title: Text(FlutterI18n.translate(context, titleKey)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      ),
    );
  }
}
