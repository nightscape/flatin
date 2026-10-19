import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/step_definitions/app_steps.pickled.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // "A SemanticsHandle was active at the end of the test" fires when the
  // handle count grew during a scenario. No step turns semantics on, so the
  // handle is the one SemanticsBinding opens when macOS switches its
  // accessibility bridge on — which lands in whichever scenario is running.
  int handlesAtStart = 0;
  setUp(() => handlesAtStart = binding.debugOutstandingSemanticsHandles);
  tearDown(() {
    expect(
      binding.debugOutstandingSemanticsHandles,
      lessThanOrEqualTo(handlesAtStart),
      reason:
          'the platform switched semantics on during this scenario; the '
          'handle belongs to the binding, not to a step',
    );
  });

  runFeatures();
}
