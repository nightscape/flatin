/// The points of one `bestimmen` item. An item with dropdowns ([asked] > 0)
/// earns by the checks alone: all its points when solved at the first check,
/// half after wrong checks, none while unsolved; a wrong check never costs
/// points. An item without dropdowns earns all its points when the learner
/// marks the task done.
int itemPoints(
  int punkte, {
  required int asked,
  required bool selfOk,
  required bool solved,
  required int wrongChecks,
}) {
  if (asked == 0) return selfOk ? punkte : 0;
  if (!solved) return 0;
  return wrongChecks == 0 ? punkte : punkte ~/ 2;
}
