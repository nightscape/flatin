import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import '../data/esel_steps.dart';

const _kindColors = <EselKind, Color>{
  EselKind.erkennen: Color(0xFF1565C0),
  EselKind.stamm: Color(0xFF2E7D32),
  EselKind.endung: Color(0xFFBF360C),
  EselKind.lautregel: Color(0xFF6A1B9A),
  EselKind.verbinden: Color(0xFF00838F),
  EselKind.merken: Color(0xFFC62828),
};

const _optionHeight = 44.0;

enum EselStepStatus { done, open, pending }

/// How far the learner has come in the steps of one wrong form. A step with
/// no options (merken, absent) is done from the start; any other step is done
/// once its right option is picked or it is shown.
class EselProgress {
  final List<EselStep> steps;
  final Set<int> _revealed = {};
  final Map<int, Set<String>> _wrongPicks = {};

  EselProgress(this.steps);

  bool isDone(int index) =>
      steps[index].options.isEmpty || _revealed.contains(index);

  int? get openIndex {
    for (var i = 0; i < steps.length; i++) {
      if (!isDone(i)) return i;
    }
    return null;
  }

  EselStepStatus statusOf(int index) {
    if (isDone(index)) return EselStepStatus.done;
    return index == openIndex ? EselStepStatus.open : EselStepStatus.pending;
  }

  Set<String> wrongPicks(int index) => _wrongPicks[index] ?? const {};

  void pick(int index, EselOption option) {
    if (option.isRight) {
      _revealed.add(index);
    } else {
      _wrongPicks.putIfAbsent(index, () => {}).add(option.identity);
    }
  }

  void show(int index) => _revealed.add(index);
}

String _name(BuildContext context, EselKind kind) =>
    FlutterI18n.translate(context, 'esel.kind.${kind.name}.name');

String _letter(BuildContext context, EselKind kind) =>
    FlutterI18n.translate(context, 'esel.kind.${kind.name}.letter');

String _optionText(BuildContext context, EselOption option) =>
    option.textKey == null
    ? option.text
    : FlutterI18n.translate(context, option.textKey!);

String _answerText(BuildContext context, EselStep step) =>
    step.answerKey == null
    ? step.answer
    : FlutterI18n.translate(
        context,
        step.answerKey!,
        translationParams: step.answerParams,
      );

class EselBadge extends StatelessWidget {
  final EselKind kind;

  const EselBadge(this.kind, {super.key});

