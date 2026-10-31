import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/word_focus.dart';
import '../models/reward.dart';
import '../providers/reward_provider.dart';
import '../providers/round_providers.dart';
import '../widgets/reward_burst.dart';
import '../widgets/town_view.dart';
import 'grammar_start_screen.dart';
import 'round_screen.dart';

/// Shows only what the round added to the ledger since [start]; the next
/// round keeps [focus].
class RoundEndScreen extends ConsumerWidget {
  const RoundEndScreen({super.key, required this.start, required this.focus});

  final RewardLedger start;
  final WordFocus focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key, [Map<String, String>? params]) =>
        FlutterI18n.translate(context, key, translationParams: params);
    final ledger = ref.watch(rewardsProvider).requireValue;
    final rules = ref.watch(gameRulesProvider).requireValue;
    final offer = ref.watch(todayOfferProvider(focus)).value;
    final next = offer == null ? null : requestOf(offer, focus);
    final bonus =
        ledger.taggedOf(coins, 'bonus') - start.taggedOf(coins, 'bonus');
    final gained = ledger.earnedOf(coins) - start.earnedOf(coins) - bonus;
    final times = multiplierSuffix(rules.multiplierOf(start, coins));
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t('home.grammar'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('round.end.title'), style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (gained > 0)
            Text(
              t('round.end.points', {'points': '$gained'}) + times,
              style: textTheme.titleLarge,
            ),
          if (bonus > 0)
            Text(
              t('round.end.bonus', {'bonus': '$bonus'}) + times,
              style: textTheme.titleLarge,
            ),
          Text(t('round.end.total', {'total': '${ledger.balance(coins)}'})),
          const SizedBox(height: 16),
          if (rules.unbuilt(ledger).any((b) => rules.isBuyable(ledger, b)))
            Text(
              t('round.end.canBuy'),
              key: const Key('round.end.canBuy'),
              style: textTheme.titleMedium,
            ),
          TownView(ledger, rules),
          if (ledger.practiceDays > 0) ...[
            const SizedBox(height: 16),
            Text(t('round.start.days', {'n': '${ledger.practiceDays}'})),
          ],
          const SizedBox(height: 24),
          if (next != null)
            ElevatedButton(
              key: const Key('round.end.again'),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => RoundScreen(next)),
              ),
              child: Text(t('round.end.again')),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            key: const Key('round.end.done'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('round.end.done')),
          ),
        ],
      ),
    );
  }
}
