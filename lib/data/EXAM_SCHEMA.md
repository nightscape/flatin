# Exam pack schema 1

An exam pack is one YAML file with the extension `.exam` (UTF-8). It holds a
Latin text to translate, its annotation, and the companion tasks. The app
imports a pack from a file; packs are never bundled. `test/fixtures/exam/synthetic.exam`
uses every feature.

The sections up to Tasks describe the fields. The codes of `analyse`,
`rolle`, `art` and `sinnrichtung`, and the values the rules name (`haupt`,
`pc`, `esse`, the tense pairs), are data of the language file
`lib/data/languages/la.yaml`; this document gives the Latin ones.
`lib/data/exam.dart` reads a pack and checks every statement of the section
Rules, one rule id per
statement; a pack that breaks one is refused as a whole with an `ExamError`
per break: the rule id and the path, e.g.
`E-token-twice exam.uebersetzung.saetze[3].teilsaetze[1]`. Paths count list
entries from 0.

## General

- Every field below is required unless it says optional. A required list may
  be empty unless it says non-empty.
- Ids are strings, because YAML reads `1.3` or `1_3` as a number. Shapes:
  sentence `s3`, token `s3_5` (its sentence id, `_`, a number), clause `s3b`
  (its sentence id and one letter), task `b2` (one letter and a number).

## Head

| Field | Value |
|---|---|
| `schema` | the int 1 |
| `id`, `titel` | string |
| `lektionen` | `{von, bis}`, ints: the first lesson of the block and the lesson of the focus |
| `schwerpunkte` | list of strings: app topic ids (`verbs:2`) and grammar section ids (`L2.1`) |
| `schwerpunkt`, `thema` | string: plain text for the PDF |
| `zeit_min` | int |
| `punkte_uebersetzung`, `punkte_gesamt` | int |
| `uebersetzung` | `{hilfen, saetze}` |
| `aufgaben` | list of tasks |

## Variant strings

`(a | b)` is a choice, `[x]` is optional, and groups nest: `(a | b [c])`. An
alternative may be empty: `(gern | oft |)`. Alternatives at the top level are
separate list entries. A reading has its runs of white space collapsed to one
space and is trimmed; a space before `, . ; : ! ? “` and a space after `„`
is removed, so a group next to such a mark leaves no gap. Variant strings are `teilsatz.de`, `satz.de`,
`ausrichtung[].de`, and `ziel` and `de` in tasks.

## Sentences: `uebersetzung.saetze[]`

`{id, tokens, teilsaetze, de}`. `de` is a non-empty list of variant strings:
the translation of the whole sentence; its first entry is the model
translation of the PDF.

### Tokens

A word token is `{id, la, lemma, analyse, rolle (optional), bezug
(optional), verbform (optional)}`. A token without `lemma` is a punctuation
mark.

- `analyse` has the keys and codes of `analyse` in the language file:
  `wortart` is required, the others are optional; the codes of `person` are
  numbers.
- `rolle`: a code of `rolle` in the language file. `attribut` is also an
  apposition, a genitive attribute, an adjectival `is`.
- `bezug`: the id of the token a word refers to.
- `verbform: [ppp id, esse id]`: a compound passive form (`portātus est`,
  `portātum esse`) is two tokens, the PPP and the `esse` token.
- A participium coniunctum is one token with `modus: part` in a clause of
  `art: pc`.

### Clauses: `teilsaetze[]`

`{id, art, tokens, uebergeordnet (optional), sinnrichtung (optional), de,
ausrichtung}`.

- `art`: a code of `clause.art` in the language file. `uebergeordnet` is
  the id of the superordinate clause.
- `tokens`: the tokens of the clause. A clause need not be contiguous (an
  embedded clause).
- `art: pc` is the participle with its complements. `sinnrichtung`: a code
  of `clause.sinnrichtung` in the language file.
- `de`: variant strings that translate the clause alone (a main clause in
  normal word order). For a pc clause they give the subordinate clause and,
  where it reads well, the prepositional phrase; `satz.de` adds the
  coordinated rendering.
- `ausrichtung`: `[{tokens, de}]`, the German of a group of tokens of the
  clause. The variant string may be empty (`-ne`). One entry may hold
  several tokens (`ā servō`, `portātae sunt`).

## Help: `uebersetzung.hilfen[]`

`{lemma, angabe, de, tokens}`: `angabe` is the dictionary entry
(`hortus, hortī m.`), `de` the meaning, `tokens` the ids of the tokens it
helps with. The list `hilfen` may be empty.

## Tasks: `aufgaben[]`

`{id, titel, punkte, art, frage, items, loesung}`: `punkte` an int, `loesung`
a list of PDF lines. Every task except `ordnen` and `frei` has a non-empty
list `items`, and every item has the int `punkte`. The items of each `art`:

| `art` | Item |
|---|---|
| `bestimmen` | `{token, merkmale}`: a token id and a list of strings; the answer comes from the token |
| `stammformen` | `{lemma, stammformen}`: `stammformen` exactly four strings |
| `bilden` | `{lemma, merkmale, form}`: `merkmale` holds the `analyse` keys that `form` of the language file names |
| `umformen` | `{vorgabe, ziel}`: `ziel` a non-empty list of variant strings |
| `vokabel` | `{la, de}`: `de` a non-empty list of variant strings |
| `ableitung` | `{fremdwort, la}` |
| `kurzantwort` | `{frage, stichwoerter}`: a non-empty list of non-empty lists of equivalent words; one word of each inner list must occur in the answer |
| `wissen_mc` | `{frage, teilsatz (optional), optionen, richtig}`: `optionen` non-empty, `teilsatz` a clause id |

