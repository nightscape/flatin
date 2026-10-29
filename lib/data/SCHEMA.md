# Grammar data schema 3.2

A data file describes one word class: its feature axes, how a label reads, the
principal parts an item gives, the declension or conjugation types, and the
items themselves. `lib/grammar/schema.dart` reads and checks a file;
`lib/models/form_label.dart` holds the axes and labels. Nothing here generates
forms — the engine does that, and every rule below is checked at load time, so
a mistake in the data throws a `SchemaError` instead of reaching the learner.

A feature **key** is the value codes of a feature bundle in axis declaration
order, joined by `.`: `ind.praes.akt.1.sg`, `gen.sg.m.komp`. A key carries no
axis names, because a code names only one axis (S1).

## File structure

```yaml
data_file_id: verbs                  # 'nouns' | 'verbs'; part of a card id

axes:                                # declaration order = key order = label order
  modus:                             # S20: every learner text is {de, en}
    name: {de: Modus, en: Mood}
    values: {ind: {de: Indikativ, en: Indicative}, ...}
    hidden_in_label: [ind]           # codes a label does not name

label:
  head: [modus, tempus, genus_verbi] # axes before the colon
  tail: [person, numerus]            # axes after it
  merge_axis: person                 # the axis describeLabels joins with "/"
  overrides:                         # S17
    - {when: {modus: [inf, part]}, axis: tempus,
       values: {fut: {de: Futur, en: Future}}}

parts:                               # the principal parts an item may give
  infinitiv:    {label: {de: Infinitiv, en: Infinitive},
                 key: inf.praes.akt}   # the keys that hold it, first one an item has wins
  praefix:      {label: {de: Präfix, en: Prefix}, display: false}

defaults:
  given_part: praesens_1sg           # the form the practice screen shows
  lemma_part: infinitiv              # the lesson key and the card id
  base_forms: [ind.perf.akt.1.sg]    # asked by the base-forms focus, with every
                                     # displayed part and every irregular form

type_inference:                      # S11; keyed by part, rules in list order
  infinitiv:
    - {suffix: "āre", types: [A-Konjugation]}
    - {suffix: "ere", min_length: 5, types: [Konsonantische, Mischkonjugation]}

sandhi:                              # S16; the file's rule library
  kurz_nt: {end: vowel, before: [nt, nd], replace: short,
            explain: {de: "Vokal vor nt/nd wird kurz",
                      en: "a vowel before nt/nd is short"}}

classes: [konjugation]               # S19; the word classes types may name

types:
  Verb-Basis:
    abstract: true                   # no item uses it, so no class or display

  A-Konjugation:
    class: konjugation               # S19; every concrete type names one
    display: {de: A-Konjugation, en: 1st conjugation}  # S20
    inherits_from: Verb-Basis        # S6
    required_stems: [praesens]       # S4
    stems:
      wurzel:   {from: infinitiv, remove: [āre, ārī],
                 display: {de: Verbstamm, en: Verb stem}}
      praesens: {template: "{wurzel}ā",
                 display: {de: Präsensstamm, en: Present stem}}
      perfekt:  {from: perfekt_1sg, remove: "ī", default: "{praesens}v"}
    forms:
      ind.praes.akt.1.sg: "{praesens}ō"
      abl.sg:             ["{stamm}ī", "{stamm}e"]   # S9: variants
    delegate:                        # S14
      - {name: ppp, type: a-o-Endungen, bind: {stamm: ppp},
         set: {modus: part, tempus: perf, genus_verbi: pass}, emit: true}
    compose:                         # S13
      - match: {tempus: [perf, plusq, fut2], genus_verbi: pass}
        join: " "
        parts:
          - {self: ppp, pass: [numerus], set: {kasus: nom, genus: m}}
          - {lexeme: esse, pass: [modus, person, numerus],
             map: {tempus: {perf: praes, plusq: impf, fut2: fut}}}
      - match: {tempus: perf, genus_verbi: akt}
        variant: true                # S24: adds accepted texts only
        join: " "
        parts:
          - {slot: reflexiv, optional: true}  # S22, S23
          - {stem: partikel, join: ""}        # S21: the text after this part
          - {self: roh, pass: [person, numerus]}
    slots: {hilfsverb: hv_haben}     # S23: default item of a slot
    sandhi: [a_ausfall, kurz_nt]     # rule ids of this file, in this order
    deponent: all                    # S10; or a list of tempus codes

shared:                              # YAML anchors items alias; nothing reads it
  ohne_steigerung: &ohne_steigerung [{grad: komp}, {grad: sup}]

items:
  - type: Unregelmäßig               # omitted when inference decides (S11)
    id: esse                         # defaults to the normalized lemma
    translation: {de: sein, en: be}
    parts: {infinitiv: esse, perfekt_1sg: fuī}
    forms: {ind.praes.akt.1.sg: sum} # overrides
    deponent: [perf, plusq, fut2]
    regular_type: Konsonantische     # S27
    absent: [{modus: imp}]           # S15
    slots: {hilfsverb: hv_sein}      # S23
```

