import 'dart:io';

import 'inputs.dart';
import 'json_io.dart';
import 'parse.dart';

const _measures = {'reps', 'time', 'distance'};
const _lateralities = {'bilateral', 'unilateral', 'alternating'};
const _loads = {'absolute', 'added', 'none'};

/// The rules of the dataset. Each returned string is one broken rule.
List<String> checkDataset(Map<String, Parsed> parsed, List<Json> records) {
  final problems = <String>[];
  final merges = readJson('curated/merges.json') as Json;
  final groups = (merges['groups'] as Map).cast<String, List<dynamic>>();
  final groupEvidence = (merges['evidence'] as Map).cast<String, dynamic>();
  final fields = (readJson('curated/fields.json') as Map)
      .cast<String, dynamic>();
  final aliases = (readJson('curated/aliases.json') as Map)
      .cast<String, dynamic>();
  final equipment = {
    for (final e
        in (readJson('vocabulary/equipment.json') as List).cast<Json>())
      e['slug'] as String,
  };
  final muscleVocabulary = readJson('vocabulary/muscles.json') as Json;
  final muscles = {
    for (final m in (muscleVocabulary['muscles'] as List).cast<Json>())
      m['slug'] as String,
  };
  final regions = {
    for (final g in (muscleVocabulary['groups'] as List).cast<Json>())
      g['slug'] as String,
  };

  final refs = <String, Json>{
    for (final d in mergedDatasets)
      for (final r in parsed[d]!.records) '$d:${r['id']}': r,
  };
  final seen = <String>{};
  for (final MapEntry(key: slug, value: members) in groups.entries) {
    for (final m in members.cast<String>()) {
      if (!refs.containsKey(m)) {
        problems.add('merges: $slug names $m, which no source has');
      }
      if (!seen.add(m)) problems.add('merges: $m is in two groups');
    }
    final renamed =
        members.length > 1 || members.single != 'free-exercise-db:$slug';
    if (renamed && !_hasEvidence(groupEvidence[slug])) {
      problems.add('merges: $slug joins or renames records with no evidence');
    }
  }
  for (final ref in refs.keys) {
    if (!seen.contains(ref)) problems.add('merges: no group has $ref');
  }

  final bySlug = {for (final r in records) r['slug'] as String: r};
  String textOf(String slug) => _flat(
    [
      for (final m in groups[slug]!.cast<String>())
        ...((refs[m]?['instructions'] as List?) ?? const []).cast<String>(),
      ...((bySlug[slug]?['instructions'] as List?) ?? const []).cast<String>(),
    ].join(' '),
  );

  void evidence(String where, String slug, Object? items) {
    if (!_hasEvidence(items)) {
      problems.add('$where has no evidence');
      return;
    }
    for (final e in (items as List).cast<Json>()) {
      final quote = e['quote'] as String?;
      if (quote != null && !textOf(slug).contains(_flat(quote))) {
        problems.add('$where quotes text that the steps do not have: "$quote"');
      }
    }
  }

  for (final MapEntry(key: slug, value: entry) in fields.entries) {
    if (!groups.containsKey(slug)) {
      problems.add('fields: no group has the slug $slug');
      continue;
    }
    for (final MapEntry(key: field, value: v)
        in (entry as Map).cast<String, dynamic>().entries) {
      evidence('fields: $slug $field', slug, (v as Map)['evidence']);
    }
  }
  for (final MapEntry(key: slug, value: list) in aliases.entries) {
    if (!groups.containsKey(slug)) {
      problems.add('aliases: no group has the slug $slug');
      continue;
    }
    for (final a in (list as List).cast<Json>()) {
      evidence('aliases: $slug "${a['name']}"', slug, a['evidence']);
    }
  }
  for (final MapEntry(key: slug, value: items) in groupEvidence.entries) {
    evidence('merges: $slug', slug, items);
  }

  final names = <String, String>{};
  for (final r in records) {
    final slug = r['slug'] as String;
    for (final name in [r['name'], ...(r['aliases'] as List)].cast<String>()) {
      final key = _normalized(name);
      final other = names[key];
      if (other != null && other != slug) {
        problems.add('names: "$name" of $slug is also a name of $other');
      }
      names[key] = slug;
    }
    for (final e in ((r['equipment'] as List?) ?? const []).cast<String>()) {
      if (!equipment.contains(e)) {
        problems.add('$slug: equipment "$e" is not in the vocabulary');
      }
    }
    final m = r['muscles'] as Map;
    for (final x in [
      ...(m['primary'] as List),
      ...(m['secondary'] as List),
    ].cast<String>()) {
      if (!muscles.contains(x)) {
        problems.add('$slug: muscle "$x" is not in the vocabulary');
      }
    }
    if (r['region'] != null && !regions.contains(r['region'])) {
      problems.add('$slug: region "${r['region']}" is not in the vocabulary');
    }
    final t = r['tracking'] as Map;
    if (!_measures.contains(t['measure'])) {
      problems.add('$slug: measure "${t['measure']}"');
    }
    if (!_lateralities.contains(t['laterality'])) {
      problems.add('$slug: laterality "${t['laterality']}"');
    }
    if (!_loads.contains(t['load'])) problems.add('$slug: load "${t['load']}"');
    final sources = (r['sources'] as List).cast<Json>();
    if (sources.isEmpty ||
        sources.any(
          (s) =>
              s['license'] == null || (s['authors'] as List?)?.isEmpty != false,
        )) {
      problems.add('$slug: a source has no license or no authors');
    }
  }

  for (final file in Directory('names').listSync().whereType<File>()) {
    if (!file.path.endsWith('.tsv')) continue;
    for (final line in file.readAsLinesSync().skip(1)) {
      final slug = line.split('\t').elementAtOrNull(1) ?? '';
      if (slug.isNotEmpty && !bySlug.containsKey(slug)) {
        problems.add('${file.path}: "$line" names no record');
      }
    }
  }

  final released = File('releases/slugs.json');
  if (released.existsSync()) {
    for (final slug in (readJson(released.path) as List).cast<String>()) {
      if (!bySlug.containsKey(slug)) {
        problems.add('released slug $slug is gone');
      }
    }
  }
  return problems;
}

bool _hasEvidence(Object? items) => items is List && items.isNotEmpty;

String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String _normalized(String name) =>
    name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
