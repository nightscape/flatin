import 'package:latin_practice/models/reward.dart';
import 'package:latin_practice/providers/reward_provider.dart';

/// The real rewards that also keep every event in [sent].
final class RecordingRewards extends Rewards {
  RecordingRewards(this.sent);

  final List<RewardEvent> sent;

  @override
  Future<List<RewardEffect>> send(RewardEvent event) {
    sent.add(event);
    return super.send(event);
  }
}
