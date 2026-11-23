import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/domain/beat_filter_view.dart';
import 'package:kickvolt/features/import/import.dart';
import 'package:kickvolt/features/projects/projects.dart';

void main() {
  Project makeProject({
    required List<Beat> beats,
    required BeatFilter filter,
  }) => Project(
    id: 'p1',
    title: 'Filter Test',
    source: const ProjectSource(
      kind: ImportSourceKind.file,
      originalName: 'test.wav',
    ),
    sampleRate: 44100,
    channels: 1,
    sampleCount: 44100 * 10,
    beats: beats,
    detection: DetectionSettings(filter: filter),
    createdAt: DateTime.utc(2026, 11, 23),
    updatedAt: DateTime.utc(2026, 11, 23),
  );

  // Hand-built beat list where the first downbeat is at index 2.
  const beatsWithDownbeatAt2 = <Beat>[
    Beat(sample: 1000, type: BeatType.beat), // 0
    Beat(sample: 2000, type: BeatType.strong), // 1
    Beat(sample: 3000, type: BeatType.downbeat), // 2 (first downbeat)
    Beat(sample: 4000, type: BeatType.beat), // 3
    Beat(sample: 5000, type: BeatType.strong), // 4
    Beat(sample: 6000, type: BeatType.beat), // 5
    Beat(sample: 7000, type: BeatType.drop), // 6 (4th from index 2)
    Beat(sample: 8000, type: BeatType.beat), // 7
    Beat(sample: 9000, type: BeatType.beat), // 8
    Beat(sample: 10000, type: BeatType.beat), // 9
    Beat(sample: 11000, type: BeatType.downbeat), // 10 (8th from index 2)
  ];

  // Hand-built beat list with no downbeats at all.
  const beatsWithoutDownbeat = <Beat>[
    Beat(sample: 1000, type: BeatType.beat), // 0
    Beat(sample: 2000, type: BeatType.strong), // 1
    Beat(sample: 3000, type: BeatType.beat), // 2
    Beat(sample: 4000, type: BeatType.drop), // 3
    Beat(sample: 5000, type: BeatType.beat), // 4
    Beat(sample: 6000, type: BeatType.beat), // 5
    Beat(sample: 7000, type: BeatType.strong), // 6
    Beat(sample: 8000, type: BeatType.beat), // 7
    Beat(sample: 9000, type: BeatType.beat), // 8
  ];

  test('BeatFilter.every returns all beat indices', () {
    final p = makeProject(
      beats: beatsWithDownbeatAt2,
      filter: BeatFilter.every,
    );
    expect(visibleBeatIndices(p), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  });

  test(
    'BeatFilter.strong returns all non-beat indices (strong, downbeat, drop)',
    () {
      final p = makeProject(
        beats: beatsWithDownbeatAt2,
        filter: BeatFilter.strong,
      );
      expect(visibleBeatIndices(p), [1, 2, 4, 6, 10]);
    },
  );

  test('BeatFilter.drops returns only drop indices', () {
    final p = makeProject(
      beats: beatsWithDownbeatAt2,
      filter: BeatFilter.drops,
    );
    expect(visibleBeatIndices(p), [6]);
  });

  test('BeatFilter.every2nd counts parity relative to the first downbeat', () {
    // First downbeat is at index 2 -> even parity indices (0, 2, 4, 6, 8, 10).
    final p = makeProject(
      beats: beatsWithDownbeatAt2,
      filter: BeatFilter.every2nd,
    );
    expect(visibleBeatIndices(p), [0, 2, 4, 6, 8, 10]);

    // When first downbeat is at index 1 -> odd parity indices (1, 3, 5).
    const downbeatAt1 = <Beat>[
      Beat(sample: 1000, type: BeatType.beat),
      Beat(sample: 2000, type: BeatType.downbeat),
      Beat(sample: 3000, type: BeatType.beat),
      Beat(sample: 4000, type: BeatType.beat),
      Beat(sample: 5000, type: BeatType.beat),
      Beat(sample: 6000, type: BeatType.downbeat),
    ];
    expect(
      visibleBeatIndices(
        makeProject(beats: downbeatAt1, filter: BeatFilter.every2nd),
      ),
      [1, 3, 5],
    );
  });

  test('BeatFilter.every4th lands on bar starts relative to first downbeat', () {
    // First downbeat at index 2 -> indices where (i - 2) % 4 == 0 -> 2, 6, 10.
    final p = makeProject(
      beats: beatsWithDownbeatAt2,
      filter: BeatFilter.every4th,
    );
    expect(visibleBeatIndices(p), [2, 6, 10]);
  });

  test(
    'every2nd and every4th count from index 0 when there is no downbeat',
    () {
      expect(
        visibleBeatIndices(
          makeProject(beats: beatsWithoutDownbeat, filter: BeatFilter.every2nd),
        ),
        [0, 2, 4, 6, 8],
      );
      expect(
        visibleBeatIndices(
          makeProject(beats: beatsWithoutDownbeat, filter: BeatFilter.every4th),
        ),
        [0, 4, 8],
      );
    },
  );

  test('empty beats list returns empty indices for all filters', () {
    for (final f in BeatFilter.values) {
      expect(
        visibleBeatIndices(makeProject(beats: const [], filter: f)),
        isEmpty,
      );
    }
  });
}
