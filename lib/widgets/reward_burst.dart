import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// "🪙 +N", and "⭐ +M" next to it when M > 0, that drifts up and fades out; it never takes a tap.
class RewardBurst extends ConsumerStatefulWidget {
  const RewardBurst(this.points, {this.bonus = 0, super.key});

  final int points;
  final int bonus;

  @override
  ConsumerState<RewardBurst> createState() => _RewardBurstState();
}

class _RewardBurstState extends ConsumerState<RewardBurst> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      settingsProvider.select((s) => s.requireValue.rewardAnimation),
    );
    if (!enabled || MediaQuery.disableAnimationsOf(context) || _done) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        onEnd: () => setState(() => _done = true),
        builder: (context, t, child) => Opacity(
          opacity: 1 - t,
          child: Transform.translate(offset: Offset(0, -32 * t), child: child),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text('🪙 +${widget.points}'),
              if (widget.bonus > 0) Text('⭐ +${widget.bonus}'),
            ],
          ),
        ),
      ),
    );
  }
}
