import 'package:redouble_exercises/json_io.dart';
import 'package:redouble_exercises/merge.dart';
import 'package:test/test.dart';

Json _parsed(String id, {String? force, List<String>? equipment}) => {
  'id': id,
  'name': id.replaceAll('_', ' '),
  'kind': 'strength',
  'level': 'beginner',
  'force': force,
  'mechanic': null,
  'equipment': equipment,
  'muscles': {
    'primary': ['chest'],
    'secondary': ['chest', 'triceps'],
  },
  'instructions': ['Lower the bar to the chest.'],
};

List<Json> _merge(
  Map<String, List<String>> groups, {
  Json fields = const {},
  List<Json> records = const [],
}) => merge(
  MergeInputs(
    parsed: {'src': records},
    sources: {
      'src': {
        'license': 'Unlicense',
        'authors': ['someone'],
      },
    },
    merges: {'groups': groups},
    fields: fields,
    aliases: const {},
    muscleGroups: const {'chest': 'chest', 'triceps': 'arms'},
  ),
);

void main() {
  test('a curated value wins, and the provenance says so', () {
    final r = _merge(
      {
        'Bench': ['src:Bench'],
      },
      records: [
        _parsed('Bench', equipment: ['barbell']),
      ],
      fields: {
        'Bench': {
          'equipment': {
            'value': ['dumbbell'],
            'evidence': [
              {'rule': 'x'},
            ],
          },
        },
      },
    ).single;
    expect(r['equipment'], ['dumbbell']);
    expect((r['provenance'] as Map)['equipment'], 'curated');
  });

  test('rules fill the gaps and drop a secondary muscle that is primary', () {
    final r = _merge(
      {
        'Plank_Hold': ['src:Plank_Hold'],
      },
      records: [
        _parsed('Plank_Hold', force: 'static', equipment: ['bodyweight']),
      ],
    ).single;
    expect((r['muscles'] as Map)['secondary'], ['triceps']);
    expect(r['region'], 'chest');
    expect(r['tracking'], {
      'measure': 'time',
      'laterality': 'bilateral',
      'load': 'added',
    });
    expect((r['provenance'] as Map)['tracking.measure'], 'rule');
  });

  test('a group takes the first member and credits every member', () {
    final r = _merge(
      {
        'Dip': ['src:Dip', 'src:Weighted_Dip'],
      },
      records: [
        _parsed('Dip', equipment: ['dip bar']),
        _parsed('Weighted_Dip', equipment: ['dip bar']),
      ],
    ).single;
    expect(r['name'], 'Dip');
    expect(
      [for (final s in r['sources'] as List) (s as Map)['id']],
      ['Dip', 'Weighted_Dip'],
    );
  });

  test('laterality reads the name', () {
    expect(lateralityOf('Single-Leg Hop'), 'unilateral');
    expect(lateralityOf('Alternate Hammer Curl'), 'alternating');
    expect(lateralityOf('Barbell Squat'), 'bilateral');
  });
}
