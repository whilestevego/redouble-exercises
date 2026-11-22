# CLAUDE.md

This repo is an open exercise dataset. `README.md` describes the format and
the build. The plan and the build record are in the REDOUBLE repo:
`plans/completed/plan-open-exercise-dataset.md`.

## Commands

```bash
make build   # parse and merge; writes parsed/ and dist/
make ci      # run it before you push
```

## Rules

- **Claude owns the curation.** Each value in `curated/` is a decision that
  Claude makes and checks against the steps of the records it touches.
- **Each curated value has evidence.** A `quote` must appear word for word in
  the steps of a member of the group, or in the record's curated steps. A
  `rule` states the rule in one or two sentences. A `url` with a `note` names
  an outside page that you read, and what it shows. Use it for a value that
  needed research. A value with no evidence does not go in.
- **An own record is an exercise that no source has.** It goes into
  `curated/records.json` as a full record with an `evidence` list. Write the
  steps in your own words, and never copy them from a page. Give url evidence
  from two independent sources or more. Check first that no record or alias
  already names the exercise.
- **`curated/not-strength.json` lists names, not records.** It holds the
  names that other apps write for cardio and activities. Do not make a
  strength record for such a name.
- **The steps decide.** When a source field contradicts the record's own
  steps, curate the field and quote the steps.
- **A form word names a different exercise.** Seated, standing, incline,
  decline, lying, kneeling, single-arm, assisted, close-grip and an equipment
  word make a different record. A name with no form word means the default
  form. Two forms of one movement share a `variationGroup` and stay two
  records.
- **An alias names the same exercise in the same form.** A family name, such
  as "Loaded Carry", is not an alias.
- **A copy name never becomes an alias.** `isCopyName` in `lib/merge.dart`
  drops a source name that marks a user's copy, one side of the body or a
  video, and a name with accented letters. Add a pattern there, and do not
  reject each name. A name in another language with no accent still needs a
  curated reject.
- **Force, mechanic and level follow fixed rules.** Force is `push`, `pull`
  or `static`, by the direction of the work. Mechanic counts the joints that
  move: one joint is `isolation`, two or more are `compound`, and a hold or a
  stretch has none. Level is `beginner` for a guided load, a move of one
  joint, a stretch or a basic bodyweight move. It is `intermediate` for a
  free-weight lift of two or more joints, a full bodyweight pull or a move
  that needs balance or power. It is `expert` for a gymnastic skill or an
  Olympic lift. State the rule in the evidence.
- **A field that changes the tracking needs a check.** A curated force of
  `static` makes the measure `time`. Equipment with no `bodyweight` makes the
  load `absolute`. Curate `tracking.load` as `added` when the body is the
  load.
- **A slug never changes, never goes away and never moves to another
  exercise** after a release lists it in `releases/slugs.json`. Before that,
  a record whose steps contradict its name gets a new slug.
- **Two released records that are one exercise join, and one slug goes to
  `curated/replaced.json`.** Move its members into the other group, give the
  join evidence and add the old name as an alias when the merge drops it.
  The release's `replaced` map tells an app to move its references.
- **The parse holds no judgment.** Never fix a value in `lib/parse.dart`. A
  value that needs a decision goes into `curated/`.
- **Never edit `parsed/` or `dist/` by hand.** `make build` writes them.
- **The equipment and muscle slugs in `vocabulary/` are the app's.** A new
  slug needs the same slug in the app's `EquipmentSeed` or `MuscleSeed`.

## A release

1. Run `make ci`.
2. Add each new slug to `releases/slugs.json`.
3. Tag the commit `vX.Y.Z` and attach `dist/exercises.json` to a GitHub
   release. The changelog lists the new slugs, the new aliases and the
   changed fields.
4. In the app, set `datasetTag` in `tool/import_exercises.dart` and run
   `make library`.

## Writing

Write all prose in ASD-STE100 Simplified Technical English, as the REDOUBLE
repo's `CLAUDE.md` describes. Commit subjects use Conventional Commits, in 72
characters or fewer.
