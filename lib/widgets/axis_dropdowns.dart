import 'package:flutter/material.dart';

import '../models/answer_description.dart';

/// One dropdown per shown axis of [selectors], keyed `<keyPrefix>.<axis id>`.
class AxisDropdowns extends StatelessWidget {
  final Selectors selectors;
  final String keyPrefix;
  final Map<String, String?> picks;
  final bool isMobile;

  /// Null locks the dropdowns.
  final void Function(String section, String? value)? onPick;

  const AxisDropdowns({
    super.key,
    required this.selectors,
    required this.keyPrefix,
    required this.picks,
    required this.isMobile,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: isMobile ? 8 : 12,
    runSpacing: isMobile ? 8 : 12,
    children: selectors.sections.map((section) {
      return SizedBox(
        width: isMobile ? double.infinity : 150,
        child: DropdownButtonFormField<String>(
          key: Key('$keyPrefix.$section'),
          isExpanded: true,
          value: picks[section],
          decoration: InputDecoration(
            labelText: selectors.axes.byId(section).name,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 12 : 16,
            ),
          ),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('--')),
            ...selectors.options[section]!.map(
              (code) => DropdownMenuItem<String>(
                value: code,
                child: Text(selectors.optionText(section, code)),
              ),
            ),
          ],
          onChanged: onPick == null ? null : (value) => onPick!(section, value),
        ),
      );
    }).toList(),
  );
}
