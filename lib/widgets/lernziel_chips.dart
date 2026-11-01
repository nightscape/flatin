import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lernziel_chips.dart';
import '../models/lesson_range.dart';
import '../models/settings.dart';
import '../providers/settings_provider.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';

String _later(BuildContext context) =>
    FlutterI18n.translate(context, 'settings.kursstand.later');

Color _colour(bool words) => words ? gold : terracotta;

/// The preset chips of the word row, or else the grammar row, of
/// [settings]; a tap on a preset passes the settings with that range on.
class LernzielChipRow extends StatelessWidget {
  const LernzielChipRow({
    super.key,
    required this.settings,
    required this.bookStarts,
    required this.words,
    required this.onCourse,
  });

  final Settings settings;
  final List<int> bookStarts;
  final bool words;
  final void Function(Settings) onCourse;

  @override
  Widget build(BuildContext context) {
    final range = words ? settings.courseWords : settings.courseGrammar;
    final later = _later(context);
    final row = words ? 'words' : 'grammar';
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final chip in lernzielRow(
          range,
          chipsFor(settings.kursstand, bookStarts),
        ))
          ChoiceChip(
            key: Key(
              'lernziel.$row.${chip.preset == null ? 'custom' : lernzielLabel(chip.preset!, later)}',
            ),
            avatar: chip.preset == null
                ? const Icon(Icons.tune, size: 16, color: ink)
                : null,
            label: Text(lernzielLabel(chip.preset ?? range, later)),
            selected: chip.selected,
            showCheckmark: false,
            selectedColor: _colour(words).withAlpha(words ? 150 : 90),
            side: BorderSide(color: _colour(words)),
            onSelected: (_) {
              if (chip.preset case final preset?) {
                onCourse(chooseLernziel(settings, preset, words: words));
              }
            },
          ),
      ],
    );
  }
}

/// The current Lernziel on the home screen: the word and the grammar range;
/// a tap opens the book view.
class LernzielEntry extends ConsumerWidget {
  const LernzielEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = switch (ref.watch(settingsProvider)) {
      AsyncData(:final value) => value,
      AsyncError(:final error) => throw error,
      _ => null,
    };
    if (settings == null) return const SizedBox.shrink();
    final later = _later(context);
    Widget range(LessonRange r, {required bool words}) => Chip(
      key: Key('home.lernziel.${words ? 'words' : 'grammar'}'),
      label: Text(
        '${FlutterI18n.translate(context, 'lernziel.${words ? 'words' : 'grammar'}')} '
        '${lernzielLabel(r, later)}',
      ),
      backgroundColor: _colour(words).withAlpha(words ? 150 : 90),
      side: BorderSide(color: _colour(words)),
      visualDensity: VisualDensity.compact,
    );
    return Material(
      color: parchment,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('home.lernziel'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(
            children: [
              Text(
                FlutterI18n.translate(context, 'lernziel.title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    range(settings.courseWords, words: true),
                    range(settings.courseGrammar, words: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
