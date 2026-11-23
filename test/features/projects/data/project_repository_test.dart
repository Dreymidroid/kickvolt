import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/overview.dart';
import 'package:kickvolt/core/audio_math/peaks.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';
import 'package:kickvolt/core/storage/project_paths.dart';
import 'package:kickvolt/features/import/import.dart';
import 'package:kickvolt/features/projects/projects.dart';

void main() {
  late Directory docs;
  late ProjectPaths paths;
  late DateTime now;
  late ProjectRepositoryImpl repo;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('project_repo_test');
    paths = ProjectPaths(docs.path);
    now = DateTime.utc(2026, 11, 22, 12, 0, 0);
    repo = ProjectRepositoryImpl(paths: () async => paths, clock: () => now);
  });

  tearDown(() {
    if (docs.existsSync()) {
      docs.deleteSync(recursive: true);
    }
  });

  ImportedSong prepareImportedSong(
    String id, {
    String title = 'Midnight Run',
    int sampleRate = 44100,
    int channels = 2,
    int frameCount = 4410,
    int peakAmplitude = 16384,
  }) {
    Directory(paths.projectDir(id)).createSync(recursive: true);
    final sourceCopy = File(paths.sourceFile(id, 'm4a'))
      ..writeAsBytesSync([1, 2, 3, 4]);
    final wavFile = File(paths.songWav(id));
    final header = buildWavHeader(
      sampleRate: sampleRate,
      channels: channels,
      frameCount: frameCount,
    );
    final data = List<int>.filled(frameCount * channels * 2, 0);
    if (frameCount > 0) {
      data[0] = peakAmplitude & 0xFF;
      data[1] = (peakAmplitude >> 8) & 0xFF;
    }
    wavFile.writeAsBytesSync([...header, ...data]);

    return ImportedSong(
      projectId: id,
      title: title,
      source: PickedSource(
        kind: ImportSourceKind.file,
        location: '/tmp/$title.m4a',
        displayName: '$title.m4a',
      ),
      sourceCopyPath: sourceCopy.path,
      wavPath: wavFile.path,
      sampleRate: sampleRate,
      channels: channels,
      frameCount: frameCount,
    );
  }

  test('createFromImport writes project.json, overview.bin, and index.json with WAV sampleCount', () async {
    final imported = prepareImportedSong('p1', frameCount: 8820);
    final created = await repo.createFromImport(imported);

    expect(created.id, 'p1');
    expect(created.title, 'Midnight Run');
    expect(created.sampleRate, 44100);
    expect(created.channels, 2);
    expect(created.sampleCount, 8820);
    expect(created.beats, isEmpty);
    expect(created.sections, isEmpty);
    expect(created.bpm, isNull);
    expect(created.source.copiedFileName, 'source.m4a');

    expect(File(paths.projectJson('p1')).existsSync(), isTrue);
    expect(File(paths.overviewBin('p1')).existsSync(), isTrue);
    expect(File(paths.indexJson).existsSync(), isTrue);

    final ov = decodeOverview(File(paths.overviewBin('p1')).readAsBytesSync());
    expect(ov.binFrames, 441);
    expect(ov.binCount, 20);
    expect(ov.bins.first, (16384 * 255) ~/ 32767);

    final list = await repo.listProjects();
    expect(list.length, 1);
    expect(list.first.id, 'p1');
    expect(list.first.thumbnail.length, 64);
    expect(list.first.durationMs, 200);
  });

  test(
    'concurrent saves, rename and delete neither fail nor lose index entries',
    () async {
      final p1 = await repo.createFromImport(prepareImportedSong('p1'));
      await repo.createFromImport(prepareImportedSong('p2', title: 'Two'));
      await repo.createFromImport(prepareImportedSong('p3', title: 'Three'));

      final titles = [for (var i = 0; i < 5; i++) 'Take $i'];
      await Future.wait([
        for (final t in titles) repo.saveProject(p1.copyWith(title: t)),
        repo.renameProject('p2', 'Renamed'),
        repo.deleteProject('p3'),
      ]);

      final list = await repo.listProjects();
      expect({for (final s in list) s.id}, {'p1', 'p2'});
      expect(titles, contains((await repo.getProject('p1')).title));
      expect((await repo.getProject('p2')).title, 'Renamed');
      final leftovers = docs
          .listSync(recursive: true)
          .where((e) => e.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    },
  );

  test(
    'createFromImport writes peaks.bin; getPeaks reads it or rebuilds it',
    () async {
      await repo.createFromImport(prepareImportedSong('p1', frameCount: 8820));
      final file = File(paths.peaksBin('p1'));
      expect(file.existsSync(), isTrue);

      final peaks = await repo.getPeaks('p1');
      expect(peaks.frameCount, 8820);
      expect(peaks.levels.map((l) => l.framesPerBucket), peakLevelFrames);
      // First frame of the left channel is 16384, right is 0: mono mix 8192.
      expect(peaks.levels.first.data[1], 8192);

      // A missing or corrupt cache is rebuilt from song.wav and rewritten.
      file.writeAsBytesSync([1, 2, 3]);
      final rebuilt = await repo.getPeaks('p1');
      expect(rebuilt.levels.first.data, peaks.levels.first.data);
      expect(decodePeaks(file.readAsBytesSync()).frameCount, 8820);

      expect(await repo.songPath('p1'), paths.songWav('p1'));
    },
  );

  test('createFromImport deletes the project folder on failure', () async {
    Directory(paths.projectDir('bad')).createSync(recursive: true);
    File(paths.songWav('bad')).writeAsBytesSync('not a wav'.codeUnits);
    const badSong = ImportedSong(
      projectId: 'bad',
      title: 'Bad',
      source: PickedSource(
        kind: ImportSourceKind.file,
        location: '/tmp/bad.mp3',
        displayName: 'bad.mp3',
      ),
      wavPath: '/unused',
      sampleRate: 44100,
      channels: 2,
      frameCount: 100,
    );

    await expectLater(repo.createFromImport(badSong), throwsA(anything));
    expect(Directory(paths.projectDir('bad')).existsSync(), isFalse);
  });

  test(
    'saveProject and getProject round-trip and update updatedAt + index order',
    () async {
      await repo.createFromImport(prepareImportedSong('p1', title: 'First'));
      now = now.add(const Duration(minutes: 5));
      final p2 = await repo.createFromImport(
        prepareImportedSong('p2', title: 'Second'),
      );

      var list = await repo.listProjects();
      expect(list.map((s) => s.id).toList(), ['p2', 'p1']);

      // Edit and save p1 later so it moves to the front of the list.
      now = now.add(const Duration(minutes: 10));
      final p1 = await repo.getProject('p1');
      final editedP1 = p1.copyWith(
        bpm: 128.0,
        beats: const [
          Beat(sample: 0, type: BeatType.strong),
          Beat(sample: 20672, type: BeatType.beat),
        ],
      );
      await repo.saveProject(editedP1);

      final reloaded = await repo.getProject('p1');
      expect(reloaded.updatedAt, now);
      expect(reloaded.bpm, 128.0);
      expect(reloaded.beatCount, 2);

      list = await repo.listProjects();
      expect(list.map((s) => s.id).toList(), ['p1', 'p2']);
      expect(list.first.beatCount, 2);
      expect(list.first.bpm, 128.0);
      expect(p2.updatedAt.isBefore(reloaded.updatedAt), isTrue);
    },
  );

  test('index is rebuilt when missing, corrupt, or out of sync with folders on disk', () async {
    await repo.createFromImport(prepareImportedSong('p1', title: 'One'));
    now = now.add(const Duration(minutes: 1));
    await repo.createFromImport(prepareImportedSong('p2', title: 'Two'));

    // 1. Delete index.json -> rebuilt.
    File(paths.indexJson).deleteSync();
    var list = await repo.listProjects();
    expect(list.map((s) => s.id).toList(), ['p2', 'p1']);
    expect(File(paths.indexJson).existsSync(), isTrue);

    // 2. Corrupt index.json -> rebuilt.
    File(paths.indexJson).writeAsStringSync('{not valid json');
    list = await repo.listProjects();
    expect(list.map((s) => s.id).toList(), ['p2', 'p1']);

    // 3. Out of sync with folders on disk (delete p2 folder behind index's back).
    Directory(paths.projectDir('p2')).deleteSync(recursive: true);
    list = await repo.listProjects();
    expect(list.map((s) => s.id).toList(), ['p1']);
  });

  test('promotes a recoverable .tmp file when project.json or index.json is missing', () async {
    await repo.createFromImport(
      prepareImportedSong('p1', title: 'Recoverable'),
    );
    final jsonFile = File(paths.projectJson('p1'));
    final tmpFile = File('${paths.projectJson('p1')}.tmp');
    jsonFile.renameSync(tmpFile.path);
    expect(jsonFile.existsSync(), isFalse);

    final loaded = await repo.getProject('p1');
    expect(loaded.title, 'Recoverable');
    expect(jsonFile.existsSync(), isTrue);
    expect(tmpFile.existsSync(), isFalse);

    // Same for index.json.tmp.
    final indexFile = File(paths.indexJson);
    final indexTmp = File('${paths.indexJson}.tmp');
    indexFile.renameSync(indexTmp.path);
    final list = await repo.listProjects();
    expect(list.single.id, 'p1');
    expect(indexFile.existsSync(), isTrue);
    expect(indexTmp.existsSync(), isFalse);
  });

  test('corrupt project.json or future schemaVersion is skipped in listProjects and throws typed exception in getProject', () async {
    await repo.createFromImport(prepareImportedSong('good', title: 'Good'));
    await repo.createFromImport(
      prepareImportedSong('corrupt', title: 'Corrupt'),
    );
    await repo.createFromImport(prepareImportedSong('future', title: 'Future'));

    File(paths.projectJson('corrupt')).writeAsStringSync('<<<corrupt>>>');
    final futureMap = jsonDecode(
      File(paths.projectJson('future')).readAsStringSync(),
    ) as Map<String, dynamic>;
    futureMap['schemaVersion'] = 99;
    File(paths.projectJson('future')).writeAsStringSync(jsonEncode(futureMap));
    File(paths.indexJson).deleteSync(); // Force rebuild

    final list = await repo.listProjects();
    expect(list.map((s) => s.id).toList(), ['good']);

    await expectLater(
      repo.getProject('corrupt'),
      throwsA(isA<ProjectCorruptException>()),
    );
    await expectLater(
      repo.getProject('future'),
      throwsA(isA<ProjectSchemaVersionException>()),
    );
    await expectLater(
      repo.getProject('nonexistent'),
      throwsA(isA<ProjectNotFoundException>()),
    );
  });

  test(
    'renameProject trims title and rejects empty or whitespace-only titles',
    () async {
      await repo.createFromImport(prepareImportedSong('p1', title: 'Old'));
      now = now.add(const Duration(minutes: 2));
      await repo.renameProject('p1', '  New Title  ');

      final p = await repo.getProject('p1');
      expect(p.title, 'New Title');
      expect((await repo.listProjects()).single.title, 'New Title');

      await expectLater(
        repo.renameProject('p1', '   '),
        throwsA(isA<InvalidProjectTitleException>()),
      );
    },
  );

  test(
    'deleteProject removes the project folder and its index entry',
    () async {
      await repo.createFromImport(prepareImportedSong('p1'));
      await repo.deleteProject('p1');

      expect(Directory(paths.projectDir('p1')).existsSync(), isFalse);
      expect(await repo.listProjects(), isEmpty);
      await expectLater(
        repo.getProject('p1'),
        throwsA(isA<ProjectNotFoundException>()),
      );
    },
  );

  test('cleanUpOrphans deletes incomplete folders and keeps complete or recoverable projects', () async {
    await repo.createFromImport(prepareImportedSong('complete'));
    await repo.createFromImport(prepareImportedSong('recoverable'));
    File(paths.projectJson('recoverable'))
        .renameSync('${paths.projectJson('recoverable')}.tmp');

    // Orphan folder with only song.wav (left by a killed import).
    prepareImportedSong('orphan');

    await repo.cleanUpOrphans();

    expect(Directory(paths.projectDir('complete')).existsSync(), isTrue);
    expect(Directory(paths.projectDir('recoverable')).existsSync(), isTrue);
    expect(File(paths.projectJson('recoverable')).existsSync(), isTrue);
    expect(Directory(paths.projectDir('orphan')).existsSync(), isFalse);
  });

  test('stored paths are relative: moving the documents directory preserves project reload', () async {
    await repo.createFromImport(prepareImportedSong('p1', title: 'Portable'));
    final rawJson = File(paths.projectJson('p1')).readAsStringSync();
    expect(rawJson.contains(docs.path), isFalse);

    final movedDocs = Directory(
      '${Directory.systemTemp.path}/moved_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      docs.renameSync(movedDocs.path);
      final movedPaths = ProjectPaths(movedDocs.path);
      final movedRepo = ProjectRepositoryImpl(
        paths: () async => movedPaths,
        clock: () => now,
      );

      final loaded = await movedRepo.getProject('p1');
      expect(loaded.title, 'Portable');
      expect(loaded.source.copiedFileName, 'source.m4a');
      expect(
        File('${movedPaths.projectDir('p1')}/${loaded.source.copiedFileName}')
            .existsSync(),
        isTrue,
      );
    } finally {
      if (movedDocs.existsSync()) {
        movedDocs.deleteSync(recursive: true);
      }
    }
  });
}
