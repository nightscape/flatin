# Known-red steps of the toy course tracer

`test/tracer/toy_course_boot_test.dart` boots the app with only the toy course
of `test/fixtures/toy_course/` (no Latin in it). Each step below fails today;
its line gives the first error of the step. Run the tracer with

    flutter test --tags tracer --run-skipped

A step that passes fails the tracer with "passes: mark it green": set its `red`
to false in `tracerSteps` and delete its line here. `test/tracer/toy_course_test.dart`
(default run) checks that this list names exactly the steps marked red. The
list only shrinks; when it is empty the app runs a course without Latin.

The toy files answer the app's Latin asset paths through a test asset bundle
(`test/tracer/toy_assets.dart`). I2 (#383) moves this injection to the course
manifest list.

Every step boots the app, and the boot throws first: "the data ends at lesson
2, lastLesson says 40" (the `loadLessonData` assertion
`wholeCourse ? highest == lastLesson`, thrown building FocusPicker on the
home screen). Each line names that error and the
step's own failure after it.

- home: the data ends at lesson 2, lastLesson says 40; then the due words fail with Unable to load asset: "lib/data/latin_verbs.yaml" (the app reads its three data files by fixed path)
- round: the data ends at lesson 2, lastLesson says 40; then no round.start.go button, the round start screen shows Unable to load asset: "lib/data/latin_verbs.yaml" (the app reads its three data files by fixed path)
- settings: the data ends at lesson 2, lastLesson says 40; then no settings.tile.toy_words tile, the settings screen offers only the fixed tiles Words, Nouns, Verbs and Input
- exam-import: the data ends at lesson 2, lastLesson says 40; then the pack is refused: exam.uebersetzung.saetze[0].tokens[0].analyse.wortart (E-code): "wortklasse" is not one of [Wortart.subst, ...] (the exam analysis codes are Dart enums)
