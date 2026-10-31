import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lesson_data.dart' show lastLesson;
import '../providers/settings_provider.dart';

Future<void> showKursstandSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const KursstandSheet(),
    );

/// Moves the Kursstand: one tap to the next lesson, or any lesson from the
/// picker. Each choice closes the sheet.
class KursstandSheet extends ConsumerWidget {
  const KursstandSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kursstand = ref.watch(settingsProvider).requireValue.kursstand;
    void choose(int lesson) {
      if (lesson != kursstand) {
        ref.read(settingsProvider.notifier).setKursstand(lesson);
      }
      Navigator.of(context).pop();
    }

    String lessonText(String key, int lesson) => FlutterI18n.translate(
      context,
      key,
      translationParams: {'lesson': '$lesson'},
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              FlutterI18n.translate(context, 'kursstand.title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (kursstand < lastLesson) ...[
              FilledButton(
                key: const Key('kursstand.next'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  textStyle: Theme.of(context).textTheme.titleLarge,
                ),
                onPressed: () => choose(kursstand + 1),
                child: Text(lessonText('kursstand.next', kursstand + 1)),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(FlutterI18n.translate(context, 'kursstand.pick')),
                ),
                DropdownButton<int>(
                  key: const Key('kursstand.picker'),
                  value: kursstand,
                  items: [
                    for (var lesson = 1; lesson <= lastLesson; lesson++)
                      DropdownMenuItem(
                        value: lesson,
                        child: Text(lessonText('kursstand.lesson', lesson)),
                      ),
                  ],
                  onChanged: (lesson) => choose(lesson!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
