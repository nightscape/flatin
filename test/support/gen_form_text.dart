import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latin_practice/models/settings.dart' show StemMarking;

/// Letters of Latin, Greek and Cyrillic words, with precomposed and combining
/// macrons.
const formTextLetters = [
  'a',
  'e',
  'i',
  'o',
  'u',
  'm',
  's',
  'r',
  't',
  'n',
  'c',
  'l',
  'ā',
  'ē',
  'ī',
  'ō',
  'ū',
  'ā',
  'ē',
  'α',
  'β',
  'ω',
  'ж',
  'д',
];

typedef FormTextCase = ({String text, int? split, StemMarking mode});

/// 0 to 12 letters; split null, or 1..length-1 when the form has 2 letters
/// or more.
FormTextCase drawFormTextCase(Random rng) {
  final letters = [
    for (var i = rng.nextInt(13); i > 0; i--)
      formTextLetters[rng.nextInt(formTextLetters.length)],
  ];
  final split = letters.length < 2 || rng.nextInt(4) == 0
      ? null
      : 1 + rng.nextInt(letters.length - 1);
  return (
    text: letters.join(),
    split: split,
    mode: StemMarking.values[rng.nextInt(StemMarking.values.length)],
  );
}

/// What the learner can do with a form in its marking: free marking, placing
/// a bar to confirm, or nothing.
enum FormTextTaps { none, free, checked }

FormTextTaps tapsOf(FormTextCase c) => switch ((c.mode, c.split)) {
  (StemMarking.aus, _) => FormTextTaps.none,
  (_, null) when c.text.characters.length < 2 => FormTextTaps.none,
  (_, null) => FormTextTaps.free,
  (StemMarking.zeigen, _) => FormTextTaps.none,
  (StemMarking.selbstMarkieren, _) => FormTextTaps.checked,
};

/// 1..8 taps on the gaps 1..[letters]-1 of a form; [letters] is at least 2.
List<int> drawGapTaps(Random rng, int letters) => [
  for (var i = 1 + rng.nextInt(8); i > 0; i--) 1 + rng.nextInt(letters - 1),
];

/// A text style the way a form can be shown: size 10..40, weight normal or bold.
TextStyle drawFormTextStyle(Random rng) => TextStyle(
  fontSize: 10.0 + rng.nextInt(31),
  fontWeight: rng.nextBool() ? FontWeight.bold : FontWeight.normal,
);

/// The system text scales a learner can set.
const formTextScales = [1.0, 1.3, 2.0];

/// Screen widths a form is laid out under: two narrow phones and the width of
/// the test surface.
const formTextWidths = [320.0, 360.0, 800.0];

/// 9 to 14 letters, so that a form breaks over two lines at a narrow width and a
/// large text scale.
String drawLongForm(Random rng) => [
  for (var i = 9 + rng.nextInt(6); i > 0; i--)
    formTextLetters[rng.nextInt(formTextLetters.length)],
].join();
