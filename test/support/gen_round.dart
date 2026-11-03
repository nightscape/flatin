import 'dart:math';

import 'package:fsrs/fsrs.dart';

/// The grammar ratings a first attempt gets; no answer rates Easy.
const firstAttemptRatings = [Rating.good, Rating.hard, Rating.again];

/// The counted first attempts of one bundle in one round: 1..12 ratings.
List<Rating> genFirstAttempts(Random rng) => [
  for (var i = 0, n = 1 + rng.nextInt(12); i < n; i++)
    firstAttemptRatings[rng.nextInt(firstAttemptRatings.length)],
];
