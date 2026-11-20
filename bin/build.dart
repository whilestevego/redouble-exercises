import 'dart:io';

import 'package:redouble_exercises/attribution.dart';
import 'package:redouble_exercises/check.dart';
import 'package:redouble_exercises/inputs.dart';
import 'package:redouble_exercises/json_io.dart';
import 'package:redouble_exercises/merge.dart';

/// Runs the parse and the merge and writes `parsed/` and `dist/`. With
/// `--check`, writes nothing: it fails when a committed file differs from a
/// new build, or when a rule of the dataset breaks.
void main(List<String> args) {
  if (!inRepoRoot) {
    stderr.writeln('Run this from the root of the repo.');
    exit(2);
  }
  final checkOnly = args.contains('--check');
  final parsed = parseAll();
  final records = merge(
    mergeInputs({for (final d in mergedDatasets) d: parsed[d]!.records}),
  );
  final outputs = {
    for (final MapEntry(key: d, value: p) in parsed.entries) ...{
      'parsed/$d.json': p.records,
      'parsed/$d.report.json': p.report,
    },
    'dist/exercises.json': release(records),
  };
  final texts = {
    'dist/ATTRIBUTION.md': attributionOf(records, [
      for (final d in mergedDatasets)
        readJson('sources/$d/SOURCE.json') as Json,
    ]),
  };

  final problems = <String>[];
  final files = {
    for (final MapEntry(key: path, value: value) in outputs.entries)
      path: encodeJson(value),
    ...texts,
  };
  for (final MapEntry(key: path, value: text) in files.entries) {
    final file = File(path);
    if (checkOnly) {
      if (!file.existsSync() || file.readAsStringSync() != text) {
        problems.add('$path is not the output of the build. Run make build.');
      }
    } else {
      file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(text);
    }
  }
  problems.addAll(checkDataset(parsed, records));
  for (final p in problems) {
    stderr.writeln('✗ $p');
  }
  stdout.writeln('${records.length} records, ${problems.length} problems');
  if (problems.isNotEmpty) exit(1);
}
