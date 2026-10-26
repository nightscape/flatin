import 'package:flutter/material.dart';

const terracotta = Color(0xFFA0412D);
const terracottaDark = Color(0xFF7E2F1F);
const gold = Color(0xFFC9A227);
const marble = Color(0xFFF4EDE1);
const parchment = Color(0xFFFBF7F0);
const sand = Color(0xFFE6D9C0);
const ink = Color(0xFF2B1D14);
const mutedText = Color(0xFF7A6A5A);
const outlineColor = Color(0xFFB8A88F);

const headingFont = 'Cinzel';

final romanTheme = _build();

ThemeData _build() {
  const scheme = ColorScheme.light(
    primary: terracotta,
    onPrimary: parchment,
    secondary: gold,
    onSecondary: ink,
    surface: parchment,
    onSurface: ink,
    onSurfaceVariant: mutedText,
    surfaceContainerHighest: sand,
    outline: outlineColor,
    error: Color(0xFFB3261E),
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: marble,
  );
  const heading = TextStyle(
    fontFamily: headingFont,
    fontWeight: FontWeight.w700,
  );
  final text = base.textTheme.apply(bodyColor: ink, displayColor: ink);
  final roundedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );
  return base.copyWith(
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.merge(heading),
      titleLarge: text.titleLarge?.merge(heading),
      titleMedium: text.titleMedium?.merge(heading),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: terracotta,
      foregroundColor: parchment,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: heading.copyWith(fontSize: 20, color: parchment),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: marble),
    cardTheme: CardThemeData(
      color: parchment,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: outlineColor),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: sand,
        foregroundColor: ink,
        disabledBackgroundColor: sand.withValues(alpha: 0.5),
        elevation: 0,
        shape: roundedShape,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: terracotta,
        foregroundColor: parchment,
        shape: roundedShape,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: terracotta,
      titleTextStyle: text.bodyLarge?.copyWith(color: ink, fontSize: 16),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? gold : outlineColor,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? terracotta : sand,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? terracotta : null,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: sand,
      selectedColor: gold.withValues(alpha: 0.45),
      side: const BorderSide(color: outlineColor),
      labelStyle: const TextStyle(color: ink),
    ),
  );
}
