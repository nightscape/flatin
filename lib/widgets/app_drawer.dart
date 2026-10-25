import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/grammar_start_screen.dart';
import '../screens/practice_screen.dart';
import '../screens/word_classification_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/language_screen.dart';
import '../models/practice_item.dart';
import '../providers/fsrs_provider.dart';

Widget buildAppDrawer(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final headerFontSize = isMobile ? 22.0 : 28.0;
  final itemFontSize = isMobile ? 16.0 : 18.0;

  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
          ),
          child: Text(
            FlutterI18n.translate(context, 'drawer.title'),
            style: TextStyle(
              color: parchment,
              fontSize: headerFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _practiceTile(
          tileKey: const Key('drawer.nouns'),
          dataFileId: 'nouns',
          labelKey: 'drawer.nouns',
          icon: Icons.book,
          fontSize: itemFontSize,
        ),
        _practiceTile(
          tileKey: const Key('drawer.verbs'),
          dataFileId: 'verbs',
          labelKey: 'drawer.verbs',
          icon: Icons.auto_stories,
          fontSize: itemFontSize,
        ),
        ListTile(
          key: const Key('drawer.grammar'),
          leading: const Icon(Icons.school, color: Colors.black),
          title: Text(
            FlutterI18n.translate(context, 'drawer.grammar'),
            style: TextStyle(color: Colors.black, fontSize: itemFontSize),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const GrammarStartScreen(),
              ),
            );
          },
        ),
        ListTile(
          key: const Key('drawer.wordClassification'),
          leading: const Icon(Icons.category, color: Colors.black),
          title: Text(
            FlutterI18n.translate(context, 'drawer.wordClassification'),
            style: TextStyle(color: Colors.black, fontSize: itemFontSize),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const WordClassificationScreen(),
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          key: const Key('drawer.language'),
          leading: const Icon(Icons.language, color: Colors.black),
          title: Text(
            FlutterI18n.translate(context, 'drawer.language'),
            style: TextStyle(color: Colors.black, fontSize: itemFontSize),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const LanguageScreen()),
            );
          },
        ),
        ListTile(
          key: const Key('drawer.settings'),
          leading: const Icon(Icons.settings, color: Colors.black),
          title: Text(
            FlutterI18n.translate(context, 'drawer.settings'),
            style: TextStyle(color: Colors.black, fontSize: itemFontSize),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    ),
  );
}

/// Opens a practicable item of the given type; disabled while the type has
/// none, either because it is switched off or because nothing has loaded yet.
Widget _practiceTile({
  required Key tileKey,
  required String dataFileId,
  required String labelKey,
  required IconData icon,
  required double fontSize,
}) {
  return Consumer(
    builder: (context, ref, child) {
      final practicable =
          ref.watch(practicableItemsByTypeProvider).value?[dataFileId] ??
          const <PracticeItem>[];
      final enabled = practicable.isNotEmpty;
      final color = enabled ? Colors.black : Theme.of(context).disabledColor;

      return ListTile(
        key: tileKey,
        enabled: enabled,
        leading: Icon(icon, color: color),
        title: Text(
          FlutterI18n.translate(context, labelKey),
          style: TextStyle(color: color, fontSize: fontSize),
        ),
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PracticeScreen(item: practicable.first),
            ),
          );
        },
      );
    },
  );
}
