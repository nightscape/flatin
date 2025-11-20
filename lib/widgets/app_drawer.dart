import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import '../screens/practice_screen.dart';
import '../screens/word_classification_screen.dart';
import '../screens/settings_screen.dart';
import '../data/practice_data.dart';
import '../models/practice_item.dart';

Widget buildAppDrawer(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  final headerFontSize = isMobile ? 22.0 : 28.0;
  final itemFontSize = isMobile ? 16.0 : 18.0;

  return Drawer(
    backgroundColor: const Color(0xFFE5E5E5),
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            color: Color(0xFFD0D0D0),
          ),
          child: Text(
            FlutterI18n.translate(context, 'drawer.title'),
            style: TextStyle(
              color: Colors.black,
              fontSize: headerFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          key: const Key('drawer.nouns'),
          leading: const Icon(Icons.book, color: Colors.black),
          title: Text(
            FlutterI18n.translate(context, 'drawer.nouns'),
            style: TextStyle(color: Colors.black, fontSize: itemFontSize),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FutureBuilder<List<PracticeItem>>(
                  future: loadPracticeItems('lib/data/latin_nouns.yaml'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Scaffold(
                        body: Center(
                          child: Text(
                            FlutterI18n.translate(context, 'drawer.errorLoadingData'),
                          ),
                        ),
                      );
                    }
                    return PracticeScreen(item: snapshot.data!.first);
                  },
                ),
              ),
            );
          },
        ),
        ListTile(
          key: const Key('drawer.verbs'),
          leading: const Icon(Icons.auto_stories, color: Colors.black),
          title: Text(
            FlutterI18n.translate(context, 'drawer.verbs'),
            style: TextStyle(color: Colors.black, fontSize: itemFontSize),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FutureBuilder<List<PracticeItem>>(
                  future: loadPracticeItems('lib/data/latin_verbs.yaml'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Scaffold(
                        body: Center(
                          child: Text(
                            FlutterI18n.translate(context, 'drawer.errorLoadingData'),
                          ),
                        ),
                      );
                    }
                    return PracticeScreen(item: snapshot.data!.first);
                  },
                ),
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
          key: const Key('drawer.settings'),
          leading: const Icon(Icons.settings, color: Colors.black),
          title: Text(
            FlutterI18n.translate(context, 'drawer.settings'),
            style: TextStyle(color: Colors.black, fontSize: itemFontSize),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
      ],
    ),
  );
}

