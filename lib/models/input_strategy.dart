import 'dart:math';

import 'package:flutter/material.dart';

/// All data a strategy might need to render its input widget.
class InputContext {
  final int index;
  final String correctAnswer;
  final List<String> allForms;

  /// The forms as the regular pattern would produce them (before explicit overrides).
  final List<String> inferredForms;
  final bool isChecked;
  final Color borderColor;
  final double labelFontSize;
  final bool isMobile;
  final String currentValue;
  final ValueChanged<String> onChanged;

  const InputContext({
    required this.index,
    required this.correctAnswer,
    required this.allForms,
    required this.inferredForms,
    required this.isChecked,
    required this.borderColor,
    required this.labelFontSize,
    required this.isMobile,
    required this.currentValue,
    required this.onChanged,
  });
}

/// Strategy for how the user enters answers in the practice screen.
abstract class InputStrategy {
  String get id;
  String get displayName;

  Widget buildInput(InputContext ctx);

  static final List<InputStrategy> all = [
    TextFieldStrategy(),
    AllFormsDropdownStrategy(),
    DistractorDropdownStrategy(),
    RegularFormDistractorStrategy(),
  ];

  static InputStrategy byId(String id) {
    return all.firstWhere((s) => s.id == id);
  }
}

// ---------------------------------------------------------------------------
// Strategies
// ---------------------------------------------------------------------------

/// Classic text field input — user types the answer.
class TextFieldStrategy extends InputStrategy {
  @override
  String get id => 'text_field';

  @override
  String get displayName => 'Texteingabe';

  @override
  Widget buildInput(InputContext ctx) {
    return _PersistentTextField(
      value: ctx.currentValue,
      isChecked: ctx.isChecked,
      borderColor: ctx.borderColor,
      labelFontSize: ctx.labelFontSize,
      isMobile: ctx.isMobile,
      onChanged: ctx.onChanged,
    );
  }
}

/// Dropdown showing all forms of the current word — user assigns each form.
class AllFormsDropdownStrategy extends InputStrategy {
  @override
  String get id => 'dropdown_all_forms';

  @override
  String get displayName => 'Dropdown (alle Formen)';

  @override
  Widget buildInput(InputContext ctx) {
    final options = ctx.allForms.toSet().toList()..sort();
    return _DropdownInput(
      options: options,
      currentValue: ctx.currentValue,
      isChecked: ctx.isChecked,
      borderColor: ctx.borderColor,
      labelFontSize: ctx.labelFontSize,
      isMobile: ctx.isMobile,
      onChanged: ctx.onChanged,
    );
  }
}

/// Dropdown showing the correct answer plus a few random distractors.
class DistractorDropdownStrategy extends InputStrategy {
  @override
  String get id => 'dropdown_distractors';

  @override
  String get displayName => 'Dropdown (mit Distraktoren)';

  @override
  Widget buildInput(InputContext ctx) {
    final distractors =
        ctx.allForms.where((f) => f != ctx.correctAnswer).toSet().toList();
    distractors.shuffle(Random(ctx.correctAnswer.hashCode ^ ctx.index));
    final options = [ctx.correctAnswer, ...distractors.take(3)];
    options.shuffle(Random(ctx.index * 37 + ctx.correctAnswer.length));
    return _DropdownInput(
      options: options,
      currentValue: ctx.currentValue,
      isChecked: ctx.isChecked,
      borderColor: ctx.borderColor,
      labelFontSize: ctx.labelFontSize,
      isMobile: ctx.isMobile,
      onChanged: ctx.onChanged,
    );
  }
}

/// Dropdown that includes the "regular" (pattern-inferred) form as a distractor
/// when the actual form is irregular. Teaches the user to distinguish irregular
/// forms from what the pattern would predict.
class RegularFormDistractorStrategy extends InputStrategy {
  @override
  String get id => 'dropdown_regular_distractor';

  @override
  String get displayName => 'Dropdown (reguläre Formen als Distraktoren)';

  @override
  Widget buildInput(InputContext ctx) {
    final options = <String>{ctx.correctAnswer};

    // Add the inferred (regular) form if it differs from the correct answer
    final inferredForm = ctx.inferredForms[ctx.index];
    if (inferredForm.toLowerCase() != ctx.correctAnswer.toLowerCase()) {
      options.add(inferredForm);
    }

    // Fill up to 4 options with other forms
    final others =
        ctx.allForms.where((f) => !options.contains(f)).toSet().toList();
    others.shuffle(Random(ctx.correctAnswer.hashCode ^ ctx.index));
    for (final o in others) {
      if (options.length >= 4) break;
      options.add(o);
    }

    final optionsList = options.toList();
    optionsList.shuffle(Random(ctx.index * 37 + ctx.correctAnswer.length));
    return _DropdownInput(
      options: optionsList,
      currentValue: ctx.currentValue,
      isChecked: ctx.isChecked,
      borderColor: ctx.borderColor,
      labelFontSize: ctx.labelFontSize,
      isMobile: ctx.isMobile,
      onChanged: ctx.onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _PersistentTextField extends StatefulWidget {
  final String value;
  final bool isChecked;
  final Color borderColor;
  final double labelFontSize;
  final bool isMobile;
  final ValueChanged<String> onChanged;

  const _PersistentTextField({
    required this.value,
    required this.isChecked,
    required this.borderColor,
    required this.labelFontSize,
    required this.isMobile,
    required this.onChanged,
  });

  @override
  State<_PersistentTextField> createState() => _PersistentTextFieldState();
}

class _PersistentTextFieldState extends State<_PersistentTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(() => widget.onChanged(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: widget.borderColor, width: 2),
    );

    return TextField(
      controller: _controller,
      enabled: !widget.isChecked,
      style: TextStyle(fontSize: widget.labelFontSize, color: Colors.black),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        disabledBorder: border,
        contentPadding: EdgeInsets.symmetric(
          horizontal: widget.isMobile ? 10 : 12,
          vertical: widget.isMobile ? 6 : 8,
        ),
      ),
    );
  }
}

class _DropdownInput extends StatelessWidget {
  final List<String> options;
  final String currentValue;
  final bool isChecked;
  final Color borderColor;
  final double labelFontSize;
  final bool isMobile;
  final ValueChanged<String> onChanged;

  const _DropdownInput({
    required this.options,
    required this.currentValue,
    required this.isChecked,
    required this.borderColor,
    required this.labelFontSize,
    required this.isMobile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = options.contains(currentValue) ? currentValue : null;

    return DropdownButtonFormField<String>(
      value: selected,
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: isChecked ? null : (v) => onChanged(v ?? ''),
      style: TextStyle(fontSize: labelFontSize, color: Colors.black),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: borderColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: borderColor, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 12,
          vertical: isMobile ? 6 : 8,
        ),
      ),
    );
  }
}
