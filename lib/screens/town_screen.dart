import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reward_provider.dart';
import '../widgets/town_view.dart';
import 'town_shop_screen.dart';

const double townMaxScale = 3;

/// The town in immersive full screen, zoomable; the shop opens from here.
class TownScreen extends ConsumerStatefulWidget {
  const TownScreen({super.key});

  @override
  ConsumerState<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends ConsumerState<TownScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(rewardsProvider).requireValue;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: townMaxScale,
              child: Center(child: TownView(ledger)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('town.close'),
                    tooltip: FlutterI18n.translate(context, 'town.close'),
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('town.build'),
                    icon: const Icon(Icons.construction),
                    label: Text(FlutterI18n.translate(context, 'town.build')),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TownShopScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
