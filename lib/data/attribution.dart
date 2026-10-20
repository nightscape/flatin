import 'package:fsrs/fsrs.dart';

import '../models/exercise.dart';
import '../models/practice_item.dart';

/// The ratings one [response] to [exercise] of [word] gives the word card and
/// the grammar card; `grammar` is null when the response says nothing about
/// the bundle.
/// Produced here from the exercise and the diagnosis; read by the review step.
({Rating word, Rating? grammar}) attribute(
  PracticeItem word,
  Exercise exercise,
  ExerciseResponse response,
) => throw UnimplementedError('attribute');