One file is exactly one YAML document; a `---` separated second document throws.

The top-level keys above are the whole set: `data_file_id`, `axes`, `label`,
`parts`, `defaults`, `type_inference`, `sandhi`, `classes`, `types`, `items`,
`shared`.
Any other one throws, so a typo such as `itemss:` fails the load instead of
silently dropping the section. `shared:` is the one key the loader only
accepts: it holds anchors that items alias (`absent: *ohne_steigerung`), and it
sits above `items:` because a YAML alias resolves only below its anchor.

Loading a file resolves which keys every item has — `GrammarFile.keysByItem`,
one `ItemKeys` per item, after S4, S10, S13, S14 and S15. That set is the
contract between this library and the engine: the engine generates a form for
exactly those keys, and it plans no keys of its own.

## Rules

**S1. Codes.** A value code is declared by exactly one axis of a file. A key
lists codes in axis declaration order; a key written in another order is not
canonical and throws.

**S2. Templates.** A form or stem template is either a literal or
`{<stem>}<ending>`: one placeholder, at the start. The stem must be one the
type declares (after S6, and after `bind` for a delegate target, S14).

**S3. `remove`.** One suffix or a list. The first suffix in list order that
matches macron-insensitively is cut from the item's own spelling; if none
matches, load throws. The stem keeps the item's macrons, so `remove: [āre, ārī]`
serves both `amāre` and `hortārī`.

**S4. Missing parts.** A stem with `from` and no `default` is unavailable when
the item does not give that part, and every form that uses it is then absent. A
stem listed in `required_stems` must be available for every item of the type,
else load throws.

**S5. Acyclicity.** Inheritance, stem templates, delegation and composition form
an acyclic graph. `lexeme:` and a filled `slot:` (S23) name an item `id` of the
same file, and an item's forms must not depend on that same item.

**S6. `inherits_from`.** Parent first; the child wins per stem name, per key and
per delegate `name`. `compose` lists append, a child's `sandhi` list replaces
the parent's when present, and the child's `deponent` wins. A missing parent
throws.

**S7. Key order.** First by axis order, then by value order inside each axis; an
absent axis sorts before any value.

**S8. `emit`.** Delegated forms with `emit: false` are internal: compositions
and the oracle may use them, the learner never practises them and they do not
show in the settings. Composed forms are always emitted.

