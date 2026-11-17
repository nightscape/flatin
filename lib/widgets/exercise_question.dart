import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise.dart';
import '../models/settings.dart' show StemMarking;
import '../providers/fsrs_provider.dart';
import 'form_text.dart';

/// The question of [exercise]. Each Latin word in it is a [FormText] in the
/// learner's stem marking, per exercise; a shown form with a stem split gets
/// its split, and its confirmed mark reviews its stem card. The text around
/// the words is the translated sentence.
class ExerciseQuestion extends ConsumerWidget {
  const ExerciseQuestion(this.exercise, {super.key});

  final Exercise exercise;

  static const questionKey = Key('exercise.question');

  static const _open = '';
  static const _close = '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(stemMarkingProvider);
    final style = Theme.of(context).textTheme.titleLarge;
    final sentence = FlutterI18n.translate(
      context,
      exercise.questionKey,
      translationParams: {
        ...exercise.questionParams,
        ...exercise.languageParam(
          FlutterI18n.currentLocale(context)!.languageCode,
        ),
        for (final name in exercise.formParams) name: '$_open$name$_close',
      },
    );
    final spans = <InlineSpan>[];
    var from = 0;
    for (final m in RegExp('$_open(.+?)$_close').allMatches(sentence)) {
      spans.add(TextSpan(text: sentence.substring(from, m.start)));
      spans.addAll(
        _wordSpans(
          context,
          exercise.questionParams[m.group(1)]!,
          exercise.stemSplits[m.group(1)],
          mode,
          (card, right) => reviewStemCard(ref, card, right),
          style,
        ),
      );
      from = m.end;
    }
    spans.add(TextSpan(text: sentence.substring(from)));
    return KeyedSubtree(
      key: ObjectKey(exercise),
      child: Text.rich(
        TextSpan(children: spans),
        key: questionKey,
        style: style,
      ),
    );
  }

  static final _word = RegExp(r'[\p{L}\p{M}]{2,}', unicode: true);

  // The WidgetSpan already scales its child by the text scaler; FormText must
  // not scale a second time.
  static Iterable<InlineSpan> _wordSpans(
    BuildContext context,
    String text,
    StemSplit? split,
    StemMarking mode,
    void Function(StemCardId, bool) onMark,
    TextStyle? style,
  ) sync* {
    assert(
      split == null || _word.stringMatch(text) == text,
      'the split form "$text" is not one word',
    );
    final unscaled = MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.noScaling);
    var at = 0;
    for (final m in _word.allMatches(text)) {
      yield TextSpan(text: text.substring(at, m.start));
      yield WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: MediaQuery(
          data: unscaled,
          child: FormText(
            text: m[0]!,
            split: split?.stemLength,
            mode: mode,
            onMark: split == null ? null : (right) => onMark(split.card, right),
            style: style,
          ),
        ),
      );
      at = m.end;
    }
    yield TextSpan(text: text.substring(at));
  }
}
