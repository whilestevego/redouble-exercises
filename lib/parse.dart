import 'json_io.dart';

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
