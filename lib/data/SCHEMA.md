# Grammar data schema 3.1

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
  modus:   {name: Modus, values: {ind: Indikativ, konj: Konjunktiv, ...},
            hidden_in_label: [ind]}  # codes a label does not name

label:
  head: [modus, tempus, genus_verbi] # axes before the colon
  tail: [person, numerus]            # axes after it
  merge_axis: person                 # the axis describeLabels joins with "/"
  overrides:                         # S17
    - {when: {modus: [inf, part]}, axis: tempus, values: {fut: Futur}}

parts:                               # the principal parts an item may give
  infinitiv:    {label: Infinitiv}
  praefix:      {label: Präfix, display: false}

defaults:
  given_part: praesens_1sg           # the form the practice screen shows
  lemma_part: infinitiv              # the lesson key and the card id

type_inference:                      # S11; keyed by part, rules in list order
  infinitiv:
    - {suffix: "āre", types: [A-Konjugation]}
    - {suffix: "ere", min_length: 5, types: [Konsonantische, Mischkonjugation]}

sandhi:                              # S16; the file's rule library
  kurz_nt: {end: vowel, before: [nt, nd], replace: short,
            explain: "Vokal vor nt/nd wird kurz"}

types:
  A-Konjugation:
    abstract: true                   # no item uses it directly
    inherits_from: Verb-Basis        # S6
    required_stems: [praesens]       # S4
    stems:
      wurzel:   {from: infinitiv, remove: [āre, ārī], display: Verbstamm}
      praesens: {template: "{wurzel}ā", display: Präsensstamm}
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
    sandhi: [a_ausfall, kurz_nt]     # rule ids of this file, in this order
    deponent: all                    # S10; or a list of tempus codes

items:
  - type: Unregelmäßig               # omitted when inference decides (S11)
    id: esse                         # defaults to the normalized lemma
    translation: sein
    parts: {infinitiv: esse, perfekt_1sg: fuī}
    forms: {ind.praes.akt.1.sg: sum} # overrides
    deponent: [perf, plusq, fut2]
    absent: [{modus: imp}]           # S15
```

One file is exactly one YAML document; a `---` separated second document throws.

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
an acyclic graph. `lexeme:` names an item `id` of the same file, and an item's
forms must not depend on that same item.

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
product of its parts' variants) or a `variant: true` sandhi rule. An item
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
resolves — one absent part removes it. A part is `self:` (a delegate of the same
type), `lexeme:` (an item) or `stem:` (an affix; it takes no `set`, `pass` or
`map`). The looked-up key is `set` plus the passed codes plus the mapped codes;
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
`end`, `before`, `replace`, `explain` (the German text the explanation shows)
and optionally `variant`. It matches a seam (S18) on normalized text:

- `end`: a letter string the left side ends with, or `vowel` / `consonant` (its
  last letter).
- `before`: `vowel` / `consonant` (the right side's first letter; the right side
  is not empty), or a list whose entry `p` matches when the right side starts
  with `p`, and whose entry `p$` matches only at a word-final seam and only when
  the right side equals `p` (`"$"` is the empty ending).
- `replace`: a literal replaces the last n letters of the left side, quantity
  marks included (n is the length of `end`, 1 for a class); `short` removes the
  quantity mark of the left side's last letter; `double_next` is the right
  side's first letter.

The first matching rule applies, at most one per seam, and a rule changes only
the left side. A rule whose output equals its input is not recorded. With
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
right: the next part's text, not word-final). It applies inside delegated
templates too, since delegate targets have no list of their own. Present stems
are school stems (`amā-`, `monē-`, `audī-`, `capi-`, `reg-`), built as root plus
theme vowel, so the quantity change at the seam is data: `amā` + `ō` → `amō`,
`capi` + `re` → `capere`.

**Collisions.** A key produced twice — by own forms, by delegation or by
composition — throws. There is no precedence between them; inheritance (S6) is
the only override mechanism besides item overrides.
