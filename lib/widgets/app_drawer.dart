import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import '../screens/practice_screen.dart';
import '../screens/word_classification_screen.dart';
import '../screens/settings_screen.dart';
import '../data/practice_data.dart';
import '../models/practice_item.dart';

Widget buildAppDrawer(BuildContext context) {
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
            style: const TextStyle(
              color: Colors.black,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          key: const Key('drawer.nouns'),
          leading: const Icon(Icons.book, color: Colors.black),
          title: Text(
            FlutterI18n.translate(context, 'drawer.nouns'),
            style: const TextStyle(color: Colors.black, fontSize: 18),
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
            style: const TextStyle(color: Colors.black, fontSize: 18),
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
            style: const TextStyle(color: Colors.black, fontSize: 18),
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
            style: const TextStyle(color: Colors.black, fontSize: 18),
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

