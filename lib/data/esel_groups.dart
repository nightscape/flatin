import '../models/practice_item.dart';
import 'esel_steps.dart';

/// Splits [keys], the readings of one spelling, into groups whose ESEL steps
/// give the same answer in every step. Groups and the keys in them follow
/// `item.formOrder`.
List<List<FormKey>> groupReadings(PracticeItem item, Iterable<FormKey> keys) {
  final ordered = keys.toList()
    ..sort((a, b) => item.formOrder.indexOf(a) - item.formOrder.indexOf(b));
  final groups = <String, List<FormKey>>{};
  for (final key in ordered) {
    groups.putIfAbsent(_answers(item, key), () => []).add(key);
  }
  return groups.values.toList();
}

String _answers(PracticeItem item, FormKey key) =>
    eselSteps(item, key).map((step) => step.shownIdentity).join('\u0001');

/// The full label of every reading in [group], joined with " / ".
String groupTitle(PracticeItem item, List<FormKey> group) => group
    .map(
      (key) => describeLabels([item.formLabels[item.formOrder.indexOf(key)]]),
    )
    .join(' / ');
