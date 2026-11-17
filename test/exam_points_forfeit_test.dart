import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/models/exam_points.dart';

typedef _Checks = ({
  int punkte,
  int asked,
  bool selfOk,
  bool solved,
  int wrongChecks,
});

/// Any check history of a dropdown item; the first is solved at the first
/// check.
Iterable<_Checks> _drawChecks(Random rng, int count) sync* {
  yield (punkte: 4, asked: 1, selfOk: true, solved: true, wrongChecks: 0);
  for (var n = 1; n < count; n++) {
    yield (
      punkte: rng.nextInt(10),
      asked: 1 + rng.nextInt(4),
      selfOk: rng.nextBool(),
      solved: rng.nextBool(),
      wrongChecks: rng.nextInt(4),
    );
  }
}

void main() {
  test('a forfeited dropdown item earns nothing, whatever its checks', () {
    for (final c in _drawChecks(Random(0), 500)) {
      expect(
        itemPoints(
          c.punkte,
          asked: c.asked,
          selfOk: c.selfOk,
          solved: c.solved,
          forfeited: true,
          wrongChecks: c.wrongChecks,
        ),
        0,
        reason: '$c',
      );
    }
  });
}
