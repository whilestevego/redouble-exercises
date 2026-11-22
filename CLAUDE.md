# CLAUDE.md

This repo is an open exercise dataset. `README.md` describes the format and
the build. The plan and the build record are in the REDOUBLE repo:
`plans/plan-open-exercise-dataset.md`.

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
- **A slug never changes, never goes away and never moves to another
  exercise** after a release lists it in `releases/slugs.json`. Before that,
  a record whose steps contradict its name gets a new slug.
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
