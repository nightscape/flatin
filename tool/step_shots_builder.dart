import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:pickled_cucumber/pickled_cucumber.dart';
import 'package:pickled_cucumber/src/model.dart';
import 'package:pickled_cucumber/src/test_code_builder.dart';
import 'package:source_gen/source_gen.dart';

/// pickled_cucumber has no per-step hook, so every generated step call
/// `await steps.x(widgetTester, ...);` is wrapped into
/// `await step(widgetTester, feature, scenario, text, steps.x(...));`
/// (see `test/support/step_shots.dart`).
class StepShotsCodeBuilder extends TestCodeBuilder {
  static final _call = RegExp(r'await steps\.(.+?);\n', dotAll: true);

  @override
  String buildCode(
    List<Feature> features,
    List<StepMethod> stepMethods,
    String stepDefsUri,
    String stepDefsClassName,
    PickledCucumber pickledCucumber,
  ) {
    final code = super.buildCode(
      features,
      stepMethods,
      stepDefsUri,
      stepDefsClassName,
      pickledCucumber,
    );
    final steps = [
      for (final feature in features)
        for (final scenario in feature.scenarios)
          for (final step in [...feature.backgroundSteps, ...scenario.steps])
            (feature.name, scenario.name, step),
    ].iterator;
    final wrapped = code
        .replaceAllMapped(_call, (m) {
          steps.moveNext();
          final (feature, scenario, step) = steps.current;
          return 'await step(widgetTester, ${_quote(feature)}, '
              '${_quote(scenario)}, ${_quote(step)}, steps.${m[1]});\n';
        })
        .replaceFirst(
          "import 'package:flutter_test/flutter_test.dart';",
          "import 'package:flutter_test/flutter_test.dart';\n"
              "import '../support/step_shots.dart';",
        );
    assert(!steps.moveNext(), 'more steps than generated calls');
    return DartFormatter(languageVersion: dartVersion).format(wrapped);
  }

  String _quote(String s) =>
      "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";
}

Builder stepShotsBuilder(BuilderOptions options) =>
    LibraryBuilder(StepShotsCodeBuilder(), generatedExtension: '.pickled.dart');
