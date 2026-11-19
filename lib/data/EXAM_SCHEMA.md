# Exam pack schema 2

An exam pack is one YAML file with the extension `.exam` (UTF-8). It holds
tasks and, in a Latin pack, a Latin text to translate with its annotation. The app
imports a pack from a file; packs are never bundled. `test/fixtures/exam/synthetic.exam`
and `test/fixtures/exam/synthetic_en.exam` use every feature.

The sections up to Tasks describe the fields. The codes of `analysis`,
`role`, clause `type` and `sense`, and the values the rules name (`haupt`,
`pc`, `esse`, the tense pairs), are data of the language file
`lib/data/languages/la.yaml`; this document gives the Latin ones. The same
file holds the `fold` and `letters` of the spelling (SCHEMA.md, Course manifest).
`lib/data/exam.dart` reads a pack and checks every statement of the section
Rules, one rule id per
statement; a pack that breaks one is refused as a whole with an `ExamError`
per break: the rule id and the path, e.g.
`E-token-twice exam.translation.sentences[3].clauses[1]`. Paths count list
entries from 0. A pack with `schema: 1` has German keys; the loader converts
it to this schema first (section Schema 1), and its errors name the keys of
this schema.

## General

- Every field below is required unless it says optional. The Latin fields of
  the Head table are required together or not at all. A required list may
  be empty unless it says non-empty.
- Ids are strings, because YAML reads `1.3` or `1_3` as a number. Shapes:
  sentence `s3`, token `s3_5` (its sentence id, `_`, a number), clause `s3b`
  (its sentence id and one letter), task `b2` (one letter and a number).

## Head

| Field | Value |
|---|---|
| `schema` | the int 2 (a pack of schema 1 is converted first) |
| `id`, `title` | string |
| `course` | optional string: the id of the course the pack belongs to; without it the pack belongs to the first course of the list. The import refuses a pack of another course than the active one |
| `language` | optional string: the id of the language of the course that `course` names; a pack with `language` and no `course` is refused |
| `scope` | optional `{book, pages, grammar}`: what the exam covers; the app keeps the values as written |
| `time_min` | int |
| `points_total` | int |
| `tasks` | list of tasks |

The Latin group is all or none of `lessons`, `topics`, `focus`, `theme`,
`points_translation` and `translation`:

| Field | Value |
|---|---|
| `lessons` | `{from, to}`, ints: the first lesson of the block and the lesson of the focus |
| `topics` | list of strings: app topic ids (`verbs:2`) and grammar section ids (`L2.1`) |
| `focus`, `theme` | string: plain text for the PDF |
| `points_translation` | int |
| `translation` | `{glosses, sentences}` |

A pack without the group has no translation section: the exam screen lists
the tasks only and `points_total` is the sum of the task points. A pack with
the group lists the PDF `solution` of every task; a pack without it may leave
`solution` out.

## Variant strings

`(a | b)` is a choice, `[x]` is optional, and groups nest: `(a | b [c])`. An
alternative may be empty: `(gern | oft |)`. Alternatives at the top level are
separate list entries. A reading has its runs of white space collapsed to one
space and is trimmed; a space before `, . ; : ! ? “` and a space after `„`
is removed, so a group next to such a mark leaves no gap. Variant strings are
`clause.meaning`, `sentence.meaning`, `alignment[].meaning`, and `target` and
`answer` in tasks.

White space directly after `|` in the source is skipped. Each reading of the
choice before `|` loses its white space at the end. White space before `)` or
`]` is kept. Then each whole reading is normalized: runs of white space become
one space, no space before , . ; : ! ? “ or after „, and the ends are trimmed.
So `(hinab | hinunter)steigen` joins both alternatives to `steigen`, `[die ]Frau`
reads `die Frau`, and `(a | b )x` reads `ax` or `b x`. A space that all
alternatives need stands outside the group: `Mann (, | und) Frau`.
An empty alternative is allowed (`(fort | weg |)`, `(| ein | das)`); an
alternative that is only white space (`laid(-| )back`, `[ ]`) is refused
(rule E-variant): write the spaced form as its own entry.

## Sentences: `translation.sentences[]`

`{id, tokens, clauses, meaning}`. `meaning` is a non-empty list of variant strings:
the translation of the whole sentence; its first entry is the model
translation of the PDF.

### Tokens

