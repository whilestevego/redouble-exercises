# redouble-exercises

An open dataset of strength exercises. It merges
[free-exercise-db](https://github.com/yuhonas/free-exercise-db) with curation
that a reviewer can check. Each record names its sources, their licenses and
their authors. [wger](https://wger.de) joins in a later release.

The [REDOUBLE](https://github.com/whilestevego/redouble) workout app builds
its exercise library from the releases of this repo.

## The release file

`dist/exercises.json` holds the records. One record:

```json
{
  "slug": "Face_Pull",
  "name": "Face Pull",
  "aliases": ["Rear Delt Cable Pull"],
  "kind": "strength",
  "region": "shoulders",
  "muscles": { "primary": ["shoulders"], "secondary": ["middle back"] },
  "equipment": ["cable"],
  "level": "intermediate",
  "force": "pull",
  "mechanic": "compound",
  "instructions": ["Facing a high pulley with a rope or dual handles attached, …"],
  "tracking": { "measure": "reps", "laterality": "bilateral", "load": "absolute" },
  "variationGroup": null,
  "sources": [
    { "dataset": "free-exercise-db", "id": "Face_Pull", "license": "Unlicense",
      "authors": ["yuhonas and contributors"], "url": "https://github.com/…/Face_Pull" }
  ],
  "provenance": { "name": "free-exercise-db", "aliases": "curated", "tracking.measure": "rule", "…": "…" },
  "license": "Unlicense",
  "credit": null
}
```

- A **slug** never changes, never goes away and never moves to another
  exercise.
- **`provenance`** gives the origin of each field: a dataset name, `curated`
  or `rule`.
- **`null` or an absent value means unknown.** An empty list of secondary
  muscles that a source states is a fact.
- **`tracking`** tells an app how to log a set. `measure` is `reps`, `time`
  or `distance`. `laterality` is `bilateral`, `unilateral` or `alternating`.
  `load` is `absolute`, `added` (bodyweight plus added weight) or `none`.
  `bodyweightFactor` is the share of the bodyweight that the movement lifts.

- **`license`** is the strictest license among the record's sources.
  **`credit`** gives the dataset, the authors, the license and the link that
  the license requires, or `null` when no source asks for credit.
  `dist/ATTRIBUTION.md` lists each credit.

The equipment and muscle slugs are in `vocabulary/`.

## How the build works

```
sources/      the upstream files, pinned to a commit
   │  step 1: parse (bin/build.dart, no judgment)
   ▼
parsed/       each source in our field names and vocabulary
   │  step 2: curate (a person or an agent, with evidence)
   ▼
curated/      merges, field values and aliases
   │  step 3: merge (bin/build.dart, fixed rules)
   ▼
dist/         the release
```

- The **parse** only translates. A value with no mapping becomes `null` and
  goes into `parsed/<source>.report.json`.
- The **curation** holds each decision. Each value has evidence: a quote from
  the record's steps, or the rule it applies. The build fails when a quote is
  not in the steps.
- The **merge** is a fixed function of the two. A curated value wins over a
  source value, and a source value wins over a rule.

A form word names a different exercise. "Seated Barbell Shoulder Press" and
"Barbell Shoulder Press" are two records, and a name with no form word means
the default form. An alias names the same exercise in the same form.

## Build and check

Install the Dart SDK. Then run these commands:

```bash
dart pub get
make build   # write parsed/ and dist/
make ci      # format, analyze, test, and check that dist/ is current
```

`make check` fails when a committed output differs from a new build, or when
a rule breaks. The rules: each source record is in one merge group, each
curated value has evidence, each slug and name is unique, and each equipment
and muscle is in the vocabulary.

## Report a missing exercise or name

Open an issue. Give the app that wrote the name, the exact name and the
equipment.

## License

The data in `dist/`, `parsed/`, `curated/` and `vocabulary/` is under
[CC BY-SA 4.0](LICENSE). The curation is also offered under CC0. The code in
`bin/`, `lib/` and `test/` is under the [MIT license](LICENSE-code).

The sources keep their own licenses:

- free-exercise-db by yuhonas and contributors, under the
  [Unlicense](https://github.com/yuhonas/free-exercise-db/blob/main/LICENSE).
