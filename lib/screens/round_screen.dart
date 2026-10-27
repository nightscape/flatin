import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise.dart';
import '../models/input_strategy.dart';
import '../models/reward.dart';
import '../providers/curriculum_provider.dart';
import '../providers/reward_provider.dart';
import '../providers/round_providers.dart';
import '../providers/settings_provider.dart';
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
  ({int points, int bonus, num factor, int serial})? _burst;

  String _t(String key, [Map<String, String>? params]) =>
      FlutterI18n.translate(context, key, translationParams: params);

  @override
  Widget build(BuildContext context) {
    final provider = roundProvider(widget.request);
    ref.listen(rewardsProvider, (previous, next) {
      if (previous?.value case final before?) {
        final after = next.requireValue;
        final bonus =
            after.taggedOf(coins, 'bonus') - before.taggedOf(coins, 'bonus');
        final gained = after.earnedOf(coins) - before.earnedOf(coins) - bonus;
        if (gained > 0) {
          setState(
            () => _burst = (
              points: gained,
              bonus: bonus,
              factor: ref
                  .read(gameRulesProvider)
                  .requireValue
                  .multiplierOf(before, coins),
              serial: (_burst?.serial ?? 0) + 1,
            ),
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
    final settings = ref.watch(settingsProvider);
    final filter = ref.watch(courseFilterProvider);
    _start ??= rewards.value;
    final error =
        round.error ?? rewards.error ?? settings.error ?? filter.error;
    if (error != null) {
      return _message(Text(_t('home.error', {'error': '$error'})));
    }
    if (!round.hasValue ||
        !rewards.hasValue ||
        !settings.hasValue ||
        !filter.hasValue ||
        round.requireValue.isOver) {
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
            inputStrategy: InputStrategy.byId(
              settings.requireValue.getInputStrategyId(task.word.dataFileId),
            ),
            practicedForms: filter.requireValue.practicedForms(
              task.word.dataFileId,
              task.word.formLabels,
            ),
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
        if (_burst case (
          :final points,
          :final bonus,
          :final factor,
          :final serial,
        ))
          Positioned(
            top: top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: RewardBurst(
                points,
                bonus: bonus,
                factor: factor,
                key: ValueKey(serial),
              ),
            ),
          ),
      ],
    );
  }

  Widget _message(Widget child) => Scaffold(
    appBar: AppBar(title: Text(_t('home.grammar'))),
    body: Center(child: child),
  );
}
