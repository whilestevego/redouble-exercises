import 'dart:io';

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
    mergeInputs({for (final e in parsed.entries) e.key: e.value.records}),
  );
  final outputs = {
    for (final MapEntry(key: d, value: p) in parsed.entries) ...{
      'parsed/$d.json': p.records,
      'parsed/$d.report.json': p.report,
    },
    'dist/exercises.json': release(records),
  };

  final problems = <String>[];
  for (final MapEntry(key: path, value: value) in outputs.entries) {
    if (checkOnly) {
      final file = File(path);
      if (!file.existsSync() || file.readAsStringSync() != encodeJson(value)) {
        problems.add('$path is not the output of the build. Run make build.');
      }
    } else {
      writeJson(path, value);
    }
  }
  problems.addAll(checkDataset(parsed, records));
  for (final p in problems) {
    stderr.writeln('✗ $p');
  }
  stdout.writeln('${records.length} records, ${problems.length} problems');
  if (problems.isNotEmpty) exit(1);
}
