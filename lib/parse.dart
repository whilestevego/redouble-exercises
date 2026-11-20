import 'package:html/parser.dart' as html;

import 'json_io.dart';
import 'merge.dart' show licenseRanks;

/// A source record in the dataset's field names and vocabulary. The parse
/// translates and never judges: a value with no mapping is null and goes into
/// the report.
typedef Parsed = ({List<Json> records, List<String> report});

Parsed parseFreeExerciseDb(List<Json> raw, Json map, Json meta) {
  final equipment = (map['equipment'] as Map).cast<String, String?>();
  final muscles = (map['muscles'] as Map).cast<String, String>();
  final kinds = (map['kind'] as Map).cast<String, String>();
  final report = <String>[];

  T? mapped<T>(Map<String, T?> table, String? value, String id, String what) {
    if (value == null) return null;
    if (!table.containsKey(value)) {
      report.add('$id: $what "$value" has no mapping');
    }
    return table[value];
  }

  List<String> muscleList(Json r, String key) => [
    for (final m in (r[key] as List).cast<String>())
      ?mapped(muscles, m, r['id'] as String, 'muscle'),
  ];

  return (
    records: [
      for (final r in raw)
        {
          'id': r['id'],
          'name': r['name'],
          'kind': mapped(
            kinds,
            r['category'] as String?,
            r['id'] as String,
            'category',
          ),
          'level': r['level'],
          'force': r['force'],
          'mechanic': r['mechanic'],
          'equipment': switch (mapped(
            equipment,
            r['equipment'] as String?,
            r['id'] as String,
            'equipment',
          )) {
            null => null,
            final e => [e],
          },
          'muscles': {
            'primary': muscleList(r, 'primaryMuscles'),
            'secondary': muscleList(r, 'secondaryMuscles'),
          },
          'instructions': r['instructions'],
          'images': r['images'],
        },
    ],
    report: report,
  );
}

/// wger's API record: the exercise, and its English translation for the
/// name, the steps and the aliases. wger gives a license and authors for each
/// record. A record with no English translation is in the report.
Parsed parseWger(List<Json> raw, Json map) {
  final report = <String>[];
  final language = map['language'] as int;
  final tables = {
    for (final k in ['region', 'kind', 'muscles', 'equipment', 'license'])
      k: (map[k] as Map).cast<String, String?>(),
  };

  String? mapped(String table, String? value, Object id) {
    if (value == null) return null;
    final t = tables[table]!;
    if (!t.containsKey(value)) {
      report.add('wger:$id: $table "$value" has no mapping');
    }
    return t[value];
  }

  List<String> list(String table, List<dynamic> items, String key, Object id) =>
      {
        for (final i in items.cast<Json>())
          ?mapped(table, i[key] as String?, id),
      }.toList();

  final records = <Json>[];
  for (final e in raw) {
    final id = e['id'] as int;
    final texts = (e['translations'] as List).cast<Json>().where(
      (t) => t['language'] == language,
    );
    if (texts.isEmpty) {
      report.add('wger:$id has no English translation');
      continue;
    }
    final t = texts.first;
    final category = (e['category'] as Json)['name'] as String;
    final equipment = list('equipment', e['equipment'] as List, 'name', id);
    final textLicenses = (map['translationLicense'] as Map)
        .cast<String, String>();
    final licenses = [
      mapped('license', (e['license'] as Json)['short_name'] as String, id),
      textLicenses['${t['license']}'],
    ].nonNulls.toList();
    if (licenses.length < 2) report.add('wger:$id: a license has no mapping');
    records.add({
      'id': '$id',
      'uuid': e['uuid'],
      'name': (t['name'] as String).trim(),
      'aliases': [
        for (final a in (t['aliases'] as List).cast<Json>())
          (a['alias'] as String).trim(),
      ],
      'kind': (tables['kind']!)[category],
      'region': mapped('region', category, id),
      'level': null,
      'force': null,
      'mechanic': null,
      'equipment': (e['equipment'] as List).isEmpty || equipment.isEmpty
          ? null
          : equipment,
      'muscles': {
        'primary': list('muscles', e['muscles'] as List, 'name', id),
        'secondary': list(
          'muscles',
          e['muscles_secondary'] as List,
          'name',
          id,
        ),
      },
      'instructions': stepsOf(t['description'] as String? ?? ''),
      'license': licenses.reduce(
        (a, b) => licenseRanks[b]! > licenseRanks[a]! ? b : a,
      ),
      'authors': {
        ...(e['author_history'] as List).cast<String>(),
        ...(t['author_history'] as List).cast<String>(),
      }.toList(),
      'variationGroup': e['variation_group'],
    });
  }
  return (records: records, report: report);
}

/// The steps of an HTML description: one for each list item, or else one for
/// each paragraph, or else one for each line of the text.
List<String> stepsOf(String source) {
  final body = html.parse(source).body;
  if (body == null) return const [];
  final items = body.querySelectorAll('li');
  final blocks = items.isNotEmpty ? items : body.querySelectorAll('p');
  final texts = blocks.isNotEmpty
      ? [for (final b in blocks) b.text]
      : body.text.split('\n');
  return [
    for (final t in texts)
      if (_flat(t).isNotEmpty) _flat(t),
  ];
}

String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
