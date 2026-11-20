import 'json_io.dart';

/// The inputs of the merge. Each one is a committed file.
class MergeInputs {
  MergeInputs({
    required this.parsed,
    required this.sources,
    required this.merges,
    required this.fields,
    required this.aliases,
    required this.muscleGroups,
  });

  /// Parsed records by dataset, in source order.
  final Map<String, List<Json>> parsed;

  /// SOURCE.json by dataset.
  final Map<String, Json> sources;
  final Json merges;
  final Json fields;
  final Json aliases;

  /// Muscle slug to its group slug.
  final Map<String, String> muscleGroups;
}

/// The tracking fields, in output order.
const trackingFields = [
  'measure',
  'durationSec',
  'distanceM',
  'laterality',
  'load',
  'bodyweightFactor',
];

/// Joins the parsed records and the curation. The same inputs give the same
/// bytes.
List<Json> merge(MergeInputs inputs) {
  final byRef = {
    for (final MapEntry(key: dataset, value: records) in inputs.parsed.entries)
      for (final r in records) '$dataset:${r['id']}': (dataset, r),
  };
  final groups = (inputs.merges['groups'] as Map).cast<String, List<dynamic>>();
  return [
    for (final MapEntry(key: slug, value: members) in groups.entries)
      _record(
        slug,
        [for (final m in members.cast<String>()) byRef[m]!],
        (inputs.fields[slug] as Map?)?.cast<String, dynamic>() ?? const {},
        (inputs.aliases[slug] as List?)?.cast<Json>() ?? const [],
        inputs,
      ),
  ];
}

Json _record(
  String slug,
  List<(String, Json)> members,
  Map<String, dynamic> curated,
  List<Json> aliases,
  MergeInputs inputs,
) {
  final provenance = <String, String>{};
  final (dataset, first) = members.first;
  final sources = _sourcesOf(members, inputs);

  T pick<T>(String field, T Function() fromSource, {T Function()? rule}) {
    if (curated.containsKey(field)) {
      provenance[field] = 'curated';
      final value = (curated[field] as Map)['value'];
      return (value is List ? value.cast<String>() : value) as T;
    }
    final value = fromSource();
    if (value != null || rule == null) {
      if (value != null) provenance[field] = dataset;
      return value;
    }
    final ruled = rule();
    if (ruled != null) provenance[field] = 'rule';
    return ruled;
  }

  final name = pick('name', () => first['name'] as String);
  final kind = pick('kind', () => first['kind'] as String?);
  final muscles = first['muscles'] as Map;
  final primary = pick(
    'muscles.primary',
    () => (muscles['primary'] as List).cast<String>(),
  );
  final secondary = pick('muscles.secondary', () {
    final all = (muscles['secondary'] as List).cast<String>();
    return [
      for (final m in all)
        if (!primary.contains(m)) m,
    ];
  });
  final equipment = pick(
    'equipment',
    () => (first['equipment'] as List?)?.cast<String>(),
    rule: () => kind == 'stretching' ? ['bodyweight'] : null,
  );
  final instructions = pick(
    'instructions',
    () => (first['instructions'] as List).cast<String>(),
  );
  final region = pick(
    'region',
    () => null,
    rule: () => primary.isEmpty ? null : inputs.muscleGroups[primary.first],
  );

  if (aliases.isNotEmpty) provenance['aliases'] = 'curated';
  final sourceName = first['name'] as String;
  final tracking = <String, Object?>{
    'measure': pick(
      'tracking.measure',
      () => null,
      rule: () => first['force'] == 'static' ? 'time' : 'reps',
    ),
    'durationSec': pick('tracking.durationSec', () => null),
    'distanceM': pick('tracking.distanceM', () => null),
    'laterality': pick(
      'tracking.laterality',
      () => null,
      rule: () => lateralityOf(sourceName),
    ),
    'load': pick(
      'tracking.load',
      () => null,
      rule: () => switch (kind) {
        'stretching' => 'none',
        _ when equipment?.contains('bodyweight') ?? false => 'added',
        _ => 'absolute',
      },
    ),
    'bodyweightFactor': pick('tracking.bodyweightFactor', () => null),
  };

  return {
    'slug': slug,
    'name': name,
    'aliases': [for (final a in aliases) a['name']],
    'kind': kind,
    'region': region,
    'muscles': {'primary': primary, 'secondary': secondary},
    'equipment': equipment,
    'level': pick('level', () => first['level'] as String?),
    'force': pick('force', () => first['force'] as String?),
    'mechanic': pick('mechanic', () => first['mechanic'] as String?),
    'instructions': instructions,
    'tracking': {
      for (final f in trackingFields)
        if (tracking[f] != null) f: tracking[f],
    },
    'variationGroup': null,
    'sources': sources,
    'provenance': provenance,
    ...licenseOf(sources),
  };
}

/// A record's own license and authors win over its dataset's.
List<Json> _sourcesOf(List<(String, Json)> members, MergeInputs inputs) => [
  for (final (dataset, r) in members)
    {
      'dataset': dataset,
      'id': r['id'],
      'license': r['license'] ?? inputs.sources[dataset]!['license'],
      'authors': r['authors'] ?? inputs.sources[dataset]!['authors'],
      'url': (inputs.sources[dataset]!['recordUrl'] as String).replaceAll(
        '{id}',
        '${r['id']}',
      ),
    },
];

/// The rank of each license that a source uses. A higher rank asks more of
/// a reuser. Rank 0 asks for no credit.
const licenseRanks = {
  'CC0': 0,
  'Unlicense': 0,
  'CC BY 4.0': 1,
  'CC BY-SA 3.0': 2,
  'CC BY-SA 4.0': 3,
};

/// The record's `license`, the strictest of its sources, and its `credit`:
/// the authors, the license and the link that a license with a rank above 0
/// requires. The credit is null when no source asks for one.
Json licenseOf(List<Json> sources) {
  int rank(Json s) =>
      licenseRanks[s['license']] ??
      (throw StateError('Unknown license ${s['license']}'));
  final strictest = sources.reduce((a, b) => rank(b) > rank(a) ? b : a);
  final credited = [
    for (final s in sources)
      if (rank(s) > 0) s,
  ];
  return {
    'license': strictest['license'],
    'credit': credited.isEmpty
        ? null
        : {
            'dataset': credited.first['dataset'],
            'authors': {
              for (final s in credited)
                ...(s['authors'] as List).cast<String>(),
            }.toList(),
            'license': strictest['license'],
            'url': credited.first['url'],
          },
  };
}

/// A rule on the name. A curated value overrides it.
String lateralityOf(String name) {
  final n = name.toLowerCase();
  if (n.startsWith('alternate') || n.startsWith('alternating')) {
    return 'alternating';
  }
  const unilateral = [
    'one-arm',
    'one arm',
    'single-arm',
    'single arm',
    'single-leg',
    'single leg',
    'one handed',
    'one-handed',
    'side plank',
    'side bridge',
    'pistol',
    'bulgarian',
    'split squat',
  ];
  return unilateral.any(n.contains) ? 'unilateral' : 'bilateral';
}