  @override
  Widget build(BuildContext context) {
    final letter = _letter(context, kind);
    return Semantics(
      label: '$letter ${_name(context, kind)}',
      excludeSemantics: true,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kindColors[kind],
          shape: BoxShape.circle,
        ),
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// One step. [scope] keeps the keys of several panels on one screen apart:
/// `<scope>.<kind>`, `<scope>.<kind>.option.<text>`, `<scope>.<kind>.show`.
class EselStepRow extends StatelessWidget {
  final String scope;
  final EselStep step;
  final EselStepStatus status;
  final Set<String> wrongPicks;
  final void Function(EselOption option)? onPick;
  final VoidCallback? onShow;
  final bool showQuestion;

  const EselStepRow({
    super.key,
    required this.scope,
    required this.step,
    required this.status,
    this.wrongPicks = const {},
    this.onPick,
    this.onShow,
    this.showQuestion = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = _kindColors[step.kind]!;
    final bool done = status == EselStepStatus.done;
    final stepKey = '$scope.${step.kind.name}';

    return CustomPaint(
      key: Key(stepKey),
      painter: _StepBorder(
        color: status == EselStepStatus.pending ? Colors.grey : color,
        dashed: step.absent,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EselBadge(step.kind),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _name(context, step.kind),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      if (!done && onShow != null)
                        TextButton(
                          key: Key('$stepKey.show'),
                          onPressed: onShow,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, _optionHeight),
                          ),
                          child: Text(
                            FlutterI18n.translate(context, 'esel.show'),
                          ),
                        ),
                    ],
                  ),
                  if (step.absent) _absentBody(context),
                  if (!step.absent && done) _doneBody(context),
                  if (status == EselStepStatus.open)
                    _openBody(context, stepKey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _absentBody(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      Text(
        FlutterI18n.translate(context, 'esel.absentLabel'),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
      Text(_answerText(context, step)),
    ],
  );

  Widget _doneBody(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (step.options.isEmpty && showQuestion)
        Text(
          FlutterI18n.translate(
            context,
            step.questionKey,
            translationParams: step.questionParams,
          ),
        ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _answerText(context, step),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      if (step.regular != null)
        Text(
          step.regular!,
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ),
    ],
  );

  Widget _openBody(BuildContext context, String stepKey) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        FlutterI18n.translate(
          context,
          step.questionKey,
          translationParams: step.questionParams,
        ),
      ),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in step.options)
            _optionButton(context, stepKey, option),
        ],
      ),
    ],
  );

  Widget _optionButton(
    BuildContext context,
    String stepKey,
    EselOption option,
  ) {
    final bool wrong = wrongPicks.contains(option.identity);
    return OutlinedButton(
      key: Key('$stepKey.option.${option.identity}'),
      onPressed: onPick == null ? null : () => onPick!(option),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, _optionHeight),
        foregroundColor: wrong ? Colors.red : null,
        side: BorderSide(color: wrong ? Colors.red : Colors.grey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (wrong)
            Semantics(
              label: FlutterI18n.translate(context, 'esel.wrongPick'),
              child: const Icon(Icons.close, size: 16),
            ),
          if (wrong) const SizedBox(width: 4),
          Flexible(child: Text(_optionText(context, option))),
        ],
      ),
    );
  }
}

class _StepBorder extends CustomPainter {
  final Color color;
  final bool dashed;

  const _StepBorder({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      );
    if (!dashed) {
      canvas.drawPath(outline, paint);
      return;
    }
    for (final PathMetric metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 10) {
        canvas.drawPath(metric.extractPath(at, at + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StepBorder old) =>
      old.color != color || old.dashed != dashed;
}

/// The panel under a wrong form: collapsible, with the quiz of [progress].
class EselPanel extends StatelessWidget {
  final String scope;
  final EselProgress progress;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(int index, EselOption option) onPick;
  final void Function(int index) onShow;

  const EselPanel({
    super.key,
    required this.scope,
    required this.progress,
    required this.expanded,
    required this.onToggle,
    required this.onPick,
    required this.onShow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('$scope.toggle'),
            onTap: onToggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _optionHeight),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      FlutterI18n.translate(context, 'esel.panel.title'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    key: Key('$scope.info'),
                    icon: const Icon(Icons.info_outline),
                    tooltip: FlutterI18n.translate(context, 'esel.legend.open'),
                    onPressed: () => showEselLegend(context),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: [
                  for (var i = 0; i < progress.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: EselStepRow(
                        scope: scope,
                        step: progress.steps[i],
                        status: progress.statusOf(i),
                        wrongPicks: progress.wrongPicks(i),
                        onPick: (option) => onPick(i, option),
                        onShow: () => onShow(i),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The steps of the forms named by [title], all done: no question, no reveal
/// button.
class EselStaticSteps extends StatelessWidget {
  final String scope;
  final String title;
  final List<EselStep> steps;

  const EselStaticSteps({
    super.key,
    required this.scope,
    required this.title,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          title,
          key: Key('$scope.title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      for (final step in steps)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: EselStepRow(
            scope: scope,
            step: step,
            status: EselStepStatus.done,
            showQuestion: false,
          ),
        ),
    ],
  );
}

Future<void> showEselLegend(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FlutterI18n.translate(context, 'esel.legend.title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(FlutterI18n.translate(context, 'esel.legend.intro')),
          const SizedBox(height: 12),
          for (final kind in EselKind.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                key: Key('esel.legend.${kind.name}'),
                children: [
                  EselBadge(kind),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name(context, kind),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          FlutterI18n.translate(
                            context,
                            'esel.legend.meaning.${kind.name}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  ),
);
