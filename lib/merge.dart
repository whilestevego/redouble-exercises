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
    this.own = const [],
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

  /// The records of `curated/records.json`, which no source has.
  final List<Json> own;
}

/// The dataset name of an own record, and its SOURCE entry.
const ownDataset = 'redouble-exercises';
const ownSource = {
  'dataset': ownDataset,
  'license': 'CC0',
  'authors': ['redouble-exercises contributors'],
  'recordUrl':
      'https://github.com/whilestevego/redouble-exercises/blob/main/curated/records.json',
};

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
  final records = [
    for (final MapEntry(key: slug, value: members) in groups.entries)
      _record(
        slug,
        [for (final m in members.cast<String>()) byRef[m]!],
        (inputs.fields[slug] as Map?)?.cast<String, dynamic>() ?? const {},
        (inputs.aliases[slug] as List?)?.cast<Json>() ?? const [],
        inputs,
      ),
    for (final r in inputs.own)
      _record(
        r['slug'] as String,
        [(ownDataset, r)],
        (inputs.fields[r['slug']] as Map?)?.cast<String, dynamic>() ?? const {},
        const [],
        inputs,
      ),
  ];
  return _dropTakenAliases(records);
}

/// A source alias is a hint. It goes when another record has it as a name or
/// a curated alias, or when an earlier record took it.
List<Json> _dropTakenAliases(List<Json> records) {
  final taken = {
    for (final r in records) ...[
      _key(r['name'] as String),
      for (final a in (r['aliases'] as List).take(r['_curatedAliases'] as int))
        _key(a as String),
    ],
  };
  return [
    for (final r in records)
      {
        for (final e in r.entries)
          if (e.key == 'aliases')
            e.key: [
              for (final (i, a) in (e.value as List).cast<String>().indexed)
                if (i < (r['_curatedAliases'] as int) || taken.add(_key(a))) a,
            ]
          else if (e.key != '_curatedAliases')
            e.key: e.value,
      },
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
  final (_, first) = members.first;
  final sources = _sourcesOf(members, inputs);

  /// The value of the first member that has one, and its dataset.
  (String, T)? fromMembers<T>(T? Function(Json r) get) {
    for (final (dataset, r) in members) {
      final value = get(r);
      if (value != null && !(value is List && value.isEmpty)) {
        return (dataset, value);
      }
    }
    return null;
  }

  T pick<T>(
    String field,
    (String, T)? Function() fromSource, {
    T Function()? rule,
  }) {
    if (curated.containsKey(field)) {
      provenance[field] = 'curated';
      final value = (curated[field] as Map)['value'];
      return (value is List ? value.cast<String>() : value) as T;
    }
    if (fromSource() case (final dataset, final value)) {
      provenance[field] = dataset;
      return value;
    }
    final ruled = rule?.call();
    if (ruled != null) provenance[field] = 'rule';
    return ruled as T;
  }

  List<String>? strings(Object? v) => (v as List?)?.cast<String>();
  Map<String, dynamic> musclesOf(Json r) =>
      r['muscles'] as Map<String, dynamic>;

  final name = pick<String>(
    'name',
    () => fromMembers((r) => r['name'] as String),
  );
  final kind = pick<String?>(
    'kind',
    () => fromMembers((r) => r['kind'] as String?),
    rule: () => kindOf(name),
  );
  final primary = pick<List<String>>(
    'muscles.primary',
    () => fromMembers((r) => strings(musclesOf(r)['primary'])),
    rule: () => const [],
  );
  final secondary = pick<List<String>>(
    'muscles.secondary',
    () => fromMembers(
      (r) => [
        for (final m in strings(musclesOf(r)['secondary']) ?? const <String>[])
          if (!primary.contains(m)) m,
      ],
    ),
    rule: () => const [],
  );
  final equipment = pick<List<String>?>(
    'equipment',
    () => fromMembers((r) => strings(r['equipment'])),
    rule: () => kind == 'stretching' ? ['bodyweight'] : null,
  );
  final instructions = pick<List<String>>(
    'instructions',
    () => fromMembers((r) => strings(r['instructions'])),
    rule: () => const [],
  );
  final region = pick<String?>(
    'region',
    () =>
        primary.isNotEmpty ? null : fromMembers((r) => r['region'] as String?),
    rule: () => primary.isEmpty ? null : inputs.muscleGroups[primary.first],
  );
  final force = pick<String?>(
    'force',
    () => fromMembers((r) => r['force'] as String?),
  );

  final rejected = {
    for (final a in aliases)
      if (a['reject'] == true) _key(a['name'] as String),
  };
  final kept = [
    for (final a in aliases)
      if (a['reject'] != true) a,
  ];
  final allAliases = <String>[
    for (final a in kept) a['name'] as String,
    for (final (i, (_, r)) in members.indexed) ...[
      if (i > 0 || !curated.containsKey('name')) r['name'] as String,
      ...?strings(r['aliases']),
    ],
  ];
  final seen = {_key(name), ...rejected};
  final named = [
    for (final a in allAliases)
      if (seen.add(_key(a))) a,
  ];
  if (kept.isNotEmpty) {
    provenance['aliases'] = 'curated';
  } else if (named.isNotEmpty) {
    provenance['aliases'] = members.first.$1;
  }

  final sourceName = first['name'] as String;
  (String, T)? tracked<T>(String f) =>
      fromMembers((r) => (r['tracking'] as Map?)?[f] as T?);
  final tracking = <String, Object?>{
    'measure': pick<String>(
      'tracking.measure',
      () => tracked('measure'),
      rule: () => measureOf(name, kind, force),
    ),
    'durationSec': pick<int?>(
      'tracking.durationSec',
      () => tracked('durationSec'),
    ),
    'distanceM': pick<num?>('tracking.distanceM', () => tracked('distanceM')),
    'laterality': pick<String>(
      'tracking.laterality',
      () => tracked('laterality'),
      rule: () => lateralityOf(sourceName),
    ),
    'load': pick<String>(
      'tracking.load',
      () => tracked('load'),
      rule: () => switch (kind) {
        'stretching' => 'none',
        _ when equipment?.contains('bodyweight') ?? false => 'added',
        _ => 'absolute',
      },
    ),
    'bodyweightFactor': pick<num?>(
      'tracking.bodyweightFactor',
      () => tracked('bodyweightFactor'),
    ),
  };
  final variationGroup = fromMembers((r) => r['variationGroup'] as String?);

  return {
    'slug': slug,
    'name': name,
    'aliases': named,
    '_curatedAliases': kept.length,
    'kind': kind,
    'region': region,
    'muscles': {'primary': primary, 'secondary': secondary},
    'equipment': equipment,
    'level': pick<String?>(
      'level',
      () => fromMembers((r) => r['level'] as String?),
    ),
    'force': force,
    'mechanic': pick<String?>(
      'mechanic',
      () => fromMembers((r) => r['mechanic'] as String?),
    ),
    'instructions': instructions,
    'tracking': {
      for (final f in trackingFields)
        if (tracking[f] != null) f: tracking[f],
    },
    'variationGroup': variationGroup?.$2,
    'sources': sources,
    'provenance': provenance,
    ...licenseOf(sources),
  };
}

/// A record's own license and authors win over its dataset's.
List<Json> _sourcesOf(List<(String, Json)> members, MergeInputs inputs) => [
  for (final (dataset, r) in members)
    if ((dataset == ownDataset ? ownSource : inputs.sources[dataset]!)
        case final source)
      {
        'dataset': dataset,
        'id': r['id'] ?? r['slug'],
        'license': r['license'] ?? source['license'],
        'authors': r['authors'] ?? source['authors'],
        'url': (source['recordUrl'] as String).replaceAll('{id}', '${r['id']}'),
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

String _key(String name) =>
    name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// A rule on the name, for a source that gives no kind.
String kindOf(String name) =>
    RegExp(r'stretch|\bpose\b|foam roll', caseSensitive: false).hasMatch(name)
    ? 'stretching'
    : 'strength';

/// A rule on the force, or on the kind and the name when no source gives a
/// force. A curated value overrides it.
String measureOf(String name, String? kind, String? force) {
  if (force != null) return force == 'static' ? 'time' : 'reps';
  final n = name.toLowerCase();
  if (kind == 'cardio') return 'time';
  if (RegExp(r'\bcarry\b|farmer|sled drag').hasMatch(n)) return 'distance';
  if (kind == 'stretching' ||
      RegExp(
        r'\bhold\b|\bplank\b|dead ?hang|\bhang$|l-sit|isometric|wall sit',
      ).hasMatch(n)) {
    return 'time';
  }
  return 'reps';
}
