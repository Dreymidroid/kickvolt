import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_detection/domain/beat_analyzer.dart';
import 'package:kickvolt/features/beat_detection/domain/beat_classifier.dart';
import 'package:kickvolt/features/projects/domain/entities/section.dart';

import '../../../fixtures/synthetic_audio.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kv_sections_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  void verifySectionInvariants({
    required List<Section> sections,
    required Set<int> beatSamples,
    required int sampleCount,
  }) {
    expect(sections, isNotEmpty);
    expect(sections.first.startSample, 0);
    expect(sections.last.endSample, sampleCount);

    final validColors = {for (final p in sectionPresets) p.name: p.colorArgb};

    for (var i = 0; i < sections.length; i++) {
      final s = sections[i];
      expect(
        s.endSample,
        greaterThan(s.startSample),
        reason: 'Section $i has non-positive length: $s',
      );
      expect(
        validColors[s.name],
        s.colorArgb,
        reason: 'Section $i color does not match sectionPresets for ${s.name}',
      );
      if (i > 0) {
        // Contiguous and non-overlapping
        expect(
          s.startSample,
          sections[i - 1].endSample,
          reason: 'Section $i is not contiguous with section ${i - 1}',
        );
        // Interior boundaries must sit on beat samples
        expect(
          beatSamples.contains(s.startSample),
          isTrue,
          reason:
              'Interior boundary ${s.startSample} of section $i is not on a beat sample',
        );
      }
      if (i < sections.length - 1) {
        expect(
          beatSamples.contains(s.endSample),
          isTrue,
          reason:
              'Interior boundary ${s.endSample} of section $i is not on a beat sample',
        );
      }
    }
  }

  test(
    'sections invariants hold on the drops fixture and include Drop section',
    () async {
      final track = await writeSyntheticDropTrack(dir: tempDir);
      final analysis = await analyzeWavFile(track.wavPath);
      final result = classifyBeats(analysis, sensitivity: 0.5);

      expect(result.succeeded, isTrue);
      final beatSamples = {for (final b in result.beats) b.sample};
      verifySectionInvariants(
        sections: result.sections,
        beatSamples: beatSamples,
        sampleCount: track.sampleCount,
      );

      expect(
        result.sections.any((s) => s.name == SectionPreset.drop.name),
        isTrue,
        reason: 'Expected a Drop section on the drops fixture',
      );
    },
  );

  test('sections invariants hold on a song with no drops', () async {
    final track = await writeSyntheticClickTrack(
      dir: tempDir,
      bpm: 120.0,
      durationSeconds: 45.0,
      accentEvery4th: true,
    );
    final analysis = await analyzeWavFile(track.wavPath);
    final result = classifyBeats(analysis, sensitivity: 0.5);

    expect(result.succeeded, isTrue);
    final beatSamples = {for (final b in result.beats) b.sample};
    verifySectionInvariants(
      sections: result.sections,
      beatSamples: beatSamples,
      sampleCount: track.sampleCount,
    );
  });

  test('sections are skipped entirely on detection failure', () async {
    final noisePath = await writeWhiteNoiseTrack(
      dir: tempDir,
      durationSeconds: 15.0,
    );
    final analysis = await analyzeWavFile(noisePath);
    final result = classifyBeats(analysis, sensitivity: 0.5);

    expect(result.succeeded, isFalse);
    expect(result.sections, isEmpty);
  });
}
