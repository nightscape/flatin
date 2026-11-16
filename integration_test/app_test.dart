import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/step_definitions/app_steps.pickled.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // An accessibility client outside the app turns platform semantics on at a
  // random point, and the binding's handle for it trips the leak check.
  binding.platformDispatcher.onSemanticsEnabledChanged = null;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Generators: example sequences plus seeded random toggle sequences (the
  // platform's on/off requests are the whole input space of the observable,
  // the outstanding handle count).
  final toggleSequences = <List<bool>>[
    [true],
    [true, false, true],
    for (final seed in List.generate(20, (i) => i))
      () {
        final random = Random(seed);
        return List.generate(1 + random.nextInt(6), (_) => random.nextBool());
      }(),
  ];

  testWidgets('platform semantics requests open no semantics handle', (
    tester,
  ) async {
    addTearDown(binding.platformDispatcher.clearSemanticsEnabledTestValue);
    final before = binding.debugOutstandingSemanticsHandles;
    for (final sequence in toggleSequences) {
      for (final enabled in sequence) {
        binding.platformDispatcher.semanticsEnabledTestValue = enabled;
        expect(
          binding.debugOutstandingSemanticsHandles,
          before,
          reason: 'platform semantics request $enabled in $sequence',
        );
      }
    }
  });

  runFeatures();
}