A word token is `{id, text, lemma, analysis, role (optional), head
(optional), verb_form (optional)}`. A token without `lemma` is a punctuation
mark.

- `analysis` has the keys and codes of `analyse` in the language file (the
  keys of the language file are not renamed): `wortart` is required, the
  others are optional; the codes of `person` are numbers.
- `role`: a code of `rolle` in the language file. `attribut` is also an
  apposition, a genitive attribute, an adjectival `is`.
- `head`: the id of the token a word refers to.
- `verb_form: [ppp id, esse id]`: a compound passive form (`portātus est`,
  `portātum esse`) is two tokens, the PPP and the `esse` token.
- A participium coniunctum is one token with `modus: part` in a clause of
  `type: pc`.

### Clauses: `clauses[]`

`{id, type, tokens, parent (optional), sense (optional), meaning,
alignment}`.

- `type`: a code of `clause.art` in the language file. `parent` is
  the id of the superordinate clause.
- `tokens`: the tokens of the clause. A clause need not be contiguous (an
  embedded clause).
- `type: pc` is the participle with its complements. `sense`: a code
  of `clause.sinnrichtung` in the language file.
- `meaning`: variant strings that translate the clause alone (a main clause in
  normal word order). For a pc clause they give the subordinate clause and,
  where it reads well, the prepositional phrase; `sentence.meaning` adds the
  coordinated rendering.
- `alignment`: `[{tokens, meaning}]`, the German of a group of tokens of the
  clause. The variant string may be empty (`-ne`). One entry may hold
  several tokens (`ā servō`, `portātae sunt`).

## Help: `translation.glosses[]`

`{lemma, grammar, meaning, tokens}`: `grammar` is the dictionary entry
(`hortus, hortī m.`), `meaning` the meaning, `tokens` the ids of the tokens it
helps with. The list `glosses` may be empty.

## Tasks: `tasks[]`

`{id, title, points, type, prompt, text, listening, items, solution}`:
`points` an int, `prompt` a string that every task except `writing` has,
`solution` a list of lines (see the Head table for when it is required).
Optional on every task except `writing`:

- `text`: Markdown shown above the items. The app renders paragraphs
  (separated by a blank line), `**bold**`, `*italic*` and `{{n}}` markers
  only.
- `listening`: `{repeat, voices, lines}`: `repeat` an int, `voices` a map of
  speaker to voice name, `lines` a list of `[speaker, text]` pairs. The app
  plays no audio: it shows a line that points to the HTML page of the exam,
  and the script `lines` with the solution.

A `vocab` task also has `direction`: `la-de`, `de-en` or `en-de`. A
`gap_fill` task may have `word_box`, a list of strings shown above the gaps.
Every task except `order`, `free` and `writing` has a non-empty list `items`,
and every item has the int `points` and may have `source`, a string: a
revision reference such as `S183`. The `source` of a `derivation` item is its
Latin word. The items of each `type`:

| `type` | Item |
|---|---|
| `analyze` | `{token, features}`: a token id and a list of strings; the answer comes from the token |
| `principal_parts` | `{lemma, principal_parts}`: `principal_parts` exactly four strings |
| `form` | `{lemma, features, form}`: `features` holds the `analyse` keys that `form` of the language file names |
| `transform` | `{given, target}`: `target` a non-empty list of variant strings |
| `vocab` | `{prompt, answer}`: `answer` a non-empty list of variant strings |
| `derivation` | `{loanword, source}` |
| `short_answer` | `{prompt, keywords, answer}`: `keywords` a non-empty list of non-empty lists of equivalent words, one word of each inner list must occur in the answer; `answer` a non-empty list of variant strings, the model answer. An item has at least one of the two |
| `multiple_choice` | `{prompt, clause (optional), options, correct}`: `options` non-empty, `clause` a clause id |
| `gap_fill` | `{sentence (optional), answer}`: `answer` a non-empty list of variant strings; see below |

`order` has no `items` but `elements`: strings in the right order; the app
shuffles them. `free` has no `items`; the student checks it against
`solution`.

A `gap_fill` task has one gap per item, in one of two styles. In the marker
style the task `text` holds `{{1}}`, `{{2}}`, ... in order, one per item, and
no item has a `sentence`. In the sentence style no marker occurs and each
item has a `sentence` with `___` at the gap. The app checks the gaps: an
input is right when it equals a reading of one `answer` variant after the
answer rules of the language file (`fold`, white space, the case of the first
letter) apply to both.

