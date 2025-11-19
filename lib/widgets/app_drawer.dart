import 'package:flutter/material.dart';
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
        const DrawerHeader(
          decoration: BoxDecoration(
            color: Color(0xFFD0D0D0),
          ),
          child: Text(
            'Latin Practice',
            style: TextStyle(
              color: Colors.black,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.book, color: Colors.black),
          title: const Text(
            'Nomen (Deklination)',
            style: TextStyle(color: Colors.black, fontSize: 18),
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
                      return const Scaffold(
                        body: Center(child: Text('Error loading data')),
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
          leading: const Icon(Icons.auto_stories, color: Colors.black),
          title: const Text(
            'Verben (Konjugation)',
            style: TextStyle(color: Colors.black, fontSize: 18),
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
                      return const Scaffold(
                        body: Center(child: Text('Error loading data')),
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
          leading: const Icon(Icons.category, color: Colors.black),
          title: const Text(
            'Wortklassifikation',
            style: TextStyle(color: Colors.black, fontSize: 18),
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
          leading: const Icon(Icons.settings, color: Colors.black),
          title: const Text(
            'Einstellungen',
            style: TextStyle(color: Colors.black, fontSize: 18),
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

