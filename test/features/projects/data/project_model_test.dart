import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/import/import.dart';
import 'package:kickvolt/features/projects/projects.dart';

void main() {
  Project sampleProject() => Project(
    id: 'proj-1',
    title: 'Midnight Run',
    source: const ProjectSource(
      kind: ImportSourceKind.file,
      originalName: 'Midnight Run.m4a',
      copiedFileName: 'source.m4a',
    ),
    sampleRate: 44100,
    channels: 2,
    sampleCount: 44100 * 168 + 33075, // 168.75 s
    beats: const [
      Beat(sample: 0, type: BeatType.downbeat),
      Beat(sample: 20672, type: BeatType.beat),
      Beat(sample: 41344, type: BeatType.strong),
      Beat(sample: 744188, type: BeatType.drop),
    ],
    sections: [
      Section(
        startSample: 0,
        endSample: 330750,
        name: SectionPreset.intro.name,
        colorArgb: SectionPreset.intro.colorArgb,
      ),
      Section(
        startSample: 330750,
        endSample: 744188,
        name: SectionPreset.verse.name,
        colorArgb: SectionPreset.verse.colorArgb,
      ),
      Section(
        startSample: 744188,
        endSample: 1405688,
        name: SectionPreset.drop.name,
        colorArgb: SectionPreset.drop.colorArgb,
      ),
    ],
    bpm: 128.0,
    beatPhaseSample: 0,
    detection: const DetectionSettings(
      sensitivity: 0.75,
      filter: BeatFilter.every4th,
    ),
    createdAt: DateTime.utc(2026, 11, 20, 10, 30, 0),
    updatedAt: DateTime.utc(2026, 11, 22, 18, 45, 12),
  );

  test(
    'JSON round trip preserves all fields, beat types, sections, and UTC dates',
    () {
      final original = sampleProject();
      final jsonMap = ProjectMapper.toJsonMap(original);

      expect(jsonMap['schemaVersion'], 1);
      expect(jsonMap['sampleRate'], 44100);
      expect(jsonMap['sampleCount'], original.sampleCount);
      expect(
        (jsonMap['source'] as Map<String, dynamic>)['copiedFileName'],
        'source.m4a',
      );

      final encoded = jsonEncode(jsonMap);
      final decodedMap = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = ProjectMapper.fromJsonMap(
        decodedMap,
        projectId: original.id,
      );

      expect(restored, original);
      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.updatedAt.isUtc, isTrue);
      expect(restored.beats.map((b) => b.type).toList(), [
        BeatType.downbeat,
        BeatType.beat,
        BeatType.strong,
        BeatType.drop,
      ]);
    },
  );

  test('M3-era project.json without detection.status loads with DetectionStatus.notRun and status round-trips', () {
    final original = sampleProject().copyWith(
      detection: const DetectionSettings(
        sensitivity: 0.65,
        filter: BeatFilter.strong,
        status: DetectionStatus.succeeded,
      ),
    );
    final fullJson = ProjectMapper.toJsonMap(original);
    expect(
      (fullJson['detection'] as Map<String, dynamic>)['status'],
      'succeeded',
    );

    final roundTripped = ProjectMapper.fromJsonMap(
      jsonDecode(jsonEncode(fullJson)) as Map<String, dynamic>,
      projectId: original.id,
    );
    expect(roundTripped.detection.status, DetectionStatus.succeeded);

    // Remove status key to simulate an M2/M3 project.json file.
    final legacyJson = jsonDecode(jsonEncode(fullJson)) as Map<String, dynamic>;
    (legacyJson['detection'] as Map<String, dynamic>).remove('status');

    final legacyRestored = ProjectMapper.fromJsonMap(
      legacyJson,
      projectId: original.id,
    );
    expect(legacyRestored.detection.status, DetectionStatus.notRun);
    expect(legacyRestored.detection.sensitivity, 0.65);
    expect(legacyRestored.detection.filter, BeatFilter.strong);
  });

  test(
    'Project derived getters compute expected values from sample indices',
    () {
      final p = sampleProject();
      expect(p.durationMs, 168750);
      expect(p.beatCount, 4);
      expect(p.strongCount, 3); // downbeat, strong, drop
      expect(p.dropCount, 1);
      expect(p.msToSamples(1000), 44100);
      expect(p.sampleToMs(44100), 1000);
      expect(p.msToSamples(1), 44);
      expect(p.msToSamples(10), 441);
      expect(p.sectionAt(100)?.name, 'Intro');
      expect(p.sectionAt(330750)?.name, 'Verse');
      expect(p.sectionAt(99999999), isNull);
    },
  );

  test('unknown or missing schemaVersion throws typed ProjectException', () {
    final jsonMap = ProjectMapper.toJsonMap(sampleProject());

    final futureVersion = Map<String, dynamic>.from(jsonMap)
      ..['schemaVersion'] = 2;
    expect(
      () => ProjectMapper.fromJsonMap(futureVersion, projectId: 'proj-1'),
      throwsA(
        isA<ProjectSchemaVersionException>().having(
          (e) => e.schemaVersion,
          'schemaVersion',
          2,
        ),
      ),
    );

    final missingVersion = Map<String, dynamic>.from(jsonMap)
      ..remove('schemaVersion');
    expect(
      () => ProjectMapper.fromJsonMap(missingVersion, projectId: 'proj-1'),
      throwsA(isA<ProjectCorruptException>()),
    );
  });

  test('timebase invariant: 1,000 beats at 44.1 kHz and 48 kHz round-trip identically', () {
    for (final rate in [44100, 48000]) {
      final beats = List<Beat>.generate(
        1000,
        (i) => Beat(
          sample: i * 19997 + (i % 7),
          type: BeatType.values[i % BeatType.values.length],
        ),
      );
      final p = sampleProject().copyWith(
        sampleRate: rate,
        sampleCount: beats.last.sample + rate,
        beats: beats,
      );

      // Display conversion (sample -> ms -> sample) may lose sub-ms precision,
      // which is why beats are stored as integer sample indices and never
      // round-tripped through milliseconds.
      for (final b in p.beats) {
        final _ = p.sampleToMs(b.sample);
      }

      final restored = ProjectMapper.fromJsonMap(
        jsonDecode(jsonEncode(ProjectMapper.toJsonMap(p)))
            as Map<String, dynamic>,
      );

      expect(restored.beats.length, 1000);
      for (var i = 0; i < 1000; i++) {
        expect(restored.beats[i].sample, beats[i].sample);
        expect(restored.beats[i].type, beats[i].type);
      }
    }
  });
}