`ordnen` has no `items` but `elemente`: strings in the right order; the app
shuffles them. `frei` has no `items`; the student checks it against
`loesung`.

## Rules

### File and fields

- [E-yaml] The file is well-formed YAML: no syntax error, no duplicate key,
  no tab in the indentation. The path is the line of the error.
- [E-schema] `schema` is 1.
- [E-field] Every required field is present and has a value; an optional
  field without a value counts as absent.
- [E-key] A field the sections above do not name is refused.
- [E-type] Every value has the type the sections above give it.
- [E-code] A code is one of its list in the language file.
- [E-empty] A list marked non-empty has at least one entry.
- [E-id-shape] Every id has the shape of its kind (section General).
- [E-id-twice] Sentence, token, clause and task ids are unique together.
- [E-variant] A variant string has balanced, uncrossed brackets and `|` only
  inside a group.
- [E-points-total] `punkte_gesamt` is `punkte_uebersetzung` plus the
  `punkte` of all tasks.

### Tokens

- [E-la-empty] The `la` of a token is not empty.
- [E-one-form] The `la` of a token is one form, without white space.
- [E-punctuation] A punctuation token is `{id, la}` only, and `la` has no
  letter or digit.
- [E-sentence-end] A `.`, `?` or `!` token lies in a clause without
  `uebergeordnet`.
- [E-rolle-none] A particle, a conjunction and a subjunction have no `rolle`.
- [E-ref-bezug] `bezug` is the id of a token of the same sentence.
- [E-bezug-missing] An `attribut`, a `praedikativum` and a relative pronoun
  have `bezug`.
- [E-person] A personal pronoun has `person`, and a participle (`modus:
  part`) has none.
- [E-verbform-missing] A verb with `genus_verbi: pass` and `tempus` `perf`,
  `plusq` or `fut2` that is not a participle has `verbform`.
- [E-ref-verbform] The ids of `verbform` are tokens of the same sentence.
- [E-verbform-both] `verbform` holds two ids, one of them the token's own,
  and both tokens have this `verbform` and `rolle: praedikat`.
- [E-verbform-pair] The first token of `verbform` is a word with
  `genus_verbi: pass` and a lemma other than `esse`, the second a word with
  `lemma: esse`.
- [E-verbform-esse] The `esse` token of the pair has `genus_verbi: akt`.
- [E-verbform-agree] The pair agrees: for a PPP with `modus: inf` the `esse`
  token is `inf` `praes`; otherwise `esse` has the same `person`, `numerus`
  and `modus`, and its `tempus` is `praes` for `perf`, `impf` for `plusq`,
  `fut` for `fut2`.
- [E-participle] A participle has no `verbform`, lies in a clause of `art:
  pc`, and its `bezug` lies outside that clause.
- [E-participle-kng] The `kasus`, `numerus` and `genus` of a participle equal
  those of its `bezug`.
- [E-ppp-kasus-genus] A PPP, a form with `genus_verbi: pass` and `tempus`
  `perf`, `plusq` or `fut2`, has `kasus` and `genus`.
- [E-participle-ppp] A participle has `tempus: perf` and `genus_verbi: pass`.

### Clauses

- [E-ref-clause-token] The `tokens` of a clause are tokens of its sentence.
- [E-token-twice] No token lies in two clauses.
- [E-token-no-clause] Every token of a sentence lies in a clause.
- [E-uebergeordnet] Every clause except `haupt` has `uebergeordnet`.
- [E-ref-uebergeordnet] `uebergeordnet` is the id of a clause of the same
  sentence.
- [E-pc] A pc clause has `sinnrichtung`, `uebergeordnet` and exactly one
  token with `modus: part`.
- [E-pc-rolle] The participle of a pc clause has `rolle: attribut` for
  `attributiv`, else `rolle: adverbiale`.
- [E-sinnrichtung] Only a pc clause has `sinnrichtung`.
- [E-ref-alignment] The `tokens` of an `ausrichtung` entry are tokens of its
  clause.
- [E-alignment] Every word token of a clause lies in exactly one of its
  `ausrichtung` entries, and no other token does.

### Help

- [E-ref-hilfe] The `tokens` of a hilfe are token ids.
- [E-hilfe-lemma] The tokens of a hilfe have its `lemma`.
- [E-hilfe-tokens] The tokens of a hilfe are all tokens of the text with its
  `lemma`.

### Tasks

- [E-points-task] The `punkte` of the items of a task sum to the task's
  `punkte`.
- [E-ref-item-token] The `token` of a `bestimmen` item is a token id.
- [E-merkmal] Each of the `merkmale` of a `bestimmen` item is `lemma`,
  `bezug` (the token has one) or a field of the token's `analyse`.
- [E-mc-richtig] `richtig` is one of the `optionen`.
- [E-ref-item-teilsatz] The `teilsatz` of a `wissen_mc` item is a clause id.
- [E-mc-sinnrichtung] With a `teilsatz`, `richtig` is the clause's
  `sinnrichtung`.
- [E-bilden-form] The `form` of a `bilden` item whose `merkmale` have
  `genus_verbi: pass`, `tempus` `perf`, `plusq` or `fut2` and no `modus:
  part` is two words (`spectātae sunt`).
- [E-ordnen] `ordnen` has at least three `elemente`.
