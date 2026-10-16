/// Our forms against a private printed paradigm set; see README.md.
///
/// Skipped unless PRINTED_PARADIGMS names the paradigm file:
///   PRINTED_PARADIGMS=`file` flutter test --tags printed --run-skipped
@Tags(['printed'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'printed.dart';

final _path = Platform.environment['PRINTED_PARADIGMS'];

void main() {
  group(
    'printed paradigms',
    skip: _path == null ? 'set PRINTED_PARADIGMS to run' : null,
    () {
      late List<PrintedLemma> printed;
      late PrintedResult result;
      late Allowed allowed;

      setUpAll(() {
        printed = parsePrinted(File(_path!).readAsStringSync());
        allowed = Allowed.parse(
          File('test/printed/allowed.yaml').readAsStringSync(),
        );
        final ours = engineOf([
          for (final l in printed) l.id,
        ], (path) => File(path).readAsStringSync());
        result = comparePrinted(
          printed: printed,
          engine: ours.items,
          axesByFile: ours.axes,
        );
        File('build/printed_report.yaml')
          ..createSync(recursive: true)
          ..writeAsStringSync(reportYaml(result));
        final byReason = <String, int>{};
        for (final a in [...allowed.diffs, ...allowed.missing]) {
          final kind = a.reason.split(':').first;
          byReason[kind] = (byReason[kind] ?? 0) + 1;
        }
        // ignore: avoid_print
        print(
          'printed: matched ${result.matched.length}, '
          'unmatched ${result.unmatched.length} (${result.unmatched.join(', ')}), '
          'compared ${result.compared}, diffs ${result.diffs.length}, '
          'missing ${result.missing.length}, by reason $byReason',
        );
      });

      test('the recorded number of lemmas match', () {
        expect(result.matched, hasLength(allowed.matchedLemmas));
      });

      test('every printed form is compared', () {
        final matched = result.matched.toSet();
        expect(
          result.compared,
          printed
              .where((l) => matched.contains(l.id))
              .fold<int>(0, (n, l) => n + l.forms.length),
        );
      });

      test('no difference or missing form that allowed.yaml does not list', () {
        expect(
          result.unlisted(allowed).map((f) => f.describe).toList(),
          isEmpty,
        );
      });

      test('allowed.yaml lists nothing that no longer differs', () {
        expect(result.stale(allowed), isEmpty);
      });
    },
  );
}