**S9. Variants.** A list value holds at least two spellings, and no two of them
are equal after normalizing quantity marks — a list holds different words, never
different spellings of one word. The first is shown and traced, all are
accepted. Variants come from a template list, a part list, a composition (the
product of its parts' variants), a `variant: true` compose rule (S24) or a
`variant: true` sandhi rule. An item
override list replaces the whole list.

**S10. Deponents.** Let D be the item's `deponent`, else the type's; `all` means
every tempus. A key with `genus_verbi: pass` moves to the same key with
`genus_verbi: akt` if

- `modus` is `ind`, `konj` or `imp` and `tempus` is in D, or
- `modus: inf` and `tempus` is `praes` or `perf` and in D, or
- `modus: part`, `tempus: perf` and `perf` is in D.

Every other passive key is dropped. An active key is dropped under the first two
conditions, also when no passive form takes its place. Keys without
`genus_verbi` and `inf.fut.akt` stay. The move happens as soon as a key is made
and before item overrides, so an override names the key the learner sees
(`ind.praes.akt.1.sg` for `hortor`).

**S11. Type inference.** Parts are tried in `type_inference` order and rules in
list order; the first match over all parts wins. A suffix with a macron matches
only a spelling with the same macrons (`ēre` matches `monēre`, not `capere`); a
macron-free suffix matches macron-insensitively, and `min_length` is the least
length of the spelling. If the matched rule offers more than one type, the item
must give `type`. An item's `type` always wins over the rules.

**S12. Type names.** They are unique across all data files. An item's `type`,
given or inferred, names a type of its own file, because the item's keys are
written in that file's axes; only `inherits_from` and `delegate.type` reach
across files. The delegating file must declare every code of a delegated key, on
the same axis as the target's file — it then writes the key again in its own
axis order.

**S13. Composition.** A compose rule makes keys over the axes named in `match`
plus every axis a part names in `pass` or `map`. An axis in `match` takes the
listed codes, any other axis every code of the axis. With `pass: all` the keys
are instead the lexeme's own keys, emitted and internal, that agree with
`match`; `map` is not allowed with it. A key is emitted only if every part
resolves — one absent part that is not optional (S22) removes it. A part is
`self:` (a delegate of the same type), `lexeme:` (an item), `slot:` (the item a
slot names, S23) or `stem:` (an affix; it takes no `set`, `pass` or `map`).
A rule takes only the keys `match`, `join`, `parts` and `variant`; a part only
its kind and `set`, `pass`, `map`, `join`, `optional`, and on a `stem:` part `sandhi`, `glue_before`. The looked-up key is `set` plus the passed codes plus the mapped codes;
an axis in `map` is passed implicitly and a code the table does not list passes
unchanged. `pass: all` is only allowed on `lexeme:`.

**S14. Delegation.** A delegate target is a leaf type: no `delegate`, no
`compose`. It sees only the stems in `bind`, its own `stems` are ignored, and a
target template whose stem is not bound throws. The axes in `set` must not occur
in the target's keys. `name` is required.

**S15. `absent`.** A generated key that has all features of one pattern is not
emitted. Each pattern must remove at least one key and must not remove a key the
item overrides.

**S16. Sandhi rules.** The file's `sandhi:` map is the rule library; a type lists
rule ids in the order they are tried, and an unknown id throws. A rule has
`end`, `before`, `replace`, `explain` (the text the explanation shows, S20)
and optionally `variant`. It matches a seam (S18) on normalized text:

- `end`: a letter string the left side ends with, or `vowel` / `consonant` (its
  last letter). Letters are a–z, the Latin quantity marks and `ä ö ü ß`.
- `before`: `vowel` / `consonant` (the right side's first letter; the right side
  is not empty), or a list whose entry `p` matches when the right side starts
  with `p`, and whose entry `p$` matches only at a word-final seam and only when
  the right side equals `p` (`"$"` is the empty ending).
- `replace`: a literal replaces the last n letters of the left side, quantity
  marks included (n is the length of `end`, 1 for a class); `short` removes the
  quantity mark of the left side's last letter; `double_next` is the right
  side's first letter; `drop_next` keeps the left side and removes the matched
  `before` entry from the right side (it needs a `before` list, else load
  throws; where it matches at a seam after a `stem:` part it throws).

The first matching rule applies, at most one per seam, and only `drop_next`
changes the right side. A rule whose output equals its input is not recorded. With
`variant: true` both spellings are produced; the shown one is the one whose left
side agrees with the start of the item's lemma part.

**S17. Label overrides.** An entry
`{when: {<axis>: <code> | [<codes>]}, axis: <axis>, values: {<code>: <text>}}`
changes only the display text of one value inside a label whose features match
`when`; the first matching entry wins. It changes no key, no code and no axis
selector text.

**S18. Seams.** A type's `sandhi` list applies at every form template `{s}e`
(left: each variant of stem `s`, right: `e`, word-final), at every stem
`default` or `template` `{b}r` (left: each variant of `b`, right: `r`, not
word-final), and after every `stem:` part of a composition (left: the affix,
right: the next part's text, not word-final; when the separator after the affix
is not empty, or the affix is the last part, the seam is word-final with an
empty right side). It applies inside delegated
templates too, since delegate targets have no list of their own. Present stems
are school stems (`amā-`, `monē-`, `audī-`, `capi-`, `reg-`), built as root plus
theme vowel, so the quantity change at the seam is data: `amā` + `ō` → `amō`,
`capi` + `re` → `capere`. A `stem:` part with `sandhi: false` has no sandhi at
the seam after it: a German particle stays as written (`mit` + `teile` →
`mitteile`), while sandhi inside the verb still applies (`arbeit` + `t` →
`arbeitet`). Only a `stem:` part takes `sandhi`; on any other part it throws
(S13).

**S19. Word class.** `classes:` lists the word classes of a file, and every
concrete type names one of them in `class:` — the class a learner weighs its
types against, so the ESEL Erkennen step draws its distractors from it. A
concrete type without `class`, a class the file does not list, and a `class` on
an abstract type each throw, naming the type and the file.

**S20. Languages.** Every text a learner reads — an axis `name`, a value text
(also in a label override), a part `label`, a stem `display`, a sandhi
`explain`, a type `display` and an item `translation` — is a map from each data
language (`dataLanguages` in `lib/grammar/schema.dart`) to a non-empty text. A
plain string, a missing or extra language and an empty text each throw. A
parse picks one language; ids, codes and type names stay the same in every
language. Every concrete type has a `display`, an abstract one has none, and
no two types of a file share a display in one language.

**S21. Separators.** A rule's `join` is the default text between two parts. A
part's own `join` is the text between it and the next present part, so one
rule can join a particle to the verb without a space and the pronoun with one.
The last part takes no `join`; one there throws. A `stem:` part with
`glue_before: <stem>` joins with `""` and takes no sandhi when the next present
part is that stem; the name must be a `stem:` part later in the same rule, else
it throws.

**S22. Optional parts.** A part with `optional: true` that has no form drops out
together with its own separator; the key stays. A rule whose parts are all
optional throws.

**S23. Slots.** A `slot: <name>` part reads the item that the composing item
names in `slots: {<name>: <item id>}`, else the one its type names in `slots:`
(inherited, the child wins per name). A slot no one fills has no form, so the
part removes the key unless it is optional. An item slot that no compose part of
its type reads throws.

**S24. Variant rules.** A compose rule with `variant: true` makes no key of its
own: its texts follow, as accepted variants, the texts of the rule that makes
the key, and the shown text, the parts and the trace stay those of that rule. A
variant rule that would make a key no other rule of the type makes throws.

**S25. Impersonal passive.** An item with `passiv: unpersönlich` has only the
impersonal passive: its passive keys with `person: 1`, `person: 2` or
`person: 3, numerus: pl` are absent (S15). A `self` part of a composed passive
key that sets `genus` reads the neuter (`ventum est`), and its delegated passive
keys are internal (S8). Any other value, and the key on a deponent, throws.

**S26. Genus.** A type may give `genus: <code>` (inherited, the child wins), an
item `genus: <code>` or a list of codes for a noun of common gender
(`cūstōs: [m, f]`); a code is one of the axis `genus`. Once a type of a class
gives a genus, every item of that class has exactly one source of it: its
type's or its own. An item of any other class gives none. A missing, doubled or
unknown genus throws.

**S27. Regular reading.** `regular_type: <type>` names another concrete type
of the file. The item is read once more as that type, with its parts and
without its forms; a form of the item counts as irregular for the base-forms
focus only when this reading has no form for its key or writes it otherwise
(`ferre` read as Konsonantische: `ferimus` is regular, `fers` is not).
`regular_passiv: unpersönlich` gives only this reading the impersonal passive
of S25 (`īre`: `itum est` is regular); the item's own keys stay as they are.
A gerund form spelled like the neuter singular of the gerundive in its case
follows from the gerundive and is not irregular (`abeundī`).

**Collisions.** A key produced twice — by own forms, by delegation or by
composition other than a variant rule (S24) — throws. There is no precedence between them; inheritance (S6) is
the only override mechanism besides item overrides.

# Sentence corpus

`lib/data/sentences.yaml` holds short Latin sentences for sentence exercises;
`lib/data/sentences.dart` reads it. The loader checks the shape;
`test/sentence_corpus_test.dart` checks every sentence against the grammar
engine and the course books.

```yaml
sentences:
  - id: l25-ppp-1              # unique
    lesson: 25                 # words and grammar stay within lessons 1..25
    latin: "Mīlitēs ab hostibus captī pācem petīvērunt."
    tokens:                    # the words of `latin`, in order
      - [mīlitēs, mīles, nom.pl]                    # text, item lemma, form key
      - [ab]                                        # a lesson headword
      - [hostibus, hostis, abl.pl]
      - [captī, capere, part.perf.pass.pl.nom.m]
      - [pācem, pāx, akk.sg]
      - [petīvērunt, petere, ind.perf.akt.3.pl]
    construction:
      kind: pcPpp              # frageNe | frageNonne | frageNum | aciPassiv
                               # | pcPpa | pcPpp | doppelterAkkusativ
      head: 3                  # token index: participle, question particle
                               # or predicative accusative
      reference: 0             # token index of its reference word; none for
                               # a question
      meaning: [temporal, kausal]  # Sinnrichtung, exactly for pcPpa / pcPpp:
                                   # temporal | kausal | konzessiv | modal
    right:                     # 2-4 right German renderings
      - "Nachdem die Soldaten … gefangen genommen worden waren, baten sie um Frieden."
    wrong:                     # 2-3 renderings, wrong under every reading
      - {de: "…, während sie … gefangen genommen wurden.", mistake: tempus}
```

A token is `[text, lemma, key]` when the engine has an item with that lemma:
`text` must be one of the spellings of form `key` (case aside). A token is
`[text]` or `[text, headword]` only for a lesson headword that is no engine
item (et, in, `-ne`): `text` is the headword or one of its words. A
vocabulary item's one form is `grund` (`[nōnne, nōnne, grund]`). An
enclitic token starts with `-` and is written onto the word before it in
`latin`.

`mistake` is one of `tempus` (wrong tense or time relation), `genusVerbi`
(active and passive swapped), `bezugswort` (wrong reference word),
`sinnrichtung`, `frageart` (wrong expected answer), `aussage` (statement
instead of question), `rollen` (subject, object or predicate swapped),
`praedikativum` (second accusative not read as predicate).

The data test fails a sentence when a token is no form of its item, when an
item, headword, form or type is taught after `lesson`, when a headword token
names a word the engine has an item for, when the tokens do not spell
`latin`, when a participle does not agree with its reference word in case,
number and gender (a noun's gender is its `genus`, S26), when a passive AcI's
participle has no accusative subject or no `esse` after it, when a question's
head is not its particle, or when a double accusative has no two accusatives.
