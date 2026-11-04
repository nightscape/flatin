import 'dart:math';

/// A book label of 0 to 40 characters, drawn from letters and spaces.
String drawShelfLabel(Random rng) {
  const alphabet = 'abcdefghij klmnopqrst';
  return String.fromCharCodes([
    for (var i = rng.nextInt(41); i > 0; i--)
      alphabet.codeUnitAt(rng.nextInt(alphabet.length)),
  ]);
}
