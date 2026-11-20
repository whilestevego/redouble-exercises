import 'dart:io';

import 'json_io.dart';
import 'merge.dart';
import 'parse.dart';

const datasets = ['free-exercise-db', 'wger'];

/// The datasets whose records `curated/merges.json` covers. A parsed dataset
/// joins the release when its records join merge groups.
const mergedDatasets = ['free-exercise-db'];

/// Runs the parse of each source in [datasets].
Map<String, Parsed> parseAll() => {
  for (final d in datasets)
    d: switch (d) {
      'free-exercise-db' => parseFreeExerciseDb(
        (readJson('sources/$d/exercises.json') as List).cast<Json>(),
        readJson('vocabulary/$d.json') as Json,
        readJson('sources/$d/SOURCE.json') as Json,
      ),
      'wger' => parseWger(
        (readJson('sources/$d/exerciseinfo.json') as List).cast<Json>(),
        readJson('vocabulary/$d.json') as Json,
      ),
      _ => throw StateError('No parse for $d'),
    },
};

MergeInputs mergeInputs(Map<String, List<Json>> parsed) {
  final muscles = readJson('vocabulary/muscles.json') as Json;
  return MergeInputs(
    parsed: parsed,
    sources: {
      for (final d in mergedDatasets)
        d: readJson('sources/$d/SOURCE.json') as Json,
    },
    merges: readJson('curated/merges.json') as Json,
    fields: readJson('curated/fields.json') as Json,
    aliases: readJson('curated/aliases.json') as Json,
    muscleGroups: {
      for (final m in (muscles['muscles'] as List).cast<Json>())
        m['slug'] as String: m['group'] as String,
    },
  );
}

/// The release file. [records] are the merged records.
Json release(List<Json> records) => {
  'format': 1,
  'license': 'CC BY-SA 4.0',
  'url': 'https://github.com/whilestevego/redouble-exercises',
  'sources': [for (final d in datasets) readJson('sources/$d/SOURCE.json')],
  'count': records.length,
  'exercises': records,
};

bool get inRepoRoot => File('pubspec.yaml').existsSync();
