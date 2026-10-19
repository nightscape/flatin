import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/distractor_strategy.dart';
import '../models/input_strategy.dart';
import '../providers/settings_provider.dart';
import 'course_scope.dart';
import 'settings_widgets.dart';

/// How the answers are typed, per data file.
class SettingsInputPage extends ConsumerWidget {
  const SettingsInputPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return SettingsPage(
      titleKey: const Key('settings.input.title'),
      title: FlutterI18n.translate(context, 'settings.inputPage'),
      body: settings.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => loadErrorText(context, error),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final id in const ['nouns', 'verbs']) ...[
              SectionTitle(FlutterI18n.translate(context, 'settings.$id')),
              Text(FlutterI18n.translate(context, 'settings.inputMode')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: Key('input.$id'),
                isExpanded: true,
                value: settings.getInputStrategyId(id),
                items: [
                  for (final s in InputStrategy.all)
                    DropdownMenuItem(value: s.id, child: Text(s.displayName)),
                ],
                onChanged: (value) => ref
                    .read(settingsProvider.notifier)
                    .setInputStrategy(id, value!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(FlutterI18n.translate(context, 'settings.distractorMode')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('input.distractors'),
              isExpanded: true,
              initialValue: settings.distractorStrategyId,
              items: [
                for (final s in distractorStrategies)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      FlutterI18n.translate(
                        context,
                        'settings.distractors.${s.id}',
                      ),
                    ),
                  ),
              ],
              onChanged: (value) => ref
                  .read(settingsProvider.notifier)
                  .setDistractorStrategy(value!),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
