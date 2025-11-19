# Latin Practice

A Flutter application for learning and practicing Latin vocabulary using spaced repetition. The app helps you master Latin noun declensions and verb conjugations through interactive practice sessions.

## Features

### Practice Modes

1. **Form Practice (Practice Screen)**
   - Practice conjugating/declining Latin words by typing the correct forms
   - Shows translation and base form (e.g., infinitive for verbs)
   - Input fields for each grammatical form (case, number, person, tense, etc.)
   - Real-time answer validation with visual feedback (green for correct, red for incorrect)
   - Supports customizable form selection - practice only the forms you want to focus on

2. **Word Classification (Wortklassifikation)**
   - Classify Latin words by selecting their grammatical properties
   - Shows a Latin word and asks you to identify its grammatical features
   - Supports multiple correct combinations (e.g., a word can be both nominative singular and accusative singular)
   - Visual feedback showing all correct classifications

### Content Types

- **Nouns (Deklination)**: Practice Latin noun declensions across all cases and numbers
- **Verbs (Konjugation)**: Practice Latin verb conjugations across persons, numbers, tenses, and moods

### Spaced Repetition System (FSRS)

- Uses the **FSRS (Free Spaced Repetition Scheduler)** algorithm for intelligent scheduling
- Automatically schedules review sessions based on your performance
- Shows count of due items for each content type
- Rating system: **Again**, **Hard**, **Good**, **Easy**
- Cards are automatically synced with vocabulary data from YAML files

### Customization

- **Settings Screen**: Enable or disable specific grammatical forms to practice
- Customize which forms appear in practice sessions for both nouns and verbs
- Settings are persisted across app sessions

### Data Management

- Vocabulary data stored in YAML files (`latin_nouns.yaml`, `latin_verbs.yaml`)
- Supports form inference from patterns (reduces manual data entry)
- Type inference based on word endings
- Automatic form generation from stems and patterns

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Dart SDK

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Building

- **Android**: `flutter build apk` or `flutter build appbundle`
- **iOS**: `flutter build ios`
- **macOS**: `flutter build macos`
- **Linux**: `flutter build linux`
- **Windows**: `flutter build windows`
- **Web**: `flutter build web`

## Project Structure

```
lib/
├── data/              # YAML vocabulary files and data loading logic
├── models/            # Data models (PracticeItem, FSRS card, Settings)
├── providers/         # Riverpod state management providers
├── screens/           # UI screens (Home, Practice, Settings, Word Classification)
├── services/          # Storage and persistence services
└── widgets/           # Reusable UI components
```

## Key Dependencies

- `flutter_riverpod`: State management
- `fsrs`: Spaced repetition algorithm
- `yaml`: YAML parsing for vocabulary data
- `shared_preferences`: Local storage for settings and FSRS cards

## Usage

1. **Start Practice**: Select "Nouns (Deklination)" or "Verbs (Konjugation)" from the home screen
2. **Practice Forms**: Type the correct forms for each grammatical category
3. **Check Answers**: Click "check" to validate your answers
4. **Rate Performance**: After checking, rate how well you knew the word (Again/Hard/Good/Easy)
5. **Word Classification**: Use "Wortklassifikation" to practice identifying grammatical properties
6. **Customize**: Go to Settings to enable/disable specific forms you want to practice

## Data Format

Vocabulary data is stored in YAML files with the following structure:
- Form definitions and labels
- Type patterns for form inference
- Individual vocabulary items with translations and forms
- Classification sections for word classification mode

## License

This project is for personal/educational use.
