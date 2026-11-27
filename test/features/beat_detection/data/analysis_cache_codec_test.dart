import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/storage/project_paths.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';

import '../../../fixtures/synthetic_audio.dart';

void main() {
  late Directory tempDir;
  late ProjectPaths paths;
  late BeatDetectionRepositoryImpl repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kv_codec_m4b_test_');
    paths = ProjectPaths(tempDir.path);
    repo = BeatDetectionRepositoryImpl(paths: () async => paths);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('round-trips all M4b fields (onsetEnvelope, lowMidOnsetEnvelope, tempoCandidates, localTempo, tempoStability, swing)', () {
    final original = BeatAnalysis(
      sampleRate: 44100,
      sampleCount: 44100 * 30,
      hopSize: 512,
      bpm: 128.0,
      confidence: 3.25,
      beatPhaseSample: 1024,
      candidates: const [
        CandidateBeat(index: 0, sample: 1024, strength: 0.75, lowEnergy: 12.5),
        CandidateBeat(index: 1, sample: 21700, strength: 0.5, lowEnergy: 4.0),
      ],
      frameLowEnergy: Float32List.fromList([1.0, 2.5, 3.75, 0.5]),
      frameOverallEnergy: Float32List.fromList([5.0, 6.25, 8.0, 2.0]),
      onsetEnvelope: Float32List.fromList([0.0, 4.2, 0.1, 3.8]),
      lowMidOnsetEnvelope: Float32List.fromList([0.0, 3.9, 0.05, 3.5]),
      tempoCandidates: const [
        TempoCandidate(bpm: 128.0, periodFrames: 40.375, score: 1.0),
        TempoCandidate(bpm: 64.0, periodFrames: 80.75, score: 0.72),
        TempoCandidate(bpm: 192.0, periodFrames: 26.9167, score: 0.45),
      ],
      localTempo: Float32List.fromList([40.3, 40.4, 40.5, 40.35]),
      tempoStability: 0.0125,
      swing: const SwingEstimate(ratio: 0.65, confidence: 0.82),
    );

    expect(analysisCacheFormatVersion, greaterThanOrEqualTo(2));
    final bytes = encodeBeatAnalysis(original);
    final decoded = decodeBeatAnalysis(bytes);

    expect(decoded.sampleRate, original.sampleRate);
    expect(decoded.sampleCount, original.sampleCount);
    expect(decoded.hopSize, original.hopSize);
    expect(decoded.bpm, original.bpm);
    expect(decoded.confidence, closeTo(original.confidence, 1e-5));
    expect(decoded.beatPhaseSample, original.beatPhaseSample);
    expect(decoded.candidates.length, 2);
    expect(decoded.frameLowEnergy, [1.0, 2.5, 3.75, 0.5]);
    expect(decoded.frameOverallEnergy, [5.0, 6.25, 8.0, 2.0]);

    for (var i = 0; i < original.onsetEnvelope.length; i++) {
      expect(
        decoded.onsetEnvelope[i],
        closeTo(original.onsetEnvelope[i], 1e-5),
      );
      expect(
        decoded.lowMidOnsetEnvelope[i],
        closeTo(original.lowMidOnsetEnvelope[i], 1e-5),
      );
    }

    expect(decoded.tempoCandidates.length, 3);
    expect(decoded.tempoCandidates[0].bpm, closeTo(128.0, 0.1));
    expect(decoded.tempoCandidates[0].periodFrames, closeTo(40.375, 1e-3));
    expect(decoded.tempoCandidates[0].score, closeTo(1.0, 1e-4));
    expect(decoded.tempoCandidates[1].bpm, closeTo(64.0, 0.1));
    expect(decoded.tempoCandidates[2].bpm, closeTo(192.0, 0.1));

    expect(decoded.localTempo.length, 4);
    for (var i = 0; i < 4; i++) {
      expect(decoded.localTempo[i], closeTo(original.localTempo[i], 1e-4));
    }
    expect(decoded.tempoStability, closeTo(0.0125, 1e-5));
    expect(decoded.swing.ratio, closeTo(0.65, 1e-4));
    expect(decoded.swing.confidence, closeTo(0.82, 1e-4));
  });

  test('old-version (v1) analysis.bin triggers silent re-analysis without throwing to caller', () async {
    const projectId = 'p_v1_cache';
    final projDir = await paths.createProjectDir(projectId);
    await writeSyntheticClickTrack(
      dir: projDir,
      fileName: 'song.wav',
      bpm: 120.0,
      durationSeconds: 12.0,
    );

    // Construct a v1 header analysis.bin file.
    final v1Bytes = Uint8List(40);
    final bd = ByteData.sublistView(v1Bytes);
    v1Bytes[0] = 'K'.codeUnitAt(0);
    v1Bytes[1] = 'V'.codeUnitAt(0);
    v1Bytes[2] = 'A'.codeUnitAt(0);
    v1Bytes[3] = 'N'.codeUnitAt(0);
    bd.setUint16(4, 1, Endian.little); // version 1
    bd.setUint32(8, 44100, Endian.little);
    bd.setUint32(12, 44100 * 12, Endian.little);
    bd.setUint32(16, 512, Endian.little);

    final cacheFile = File(paths.analysisFile(projectId));
    await cacheFile.writeAsBytes(v1Bytes);

    expect(() => decodeBeatAnalysis(v1Bytes), throwsA(isA<FormatException>()));

    // Repository returns null from getCachedAnalysis and transparently re-analyzes.
    expect(await repo.getCachedAnalysis(projectId), isNull);
    final rebuilt = await repo.analyze(projectId);
    expect(rebuilt.bpm, closeTo(120.0, 1.0));
    expect(rebuilt.onsetEnvelope, isNotEmpty);
    expect(rebuilt.tempoCandidates, isNotEmpty);
  });
}