A `writing` task has `{id, title, points, type, situation, requirements,
words, rubric, model_answer}` and no `prompt`, `text`, `listening`, `items` or
`solution`. `situation` is a string; `requirements` and `model_answer` are a
string or a list of strings; `words` is `{min, max}`, ints; `rubric` is a
list of `{criterion, points}`. The student writes in the app, which counts
the words, and marks each rubric line after the model answer is shown; the
earned points are the sum of the marked lines.

A task of any other type earns its `points` when the student marks it done,
except `analyze` (dropdown checks) and `gap_fill` (the `points` of each right
gap).

## Rules

### File and fields

- [E-yaml] The file is well-formed YAML: no syntax error, no duplicate key,
  no tab in the indentation. The path is the line of the error.
- [E-schema] `schema` is 1 or 2; a schema-1 pack is converted first (section
  Schema 1).
- [E-field] Every required field is present and has a value; an optional
  field without a value counts as absent. `language` is the id of the
  language of the course `course` names, and needs `course`.
- [E-latin-group] The Latin group of the Head table is all present or all
  absent.
- [E-key] A field the sections above do not name is refused.
- [E-type] Every value has the type the sections above give it.
- [E-code] A code is one of its list in the language file.
- [E-empty] A list marked non-empty has at least one entry.
- [E-id-shape] Every id has the shape of its kind (section General).
- [E-id-twice] Sentence, token, clause and task ids are unique together.
- [E-variant] A variant string has balanced, uncrossed brackets and `|` only
  inside a group; no alternative is only white space.
- [E-points-total] `points_total` is `points_translation` (0 without the
  Latin group) plus the `points` of all tasks.

### Tokens

- [E-la-empty] The `text` of a token is not empty.
- [E-one-form] The `text` of a token is one form, without white space.
- [E-punctuation] A punctuation token is `{id, text}` only, and `text` has no
  letter or digit.
- [E-sentence-end] A `.`, `?` or `!` token lies in a clause without
  `parent`.
- [E-rolle-none] A particle, a conjunction and a subjunction have no `role`.
- [E-ref-bezug] `head` is the id of a token of the same sentence.
- [E-bezug-missing] An `attribut`, a `praedikativum` and a relative pronoun
  have `head`.
- [E-person] A personal pronoun has `person`, and a participle (`modus:
  part`) has none.
- [E-verbform-missing] A verb with `genus_verbi: pass` and `tempus` `perf`,
  `plusq` or `fut2` that is not a participle has `verb_form`.
- [E-ref-verbform] The ids of `verb_form` are tokens of the same sentence.
- [E-verbform-both] `verb_form` holds two ids, one of them the token's own,
  and both tokens have this `verb_form` and `role: praedikat`.
- [E-verbform-pair] The first token of `verb_form` is a word with
  `genus_verbi: pass` and a lemma other than `esse`, the second a word with
  `lemma: esse`.
- [E-verbform-esse] The `esse` token of the pair has `genus_verbi: akt`.
- [E-verbform-agree] The pair agrees: for a PPP with `modus: inf` the `esse`
  token is `inf` `praes`; otherwise `esse` has the same `person`, `numerus`
  and `modus`, and its `tempus` is `praes` for `perf`, `impf` for `plusq`,
  `fut` for `fut2`.
- [E-participle] A participle has no `verb_form`, lies in a clause of `type:
  pc`, and its `head` lies outside that clause.
- [E-participle-kng] The `kasus`, `numerus` and `genus` of a participle equal
  those of its `head`.
- [E-ppp-kasus-genus] A PPP, a form with `genus_verbi: pass` and `tempus`
  `perf`, `plusq` or `fut2`, has `kasus` and `genus`.
- [E-participle-ppp] A participle has `tempus: perf` and `genus_verbi: pass`.

### Clauses

- [E-ref-clause-token] The `tokens` of a clause are tokens of its sentence.
- [E-token-twice] No token lies in two clauses.
- [E-token-no-clause] Every token of a sentence lies in a clause.
- [E-uebergeordnet] Every clause except `haupt` has `parent`.
- [E-ref-uebergeordnet] `parent` is the id of a clause of the same
  sentence.
- [E-pc] A pc clause has `sense`, `parent` and exactly one
  token with `modus: part`.
