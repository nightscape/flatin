import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../theme.dart';
import 'kursstand_sheet.dart';

/// The lesson the class has reached; a tap opens the sheet that moves it.
class KursstandChip extends ConsumerWidget {
  const KursstandChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kursstand = switch (ref.watch(settingsProvider)) {
      AsyncData(:final value) => value.kursstand,
      AsyncError(:final error) => throw error,
      _ => null,
    };
    if (kursstand == null) return const SizedBox.shrink();
    return Tooltip(
      message: FlutterI18n.translate(
        context,
        'kursstand.chip',
        translationParams: {'lesson': '$kursstand'},
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          key: const Key('home.kursstand'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => showKursstandSheet(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
            decoration: BoxDecoration(
              color: terracottaDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: parchment, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book, color: parchment, size: 20),
                const SizedBox(width: 6),
                Text(
                  '$kursstand',
                  style: const TextStyle(
                    color: parchment,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
