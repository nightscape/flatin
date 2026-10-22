import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise.dart';
import '../models/reward.dart';
import '../providers/reward_provider.dart';
import '../providers/round_providers.dart';
import '../widgets/reward_burst.dart';
import 'exercise_match_widget.dart';
import 'exercise_screen.dart';
import 'round_end_screen.dart';

/// Asks the tasks of one round; leaving the screen aborts the round.
class RoundScreen extends ConsumerStatefulWidget {
  const RoundScreen(this.request, {super.key});

  final RoundRequest request;

  @override
  ConsumerState<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends ConsumerState<RoundScreen> {
  /// The ledger before the first answer; the end screen shows the growth.
  RewardLedger? _start;
  ({int points, int serial})? _burst;

  String _t(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(context, key, translationParams: params);

  @override
  Widget build(BuildContext context) {
    final provider = roundProvider(widget.request);
    ref.listen(rewardsProvider, (previous, next) {
      if (previous?.value case final before?) {
        final gained = next.requireValue.points - before.points;
        if (gained > 0) {
          setState(
            () => _burst = (points: gained, serial: (_burst?.serial ?? 0) + 1),
          );
        }
      }
    });
    ref.listen(provider, (_, next) {
      if (next.value?.isOver ?? false) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RoundEndScreen(start: _start!)),
        );
      }
    });

    final round = ref.watch(provider);
    final rewards = ref.watch(rewardsProvider);
    _start ??= rewards.value;
    final error = round.error ?? rewards.error;
    if (error != null) {
      return _message(Text(_t('home.error', {'error': '$error'})));
    }
    if (!round.hasValue || !rewards.hasValue || round.requireValue.isOver) {
      return _message(const CircularProgressIndicator());
    }

    final state = round.requireValue;
    final task = state.queue.first;
    final title = state.inRetries
        ? _t('round.retry')
        : _t('round.task', {
            'n': '${state.shownNumber}',
            'total': '${state.total}',
          });
    void respond(ExerciseResponse response) =>
        ref.read(provider.notifier).respond(response);
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Stack(
      children: [
        switch (task.exercise.answer) {
          MatchingAnswer() => ExerciseMatchWidget(
            word: task.word,
            exercise: task.exercise,
            title: title,
            onResponse: respond,
          ),
          ChoiceAnswer() || TypedAnswer() => ExerciseScreen(
            word: task.word,
            exercise: task.exercise,
            title: title,
            onResponse: respond,
          ),
        },
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(
            value: state.inRetries ? 1 : state.answeredFirst / state.total,
          ),
        ),
        if (_burst case (:final points, :final serial))
          Positioned(
            top: top + 16,
            left: 0,
            right: 0,
            child: Center(child: RewardBurst(points, key: ValueKey(serial))),
          ),
      ],
    );
  }

  Widget _message(Widget child) => Scaffold(
    appBar: AppBar(title: Text(_t('home.grammar'))),
    body: Center(child: child),
  );
}
