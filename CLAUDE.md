# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Latin Practice — a Flutter app for learning Latin vocabulary (noun declensions, verb conjugations) using FSRS spaced repetition. UI language is German. Package name: `latin_practice`.

## Common Commands

```bash
flutter pub get                              # Install dependencies
flutter run                                  # Run the app
flutter analyze                              # Lint
flutter test                                 # Run unit tests
flutter test test/form_inference_test.dart    # Run a single test file
flutter test integration_test/               # Run integration tests

# Regenerate Riverpod code (after modifying @riverpod annotated providers)
dart run build_runner build --delete-conflicting-outputs

# Run Cucumber-style BDD tests
flutter test test/features/                  # Unit-level Cucumber tests

# Deploy (Fastlane)
cd android && fastlane release
cd ios && fastlane release
```

## Version Control

This project uses **Jujutsu** (`.jj` directory exists). Use `jj` commands, not `git`.

## Architecture

### Data Pipeline: YAML → PracticeItem → Screen

Vocabulary lives in YAML files (`lib/data/latin_nouns.yaml`, `lib/data/latin_verbs.yaml`). Each YAML file is self-describing: it contains form metadata (`form_labels`, `form_order`, `classification_sections`), type patterns for automatic form generation, type inference rules, and the vocabulary items themselves.

`practice_data.dart` loads YAML and performs **form inference**: given a word and its declension/conjugation type, it extracts a stem and generates all grammatical forms via pattern templates. This avoids manually specifying every form for every word. The inference system handles Latin diacritics (macrons like ā, ē) by normalizing them for comparison.

### State Management: Riverpod with code generation

Providers use `@riverpod` annotations and require generated `.g.dart` files. After changing any provider, run `dart run build_runner build --delete-conflicting-outputs`.

Key providers:
- `fsrs_provider.dart` — FSRS scheduling, due card computation, review logic
- `practice_providers.dart` — UI state for practice and word classification screens
- `settings_provider.dart` — persisted form enable/disable preferences

### FSRS Spaced Repetition

Cards are stored in SharedPreferences via `FsrsStorage`. On app start, cards sync with current YAML items (new items get new cards, existing cards keep their review history). Card identity is derived from the item's content via `PracticeItemCard.generateItemId()`.

### Screens

- **HomeScreen** — entry point, shows noun/verb practice with due counts
- **PracticeScreen** — form fill-in practice (type correct declension/conjugation forms)
- **WordClassificationScreen** — identify grammatical properties of a given word
- **SettingsScreen** — toggle which grammatical forms to practice

### i18n

Uses `flutter_i18n` with JSON translation files in `assets/flutter_i18n/` (en.json, de.json).

### Testing

- **Unit tests** (`test/`) — form inference validation against YAML data
- **Cucumber/BDD tests** (`test/features/`, `test/step_definitions/`) — uses `pickled_cucumber`
- **Integration tests** (`integration_test/`) — full app tests with screenshot capture for Fastlane

### Adding New Vocabulary

Add items to the appropriate YAML file under `items:`. If the word's type can be inferred from its ending (via `type_inference` rules) and its forms can be generated from `type_patterns`, you only need to specify `word` and `translation`. Otherwise provide `type` and/or explicit `forms`.

### Adding a New Declension/Conjugation Pattern

1. Add the pattern under `type_patterns` in the YAML file with `stem_extraction` and form templates
2. Add type inference rules under `type_inference` if the type can be guessed from word endings
3. Run `flutter test test/form_inference_test.dart` to verify inference works correctly
