import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise.dart';
import '../providers/fsrs_provider.dart';
import 'exercise_match_widget.dart';
import 'exercise_screen.dart';

/// Asks one grammar exercise after the other; each response reviews the
/// word card and the grammar card, and the next exercise follows from them.
class GrammarExercisePage extends ConsumerWidget {
  const GrammarExercisePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget message(Widget child) => Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, 'exercise.screen.title')),
      ),
      body: Center(child: child),
    );
    return ref
        .watch(nextGrammarExerciseProvider)
        .when(
          loading: () => message(const CircularProgressIndicator()),
          error: (error, _) => message(
            Text(
              FlutterI18n.translate(
                context,
                'home.error',
                translationParams: {'error': error.toString()},
              ),
            ),
          ),
          data: (asked) {
            if (asked == null) {
              return message(
                Text(
                  FlutterI18n.translate(context, 'exercise.home.nothingDue'),
                  key: const Key('exercise.home.nothingDue'),
                ),
              );
            }
            void respond(ExerciseResponse response) =>
                reviewExercise(ref, asked, response);
            return switch (asked.exercise.answer) {
              MatchingAnswer() => ExerciseMatchWidget(
                word: asked.word,
                exercise: asked.exercise,
                onResponse: respond,
              ),
              ChoiceAnswer() || TypedAnswer() => ExerciseScreen(
                word: asked.word,
                exercise: asked.exercise,
                onResponse: respond,
              ),
            };
          },
        );
  }
}
