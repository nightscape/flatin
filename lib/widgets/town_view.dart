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
    final built = townOf(ledger)..sort((a, b) => a.bottom.compareTo(b.bottom));
    final next = nextBuilding(ledger);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: townWidth / townHeight,
        child: LayoutBuilder(
          builder: (context, box) {
            Widget at(
              Building b,
              Key key,
              Widget Function(double width) child,
            ) {
              final width = b.width * box.maxWidth;
              return Positioned(
                key: key,
                left: b.x * box.maxWidth - width / 2,
                bottom: (1 - b.bottom) * box.maxHeight,
                width: width,
                child: child(width),
              );
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/town/background.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                for (final b in built)
                  at(
                    b,
                    Key('town.building.${b.id}'),
                    (_) => Tooltip(
                      message: FlutterI18n.translate(
                        context,
                        'reward.building.${b.id}',
                      ),
                      child: Image.asset('assets/town/${b.id}.png'),
                    ),
                  ),
                if (next != null)
                  at(
                    next,
                    Key('town.next.${next.id}'),
                    (_) => Image.asset('assets/town/construction.png'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
