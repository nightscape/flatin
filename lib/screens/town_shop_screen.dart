import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/game_rules.dart';
import '../models/reward.dart';
import '../providers/reward_provider.dart';

/// The buildings not built yet, bought with the coin balance.
class TownShopScreen extends ConsumerWidget {
  const TownShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key, [Map<String, String>? params]) =>
        FlutterI18n.translate(context, key, translationParams: params);
    final ledger = ref.watch(rewardsProvider).requireValue;
    final rules = ref.watch(gameRulesProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: Text(t('shop.title'))),
      body: ListView(
        children: [
          for (final b in rules.unbuilt(ledger))
            ListTile(
              key: Key('shop.item.${b.id}'),
              enabled: ledger.canAfford(b.price),
              leading: Image.asset('assets/town/${b.id}.png', width: 56),
              title: Text(t('reward.building.${b.id}')),
              subtitle: Text(
                [
                  ledger.canAfford(b.price)
                      ? t('shop.price', {'price': '${b.price[coins]}'})
                      : t('shop.missing', {
                          'price': '${b.price[coins]}',
                          'missing':
                              '${b.price[coins]! - ledger.balance(coins)}',
                        }),
                  if (b.modifies.isNotEmpty) t('reward.effect.${b.id}'),
                ].join('\n'),
              ),
              onTap: () => _confirm(context, ref, b),
            ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref, Building b) async {
    final name = FlutterI18n.translate(context, 'reward.building.${b.id}');
    final bought = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          FlutterI18n.translate(
            context,
            'shop.confirm',
            translationParams: {'name': name, 'price': '${b.price[coins]}'},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(FlutterI18n.translate(context, 'shop.cancel')),
          ),
          TextButton(
            key: const Key('shop.confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(FlutterI18n.translate(context, 'shop.buy')),
          ),
        ],
      ),
    );
    if (bought == true) {
      await ref.read(rewardsProvider.notifier).buy(b);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
