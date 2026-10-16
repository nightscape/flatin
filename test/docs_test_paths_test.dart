// Docs rot silently: a test path renamed in the tree stays in Markdown forever.
// Every test path a tracked Markdown file names must exist on disk.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The command and everything up to the end of the line or a shell comment.
final _command = RegExp(r'flutter test([^\n`#]*)');

/// A path in backticks or in a command word, under one of the two test roots.
final _codeSpan = RegExp(r'`([^`\n]+)`');

const _testRoots = ['test/', 'integration_test/'];

bool _looksLikeTestPath(String word) =>
    _testRoots.any((root) => word.startsWith(root));

/// Flag values (`macos` in `-d macos`, `oracle` in `--tags oracle`) carry no
/// slash, so they drop out without parsing the flags.
bool _looksLikePath(String word) =>
    !word.startsWith('-') && (word.contains('/') || word.endsWith('.dart'));

/// `test/features/*.feature` is a claim about the directory, not about a file.
String _upToTheGlob(String candidate) => candidate.contains('*')
    ? candidate.substring(0, candidate.indexOf('*'))
    : candidate;

void main() {
  final tracked = Process.runSync('jj', ['file', 'list']);
  if (tracked.exitCode != 0) {
    throw StateError('jj file list failed: ${tracked.stderr}');
  }
  final markdown = (tracked.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((path) => path.endsWith('.md'))
      .toList();

  test('the tracked Markdown files are visible to this test', () {
    expect(markdown, contains('CLAUDE.md'));
  });

  for (final path in markdown) {
    test('$path names only test paths that exist', () {
      final text = File(path).readAsStringSync();
      final named = <String>{};

      for (final match in _command.allMatches(text)) {
        named.addAll(match.group(1)!.split(RegExp(r'\s+')).where(_looksLikePath));
      }
      for (final match in _codeSpan.allMatches(text)) {
        named.addAll(match.group(1)!.split(RegExp(r'\s+')).where(
            (word) => _looksLikeTestPath(word.replaceAll(RegExp(r'[,.]$'), ''))));
      }

      final missing = named
          .map((word) => word.replaceAll(RegExp(r'[,.]$'), ''))
          .map(_upToTheGlob)
          .where((candidate) =>
              !File(candidate).existsSync() && !Directory(candidate).existsSync())
          .toList()
        ..sort();
      expect(missing, isEmpty, reason: '$path names paths that do not exist');
    });
  }
}
