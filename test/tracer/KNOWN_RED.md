# Known-red steps of the toy course tracer

`test/tracer/toy_course_boot_test.dart` boots the app with only the toy course
of `test/fixtures/toy_course/` (no Latin in it). Each step below fails today;
its line gives the first error of the step. Run the tracer with

    flutter test --tags tracer --run-skipped

A step that passes fails the tracer with "passes: mark it green": set its `red`
to false in `tracerSteps` and delete its line here. `test/tracer/toy_course_test.dart`
(default run) checks that this list names exactly the steps marked red. The
list only shrinks; when it is empty the app runs a course without Latin.

The test asset bundle (`test/tracer/toy_assets.dart`) answers the course list
`lib/data/courses.yaml` with `test/fixtures/toy_course/courses.yaml`; the toy
manifest names the toy files.

Every step boots the app, and the boot throws first: "the data ends at lesson
2, lastLesson says 40" (the `loadLessonData` assertion
`wholeCourse ? highest == lastLesson`, thrown building FocusPicker on the
home screen). Each line names that error and the
step's own failure after it.

- home: the data ends at lesson 2, lastLesson says 40; then the due words fail with the same error, so only the boot error is left
- round: the data ends at lesson 2, lastLesson says 40; then no round.start.go button, the round start screen shows the boot error
- settings: the data ends at lesson 2, lastLesson says 40; then the settings.tile.toy_words tile opens a grammar page that shows the boot error, so no form.toy_words.tu.ein
- exam-import: the data ends at lesson 2, lastLesson says 40; then the pack imports and is listed with the toy language, so only the boot error is left
