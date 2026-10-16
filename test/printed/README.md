# Printed paradigm comparison

Compares the forms the engine derives with a private printed paradigm set.
The data is not in the repo; the test is skipped unless the environment
variable `PRINTED_PARADIGMS` names the YAML file:

    PRINTED_PARADIGMS=<path to the file> flutter test --tags printed --run-skipped

A printed form passes when the engine's shown spelling for exactly its
features is one of the printed spellings (exact string, macrons count).
`printed.dart` holds the one table (`shapeRules`) that maps printed feature
sets to engine keys; a feature set without a rule fails the run.

`allowed.yaml` lists every known difference with a reason, and
`matched_lemmas`, the exact number of printed lemmas that find an item. An
entry that matches nothing any more fails the run. A run writes
`build/printed_report.yaml` in the same layout, reasons empty.

`printed_logic_test.dart` pins the comparison logic with inline data and runs
in every `flutter test`.