- [E-pc-rolle] The participle of a pc clause has `role: attribut` for
  `attributiv`, else `role: adverbiale`.
- [E-sinnrichtung] Only a pc clause has `sense`.
- [E-ref-alignment] The `tokens` of an `alignment` entry are tokens of its
  clause.
- [E-alignment] Every word token of a clause lies in exactly one of its
  `alignment` entries, and no other token does.

### Help

- [E-ref-hilfe] The `tokens` of a gloss are token ids.
- [E-hilfe-lemma] The tokens of a gloss have its `lemma`.
- [E-hilfe-tokens] The tokens of a gloss are all tokens of the text with its
  `lemma`.

### Tasks

- [E-points-task] The `points` of the items of a task sum to the task's
  `points`.
- [E-ref-item-token] The `token` of an `analyze` item is a token id.
- [E-merkmal] Each of the `features` of an `analyze` item is `lemma`,
  `bezug` (the token has a `head`) or a field of the token's `analysis`. The
  two names `lemma` and `bezug` are the same in schema 1.
- [E-mc-richtig] `correct` is one of the `options`.
- [E-ref-item-teilsatz] The `clause` of a `multiple_choice` item is a clause id.
- [E-mc-sinnrichtung] With a `clause`, `correct` is the clause's
  `sense`.
- [E-bilden-form] The `form` of a `form` item whose `features` have
  `genus_verbi: pass`, `tempus` `perf`, `plusq` or `fut2` and no `modus:
  part` is two words (`spectātae sunt`).
- [E-ordnen] `order` has at least three `elements`.
- [E-gap-style] A `gap_fill` task uses one style: with `{{n}}` markers in the
  `text` no item has a `sentence`; without markers every item has a
  `sentence` with `___`.
- [E-gap-marker-order] The markers of the `text` read `{{1}}`, `{{2}}`, ... in
  order.
- [E-gap-marker-count] The `text` has as many markers as the task has items.
- [E-writing-words] `words.min` is at most `words.max`.
- [E-writing-rubric] The `points` of the `rubric` lines sum to the task's
  `points`.

## Schema 1

A pack with `schema: 1` has German keys. `convertSchema1`
(`lib/data/exam_conversion.dart`) renames them as below and sets `schema: 2`;
the loader reads the result. A key not in the table is refused as an unknown
field. Codes from the language file and the values `lemma` and `bezug` in
`features` stay as they are.

| Schema 1 | Schema 2 |
|---|---|
| `titel`, `kurs`, `thema`, `schwerpunkt`, `schwerpunkte` | `title`, `course`, `theme`, `focus`, `topics` |
| `lektionen{von, bis}` | `lessons{from, to}` |
| `zeit_min`, `punkte_uebersetzung`, `punkte_gesamt` | `time_min`, `points_translation`, `points_total` |
| `uebersetzung{hilfen, saetze}` | `translation{glosses, sentences}` |
| gloss `angabe`, `de` | `grammar`, `meaning` |
| sentence `teilsaetze`, `de` | `clauses`, `meaning` |
| token `la`, `analyse`, `rolle`, `bezug`, `verbform` | `text`, `analysis`, `role`, `head`, `verb_form` |
| clause `art`, `uebergeordnet`, `sinnrichtung`, `de`, `ausrichtung` | `type`, `parent`, `sense`, `meaning`, `alignment` |
| `aufgaben`, task `titel`, `punkte`, `art`, `frage`, `loesung`, `elemente` | `tasks`, `title`, `points`, `type`, `prompt`, `solution`, `elements` |
| task `art` values `bestimmen`, `stammformen`, `bilden`, `umformen`, `vokabel`, `ableitung`, `kurzantwort`, `wissen_mc`, `ordnen`, `frei` | `analyze`, `principal_parts`, `form`, `transform`, `vocab`, `derivation`, `short_answer`, `multiple_choice`, `order`, `free` |
| item `merkmale`, `stammformen`, `punkte` | `features`, `principal_parts`, `points` |
| item `vorgabe`, `ziel` | `given`, `target` |
| vocab item `la`, `de` | `prompt`, `answer`; the task gets `direction: la-de` |
| derivation item `fremdwort`, `la` | `loanword`, `source` |
| item `frage`, `stichwoerter`, `optionen`, `richtig`, `teilsatz` | `prompt`, `keywords`, `options`, `correct`, `clause` |
