import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/storage/project_paths.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../../fixtures/synthetic_audio.dart';
import '../../../fixtures/synthetic_music.dart';

void main() {
  late Directory tempDir;
  late ProjectPaths paths;
  late BeatDetectionRepositoryImpl repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kv_retrack_test_');
    paths = ProjectPaths(tempDir.path);
    repo = BeatDetectionRepositoryImpl(paths: () async => paths);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('re-track from cached analysis.bin equals a fresh re-track on in-memory analysis with the same options', () async {
    const projectId = 'p_retrack_eq';
    final projDir = await paths.createProjectDir(projectId);
    final song = await writeSyntheticDnbSong(
      projDir,
      bpm: 174.0,
      seconds: 25.0,
    );
    await File(song.path).rename(paths.songWav(projectId));

    final initial = await repo.analyze(projectId);

    // Reload from disk cache in a new repository instance.
    final repoFromDisk = BeatDetectionRepositoryImpl(paths: () async => paths);
    final cached = await repoFromDisk.getCachedAnalysis(projectId);
    expect(cached, isNotNull);

    const options = TrackingOptions(
      targetBpm: 174.0,
      tempoMode: TempoMode.steady,
    );

    final fromRepo = await repoFromDisk.retrack(projectId, cached!, options);
    final direct = await retrack(
      initial,
      options,
      wavPath: paths.songWav(projectId),
    );

    expect(fromRepo.bpm, direct.bpm);
    expect(fromRepo.beatPhaseSample, direct.beatPhaseSample);
    expect(
      fromRepo.candidates.map((c) => c.sample).toList(),
      direct.candidates.map((c) => c.sample).toList(),
    );

    // Second call with the same options uses the in-memory option cache
    // without touching song.wav on disk (verify by deleting song.wav first).
    await File(paths.songWav(projectId)).delete();
    final cachedRetrack = await repoFromDisk.retrack(
      projectId,
      cached,
      options,
    );
    expect(identical(cachedRetrack, fromRepo), isTrue);
  });

  test('cancelling mid-retrack closes song.wav so the project folder is deletable immediately on Windows', () async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final projectId = 'p_cancel_$attempt';
      final projDir = await paths.createProjectDir(projectId);
      await writeSyntheticClickTrack(
        dir: projDir,
        fileName: 'song.wav',
        bpm: 140.0,
        durationSeconds: 90.0,
      );

      final analysis = await repo.analyze(projectId);
      final token = AnalysisCancelToken();

      Object? caught;
      final future = repo
          .retrack(
            projectId,
            analysis,
            const TrackingOptions(
              targetBpm: 140.0,
              tempoMode: TempoMode.varying,
            ),
            cancelToken: token,
          )
          .then<void>((_) {}, onError: (Object e) => caught = e);

      // Cancel while isolate is spawning / running.
      await Future<void>.delayed(Duration(milliseconds: attempt * 5));
      await token.cancel();
      await future;

      expect(caught, isA<AnalysisCancelledException>());

      // Immediately delete the project folder; fails on Windows if song.wav is still open.
      await projDir.delete(recursive: true);
      expect(await projDir.exists(), isFalse);
    }
  });

  test('performance: re-tracking a 3-minute 44.1 kHz song completes in < 1 s', () async {
    const projectId = 'p_perf_3min';
    final projDir = await paths.createProjectDir(projectId);
    await writeSyntheticClickTrack(
      dir: projDir,
      fileName: 'song.wav',
      bpm: 128.0,
      sampleRate: 44100,
      channels: 2,
      durationSeconds: 180.0,
    );

    final fullSw = Stopwatch()..start();
    final analysis = await repo.analyze(projectId, forceReanalyze: true);
    fullSw.stop();

    final retrackSw = Stopwatch()..start();
    final retracked = await repo.retrack(
      projectId,
      analysis,
      const TrackingOptions(targetBpm: 64.0, tempoMode: TempoMode.steady),
    );
    retrackSw.stop();

    final retrackVaryingSw = Stopwatch()..start();
    final retrackedVarying = await repo.retrack(
      projectId,
      analysis,
      const TrackingOptions(targetBpm: 128.0, tempoMode: TempoMode.varying),
    );
    retrackVaryingSw.stop();

    // ignore: avoid_print
    print(
      'PERF_RETRACK_3MIN | fullAnalyze=${fullSw.elapsedMilliseconds}ms '
      '| retrackSteady=${retrackSw.elapsedMilliseconds}ms '
      '| retrackVarying=${retrackVaryingSw.elapsedMilliseconds}ms',
    );

    expect(retracked.bpm, closeTo(64.0, 1.0));
    expect(retrackedVarying.bpm, closeTo(128.0, 1.0));
    expect(
      retrackSw.elapsedMilliseconds,
      lessThan(1000),
      reason:
          'Re-track steady took ${retrackSw.elapsedMilliseconds} ms (limit 1,000 ms)',
    );
    expect(
      retrackVaryingSw.elapsedMilliseconds,
      lessThan(1000),
      reason:
          'Re-track varying took ${retrackVaryingSw.elapsedMilliseconds} ms (limit 1,000 ms)',
    );
  });
}
