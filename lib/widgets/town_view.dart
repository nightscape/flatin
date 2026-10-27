import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../data/game_rules.dart';
import '../data/rewards.dart';
import '../models/reward.dart';

/// The town scene: built buildings back to front.
class TownView extends StatelessWidget {
  const TownView(this.ledger, this.rules, {super.key});

  final RewardLedger ledger;
  final GameRules rules;

  @override
  Widget build(BuildContext context) {
    final built = ledger.buildings.toSet();
    final modifying = {
      for (final b in rules.buildings)
        if (b.modifies.isNotEmpty) b.id,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: townWidth / townHeight,
        child: LayoutBuilder(
          builder: (context, box) {
            Widget at(TownSprite s, Key key, Widget child) {
              return Positioned(
                key: key,
                left: s.left * box.maxWidth,
                bottom: (1 - s.bottom) * box.maxHeight,
                width: s.width * box.maxWidth,
                child: child,
              );
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/town/background.webp',
                    fit: BoxFit.cover,
                  ),
                ),
                for (final s in townSprites)
                  if (built.contains(s.building))
                    at(
                      s,
                      Key('town.building.${s.sprite}'),
                      s.sprite.startsWith('aquaeductus-')
                          ? Image.asset('assets/town/${s.sprite}.png')
                          : Tooltip(
                              message: [
                                FlutterI18n.translate(
                                  context,
                                  'reward.building.${s.building}',
                                ),
                                if (modifying.contains(s.building))
                                  FlutterI18n.translate(
                                    context,
                                    'reward.effect.${s.building}',
                                  ),
                              ].join('\n'),
                              child: Image.asset('assets/town/${s.sprite}.png'),
                            ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
