import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../data/rewards.dart';
import '../models/reward.dart';

/// The town scene: built buildings back to front, a construction site for the next one.
class TownView extends StatelessWidget {
  const TownView(this.ledger, {super.key});

  final RewardLedger ledger;

  @override
  Widget build(BuildContext context) {
    final built = townOf(ledger).map((b) => b.id).toSet();
    final next = nextBuilding(ledger);
    // The aqueduct has no plate: its site stands at the castellum, which carries its tooltip.
    final site = next == null
        ? null
        : townSprites.singleWhere(
            (s) =>
                s.sprite == (next.id == 'aquaeductus' ? 'castellum' : next.id),
          );
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
                              message: FlutterI18n.translate(
                                context,
                                'reward.building.${s.building}',
                              ),
                              child: Image.asset('assets/town/${s.sprite}.png'),
                            ),
                    ),
                if (site != null)
                  at(
                    site,
                    Key('town.next.${next!.id}'),
                    Image.asset('assets/town/construction.png'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
