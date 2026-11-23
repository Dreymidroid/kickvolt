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
    tempDir = await Directory.systemTemp.createTemp('kv_cache_isolate_test_');
    paths = ProjectPaths(tempDir.path);
    repo = BeatDetectionRepositoryImpl(paths: () async => paths);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Analysis cache (analysis.bin)', () {
    test('binary codec round-trips BeatAnalysis fields and arrays', () {
      final original = BeatAnalysis(
        sampleRate: 48000,
        sampleCount: 48000 * 30,
        hopSize: 512,
        bpm: 128.0,
        confidence: 3.25,
        beatPhaseSample: 1024,
        candidates: const [
          CandidateBeat(
            index: 0,
            sample: 1024,
            strength: 0.75,
            lowEnergy: 12.5,
          ),
          CandidateBeat(index: 1, sample: 23524, strength: 0.5, lowEnergy: 4.0),
        ],
        frameLowEnergy: Float32List.fromList([1.0, 2.5, 3.75, 0.5]),
        frameOverallEnergy: Float32List.fromList([5.0, 6.25, 8.0, 2.0]),
      );

      final bytes = encodeBeatAnalysis(original);
      final decoded = decodeBeatAnalysis(bytes);

      expect(decoded.sampleRate, original.sampleRate);
      expect(decoded.sampleCount, original.sampleCount);
      expect(decoded.hopSize, original.hopSize);
      expect(decoded.bpm, original.bpm);
      expect(decoded.confidence, closeTo(original.confidence, 1e-5));
      expect(decoded.beatPhaseSample, original.beatPhaseSample);
      expect(decoded.candidates.length, 2);
      expect(decoded.candidates[0].sample, 1024);
      expect(decoded.candidates[1].sample, 23524);
      expect(decoded.frameLowEnergy, [1.0, 2.5, 3.75, 0.5]);
      expect(decoded.frameOverallEnergy, [5.0, 6.25, 8.0, 2.0]);
    });

    test(
      'corrupt or old-version cache is ignored and rebuilt from song.wav',
      () async {
        const projectId = 'p_cache';
        final projDir = await paths.createProjectDir(projectId);
        await writeSyntheticClickTrack(
          dir: projDir,
          fileName: 'song.wav',
          bpm: 120.0,
          durationSeconds: 12.0,
        );

        // 1. Write corrupt bytes to analysis.bin -> getCachedAnalysis returns null,
        // analyze() rebuilds and overwrites analysis.bin.
        final cacheFile = File(paths.analysisFile(projectId));
        await cacheFile.writeAsBytes([1, 2, 3, 4, 5]);
        expect(await repo.getCachedAnalysis(projectId), isNull);

        final rebuilt = await repo.analyze(projectId);
        expect(rebuilt.bpm, closeTo(120.0, 1.0));
        expect(await cacheFile.exists(), isTrue);

        // Fresh repository instance reads the valid cache from disk without
        // re-running if we corrupt song.wav afterwards.
        final repo2 = BeatDetectionRepositoryImpl(paths: () async => paths);
        final fromDisk = await repo2.getCachedAnalysis(projectId);
        expect(fromDisk, isNotNull);
        expect(fromDisk!.candidates.length, rebuilt.candidates.length);

        // 2. Write an old/unsupported version number into analysis.bin header.
        final validBytes = Uint8List.fromList(await cacheFile.readAsBytes());
        ByteData.sublistView(validBytes).setUint16(4, 99, Endian.little);
        await cacheFile.writeAsBytes(validBytes);

        final repo3 = BeatDetectionRepositoryImpl(paths: () async => paths);
        expect(await repo3.getCachedAnalysis(projectId), isNull);
        final rebuiltAgain = await repo3.analyze(projectId);
        expect(rebuiltAgain.bpm, closeTo(120.0, 1.0));
      },
    );
  });

  group('Isolate runner', () {
    test('progress is monotonic across stages and ends at 1.0', () async {
      const projectId = 'p_iso';
      final projDir = await paths.createProjectDir(projectId);
      await writeSyntheticClickTrack(
        dir: projDir,
        fileName: 'song.wav',
        bpm: 128.0,
        durationSeconds: 15.0,
      );

      final events = <AnalysisProgress>[];
      final analysis = await repo.analyze(projectId, onProgress: events.add);

      expect(analysis.bpm, closeTo(128.0, 1.0));
      expect(events, isNotEmpty);

      var prevFrac = -1.0;
      var prevStageIdx = 0;
      for (final e in events) {
        expect(
          e.fraction,
          greaterThanOrEqualTo(prevFrac),
          reason:
              'Progress fraction went backwards: $prevFrac -> ${e.fraction}',
        );
        expect(
          e.stage.index,
          greaterThanOrEqualTo(prevStageIdx),
          reason:
              'Stage index went backwards: $prevStageIdx -> ${e.stage.index}',
        );
        prevFrac = e.fraction;
        prevStageIdx = e.stage.index;
      }
      expect(events.last.fraction, 1.0);
      expect(events.any((e) => e.bpm != null), isTrue);
    });

    test('cancel stops the isolate and the future fails with AnalysisCancelledException', () async {
      const projectId = 'p_cancel';
      final projDir = await paths.createProjectDir(projectId);
      await writeSyntheticClickTrack(
        dir: projDir,
        fileName: 'song.wav',
        bpm: 120.0,
        durationSeconds: 60.0,
      );

      final token = AnalysisCancelToken();
      final future = repo.analyze(
        projectId,
        cancelToken: token,
        onProgress: (p) {
          if (p.fraction > 0.05) {
            token.cancel();
          }
        },
      );

      await expectLater(future, throwsA(isA<AnalysisCancelledException>()));
    });
  });
}
