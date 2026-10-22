import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../data/rewards.dart';

/// The buildings earned so far, in the order they were built.
class TownView extends StatelessWidget {
  const TownView(this.buildings, {super.key});

  final List<Building> buildings;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final b in buildings)
        Tooltip(
          message: FlutterI18n.translate(context, 'reward.building.${b.id}'),
          child: Text(b.emoji, style: const TextStyle(fontSize: 32)),
        ),
    ],
  );
}
