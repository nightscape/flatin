import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/topics.dart';
import '../models/lesson_range.dart';
import '../providers/reward_provider.dart';
import '../providers/round_providers.dart';
import 'round_screen.dart';

/// The round [offer] starts; null when nothing is due.
RoundRequest? requestOf(TodayOffer offer) => switch (offer) {
  MixedOffer() => const MixedRound(),
  NewTopicOffer(:final topic) => BlockedRound(topic.id),
  NothingDue() => null,
};

/// "Heute dran" on top, then every topic the course offers.
class GrammarStartScreen extends ConsumerWidget {
  const GrammarStartScreen({super.key, this.namer = const DerivedTopicNamer()});

  final TopicNamer namer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key, [Map<String, String>? params]) =>
        FlutterI18n.translate(context, key, translationParams: params);
    void open(RoundRequest request) => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RoundScreen(request)));

    final offer = ref.watch(todayOfferProvider);
    final topics = ref.watch(topicsProvider);
    final rewards = ref.watch(rewardsProvider);
    final error = offer.error ?? topics.error ?? rewards.error;
    final Widget body;
    if (error != null) {
      body = Center(child: Text(t('home.error', {'error': '$error'})));
    } else if (!offer.hasValue || !topics.hasValue || !rewards.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final request = requestOf(offer.requireValue);
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('round.start.today'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(switch (offer.requireValue) {
                    MixedOffer() => t('round.start.mixed'),
                    NewTopicOffer(:final topic) => t('round.start.newTopic', {
                      'name': namer.name(topic),
                    }),
                    NothingDue() => t('round.start.nothingDue'),
                  }),
                  if (request != null) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      key: const Key('round.start.go'),
                      onPressed: () => open(request),
                      child: Text(t('round.start.go')),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t('round.start.topics'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final topic in topics.requireValue)
            ListTile(
              key: Key('round.topic.${topic.id}'),
              title: Text(namer.name(topic)),
              subtitle: Text(
                topic.lesson == laterLesson
                    ? t('round.start.later')
                    : t('round.start.lesson', {'n': '${topic.lesson}'}),
              ),
              onTap: () => open(BlockedRound(topic.id)),
            ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(t('home.grammar'))),
      body: body,
    );
  }
}
