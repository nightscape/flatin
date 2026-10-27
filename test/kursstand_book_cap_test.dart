// Property: no book opens wider than [shelfMaxCell] per lesson. On a track
// too wide for that, the room a full book cannot take goes to the other
// books, the closed ones too, and the row stays centred on the track.
import 'package:flutter_test/flutter_test.dart';
import 'package:latin_practice/widgets/kursstand_shelf.dart';

void main() {
  const starts = [1, 21];

  test('a narrow track gives each book its share of the free room', () {
    final scale = BookScale(starts, [1, 0.3], 0, 300);
    expect(scale.widths[0] - 22, moreOrLessEquals(234 / 1.3));
    expect(scale.widths[1] - 22, moreOrLessEquals(234 * 0.3 / 1.3));
    expect(scale.starts.first, 0);
    expect(scale.fan(0) + scale.fan(1), moreOrLessEquals(1));
  });

  for (final expansion in [
    [1.0, 0.0],
    [0.0, 1.0],
    [1.0, 0.3],
    [0.0, 0.0],
  ]) {
    test('a wide track caps every book, expansion $expansion', () {
      final scale = BookScale(starts, expansion, 24, 1200);
      for (var b = 0; b < starts.length; b++) {
        expect(scale.widths[b], moreOrLessEquals(20 * shelfMaxCell));
        expect(scale.fan(b), moreOrLessEquals(1));
      }
      final row = scale.widths.fold(0.0, (a, w) => a + w);
      expect(scale.starts.first - 24, moreOrLessEquals((1200 - row) / 2));
    });
  }

  test('a full book passes its room to the closed one', () {
    // 560 px: the open book takes its 280 px, the closed one the rest.
    final scale = BookScale(starts, [1, 0], 0, 560);
    expect(scale.widths[0], moreOrLessEquals(20 * shelfMaxCell));
    expect(scale.widths[1], moreOrLessEquals(560 - 280 - 22));
    expect(scale.starts.first, 0);
  });
}
