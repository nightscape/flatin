import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rewards.dart';
import '../providers/reward_provider.dart';

/// The buildings not built yet, bought with the coin balance.
class TownShopScreen extends ConsumerWidget {
  const TownShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key, [Map<String, String>? params]) =>
        FlutterI18n.translate(context, key, translationParams: params);
    final ledger = ref.watch(rewardsProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: Text(t('shop.title'))),
      body: ListView(
        children: [
          for (final b in unbuiltOf(ledger))
            ListTile(
              key: Key('shop.item.${b.id}'),
              enabled: b.price <= ledger.balance,
              leading: Image.asset('assets/town/${b.id}.png', width: 56),
              title: Text(t('reward.building.${b.id}')),
              subtitle: Text(
                b.price <= ledger.balance
                    ? t('shop.price', {'price': '${b.price}'})
                    : t('shop.missing', {
                        'price': '${b.price}',
                        'missing': '${b.price - ledger.balance}',
                      }),
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
            translationParams: {'name': name, 'price': '${b.price}'},
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
