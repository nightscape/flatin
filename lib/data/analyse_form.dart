import '../models/form_label.dart';
import 'languages/language.dart' show Codes;

/// The key of the form that [analyse] names in a data file with [labels]:
/// the label with the most features whose codes the analysis states, or null
/// when no label fits. Of equal labels the first in file order wins.
///
/// The analysis keys of the language file are the axis ids of the data files,
/// so the labels alone say which keys count: a feature the analysis does not
/// state (degree, adverb) makes its labels unreachable, and a key the data
/// file has no axis for (`wortart`) is ignored.
FormKey? formKeyOfAnalyse(Iterable<FormLabel> labels, Codes analyse) {
  FormLabel? best;
  for (final label in labels) {
    final fits = label.features.entries.every(
      (e) => '${analyse[e.key]}' == e.value,
    );
    if (fits &&
        (best == null || label.features.length > best.features.length)) {
      best = label;
    }
  }
  return best?.key;
}
