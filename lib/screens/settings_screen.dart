import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rewards.dart';
import '../providers/settings_provider.dart';
import 'course_scope.dart';
import 'kursstand_card.dart';
import 'settings_grammar_page.dart';
import 'settings_input_page.dart';
import 'settings_widgets.dart';
import 'settings_words_page.dart';

class _MacronSwitch extends ConsumerWidget {
  const _MacronSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(settingsProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const SizedBox.shrink(),
          error: (error, _) => loadErrorText(context, error),
          data: (settings) => SwitchListTile(
            key: const Key('settings.avoidMacronTwins'),
            title: Text(
              FlutterI18n.translate(context, 'settings.avoidMacronTwins'),
            ),
            value: settings.avoidMacronTwins,
            onChanged: ref.read(settingsProvider.notifier).setAvoidMacronTwins,
          ),
        );
  }
}

class _RewardSection extends ConsumerWidget {
  const _RewardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);
    String tr(String id) =>
        FlutterI18n.translate(context, 'settings.reward.$id');
    return ref
        .watch(settingsProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => loadErrorText(context, error),
          data: (settings) => Column(
            key: const Key('settings.section.reward'),
            children: [
              SectionTitle(tr('title')),
              for (final id in switchableRewardIds)
                SwitchListTile(
                  key: Key('settings.reward.$id'),
                  title: Text(tr(id)),
                  value: settings.isRewardEnabled(id),
                  onChanged: (_) => notifier.toggleReward(id),
                ),
              SwitchListTile(
                key: const Key('settings.reward.animation'),
                title: Text(tr('animation')),
                value: settings.rewardAnimation,
                onChanged: notifier.setRewardAnimation,
              ),
            ],
          ),
        );
  }
}

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
          _tile(
            context,
            'words',
            'settings.wordsPage',
            const SettingsWordsPage(),
          ),
          _tile(
            context,
            'nouns',
            'settings.nouns',
            const SettingsGrammarPage(dataFileId: 'nouns'),
          ),
          _tile(
            context,
            'verbs',
            'settings.verbs',
            const SettingsGrammarPage(dataFileId: 'verbs'),
          ),
          _tile(
            context,
            'input',
            'settings.inputPage',
            const SettingsInputPage(),
          ),
          const _MacronSwitch(),
          const _RewardSection(),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String id, String titleKey, Widget page) {
    return ListTile(
      key: Key('settings.tile.$id'),
      title: Text(FlutterI18n.translate(context, titleKey)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }
}
