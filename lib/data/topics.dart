/// Topics: the bundles that one curriculum entry introduces first.
library;

import 'dart:math';

import '../models/exercise.dart';
import '../models/practice_item.dart';
import 'curriculum.dart';
import 'selection.dart';

const _fileOrder = ['nouns', 'verbs'];
const _verbBundleAxes = ['modus', 'tempus', 'genus_verbi'];

final class Topic {
  /// `<dataFileId>:<lesson>`, e.g. `verbs:23`. In memory only, never stored.
  final String id;
  final String dataFileId;

  /// `laterLesson` for the `later:` entry.
  final int lesson;

  /// In form order, never empty.
  final List<GrammarBundle> bundles;
  final String name;

  Topic({
    required this.dataFileId,
    required this.lesson,
    required this.bundles,
    required this.name,
  }) : id = '$dataFileId:$lesson',
       assert(bundles.isNotEmpty);
}

/// Every topic of [items], in course order: lesson, then data file, then the
/// first form of the topic. Every bundle of [items] is in exactly one topic.
/// [nounTypeDisplays] maps each noun type to the name the learner reads.
List<Topic> topicsOf(
  List<PracticeItem> items,
  Curriculum curriculum, {
  required Map<String, String> nounTypeDisplays,
}) {
  final lessonOf = <(String, GrammarBundle), int>{};
  final formIndexOf = <(String, GrammarBundle), int>{};
  final nameOf = <(String, GrammarBundle), String>{};
  for (final item in items) {
    for (var i = 0; i < item.formOrder.length; i++) {
      final key = (item.dataFileId, bundleOf(item, item.formOrder[i]));
      final lesson = grammarLesson(curriculum, item, item.formOrder[i]);
      lessonOf.update(key, (l) => min(l, lesson), ifAbsent: () => lesson);
      formIndexOf.update(key, (j) => min(j, i), ifAbsent: () => i);
      nameOf.putIfAbsent(
        key,
        () => item.dataFileId == 'nouns'
            ? nounTypeDisplays[key.$2]!
            : [
                for (final axis in _verbBundleAxes)
                  item.formLabels[i].display(axis),
              ].nonNulls.join(' '),
      );
    }
  }

  final grouped = <(String, int), List<(String, GrammarBundle)>>{};
  for (final key in lessonOf.keys) {
    grouped.putIfAbsent((key.$1, lessonOf[key]!), () => []).add(key);
  }
  return [
    for (final entry in grouped.entries)
      () {
        final keys = entry.value
          ..sort((a, b) {
            final byIndex = formIndexOf[a]!.compareTo(formIndexOf[b]!);
            return byIndex != 0 ? byIndex : a.$2.compareTo(b.$2);
          });
        return Topic(
          dataFileId: entry.key.$1,
          lesson: entry.key.$2,
          bundles: [for (final k in keys) k.$2],
          name: [for (final k in keys) nameOf[k]!].join(', '),
        );
      }(),
  ]..sort((a, b) {
    final byLesson = a.lesson.compareTo(b.lesson);
    return byLesson != 0
        ? byLesson
        : _fileOrder
              .indexOf(a.dataFileId)
              .compareTo(_fileOrder.indexOf(b.dataFileId));
  });
}

/// The bundles of [topic] the course offers now; empty = topic not listed.
Set<GrammarBundle> offeredBundles(Topic topic, Set<GrammarBundle> unlocked) =>
    topic.bundles.toSet().intersection(unlocked);
