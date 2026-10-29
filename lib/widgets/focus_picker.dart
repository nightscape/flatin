import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/word_focus.dart';
import '../providers/fsrs_provider.dart';

/// Picks the word group of the next start; a group without words in the
/// course range is shown but cannot be picked. The held [value] is always
/// listed, also when a narrower course range has dropped its type.
class FocusPicker extends ConsumerWidget {
  const FocusPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.offersBaseForms = false,
  });

  final WordFocus value;
  final ValueChanged<WordFocus> onChanged;

  /// Only the noun and verb practice can ask base forms alone.
  final bool offersBaseForms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => FlutterI18n.translate(context, key);
    final (focuses, practicable) = switch ((
      ref.watch(wordFocusesProvider),
      ref.watch(practicableItemsByTypeProvider),
    )) {
      (AsyncData(value: final f), AsyncData(value: final p)) => (f, p),
      (AsyncError(:final error), _) ||
      (_, AsyncError(:final error)) => throw error,
      _ => (null, null),
    };
    if (focuses == null) return const SizedBox.shrink();
    final words = practicable!;
    return Row(
      children: [
        Text(t('focus.label')),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<WordFocus>(
            key: const Key('focus.picker'),
            isExpanded: true,
            value: value,
            onChanged: (focus) => onChanged(focus!),
            items: [
              for (final focus in {
                ...focuses,
                if (offersBaseForms) const BaseForms(),
                value,
              })
                DropdownMenuItem(
                  key: Key('focus.option.${focus.id}'),
                  value: focus,
                  enabled: focus.hasWords(words),
                  child: Text(
                    focus.hasWords(words)
                        ? _label(t, focus)
                        : '${_label(t, focus)} – ${t('focus.empty')}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _label(String Function(String) t, WordFocus focus) =>
      switch (focus) {
        AllWords() => t('focus.all'),
        FileFocus(:final dataFileId) => t('focus.$dataFileId'),
        IrregularVerbs() => t('focus.irregular'),
        BaseForms() => t('focus.baseForms'),
        TypeFocus(:final display) => display,
      };
}
