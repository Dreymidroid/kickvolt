// End-to-end flows I1–I13 (docs/handoff/E2E-testing.md §A3.2) on a real
// device: real native decode/encode, real files. Only the system pickers,
// share sheet, SAF folder picker and haptics are scripted (support/fakes).
//
// Run all:   flutter test integration_test -d <device>
// Run one:   flutter test integration_test/app_test.dart -d <device> --plain-name "I5"
//
// Measured numbers are printed as `E2E_RESULT | <flow> | ...` lines.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kickvolt/core/core.dart';
import 'package:kickvolt/features/features.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';
import 'support/fixture_audio.dart';
import 'support/mp4_to_adts.dart';
import 'support/signal.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final app = E2EApp();

  // ---------------------------------------------------------------------
  // I1 — Import WAV → Analyzing → editor
  // ---------------------------------------------------------------------
  for (final (rate, ch, name) in [
    (44100, 2, 'fx_44k_stereo'),
    (48000, 1, 'fx_48k_mono'),
  ]) {
    testWidgets('I1 import WAV $name', (tester) async {
      await app.launch(tester);
      final fx = FixtureAudio.generate(sampleRate: rate, channels: ch);
      final src = await app.writeScratch('$name.wav', fx.wavBytes());

      final sw = Stopwatch()..start();
      final ready = await app.importToEditor(tester, src);
      final importMs = sw.elapsedMilliseconds;
      final id = ready.project.id;

      final song = await readPcm16(app.paths.songWav(id));
      expect(song.info.sampleRate, rate);
      expect(song.channels, ch);
      expect(song.frames, fx.frameCount);
      final pcmIdentical = bytesEqual(
        song.dataBytes,
        fx.wavBytes().sublist(44),
      );
      expect(pcmIdentical, isTrue, reason: 'WAV→WAV decode changed samples');

      final json = await app.readProjectJson(id);
      final bpm = (json['bpm'] as num).toDouble();
      expect((bpm - 120).abs(), lessThanOrEqualTo(1), reason: 'bpm=$bpm');
      final beats = E2EApp.beatSamplesOf(json);
      final offs = signedOffsets(beats, fx.beatSamples);
      final worstMs = offs.map((o) => o.abs()).reduce(math.max) * 1000 / rate;
      expect(worstMs, lessThanOrEqualTo(10));
      expect(beats.length, fx.beatSamples.length);

      // Timing of the two native/compute stages on their own.
      final dsw = Stopwatch()..start();
      await app.audio.decodeToWav(
        jobId: 'bench-$name',
        inputPath: src,
        outputPath: app.scratchPath('bench_$name.wav'),
      );
      final decodeMs = dsw.elapsedMilliseconds;
      final asw = Stopwatch()..start();
      await analyzeWavFile(app.paths.songWav(id));
      final analyzeMs = asw.elapsedMilliseconds;
      report(
        'I1 $name',
        'frames=${song.frames} pcmIdentical=$pcmIdentical bpm=$bpm '
            'beats=${beats.length}/${fx.beatSamples.length} '
            'worst=${worstMs.toStringAsFixed(2)}ms importTotal=${importMs}ms '
            'decode=${decodeMs}ms analyze=${analyzeMs}ms',
      );

      await app.backToHome(tester);
      await pumpUntilFound(tester, find.text(name));
    });
  }

  // ---------------------------------------------------------------------
  // I2 — compressed formats. No ffmpeg/LAME on the host, so the M4A is made
  // on the device by the app's own encodeM4a (encoder→decoder round trip)
  // and the .aac is the same AAC frames rewrapped as ADTS. MP3 and MP4
  // video fixtures can't be produced here (Blocked in the results).
  // ---------------------------------------------------------------------
  for (final (rate, ch, container) in [
    (44100, 2, 'm4a'),
    (48000, 1, 'm4a'),
    (44100, 2, 'aac'),
    (48000, 1, 'aac'),
  ]) {
    final name = 'fx_${rate ~/ 1000}k_${ch == 2 ? 'stereo' : 'mono'}';
    testWidgets('I2 import $container $name (device-encoded)', (tester) async {
      await app.launch(tester);
      final fx = FixtureAudio.generate(sampleRate: rate, channels: ch);
      final wav = await app.writeScratch('$name.src.wav', fx.wavBytes());
      final m4aPath = app.scratchPath('$name.m4a');
      final enc = await app.audio.encodeM4a(
        jobId: 'fixture-$name',
        wavPath: wav,
        outPath: m4aPath,
      );
      expect(enc.sampleRate, rate);
      expect(enc.channels, ch);
      var src = m4aPath;
      if (container == 'aac') {
        final adts = m4aToAdts(
          await File(m4aPath).readAsBytes(),
          sampleRate: rate,
          channels: ch,
        );
        src = await app.writeScratch('$name.aac', adts);
      }

      final sw = Stopwatch()..start();
      final ready = await app.importToEditor(tester, src);
      final importMs = sw.elapsedMilliseconds;
      final id = ready.project.id;

      final song = await readPcm16(app.paths.songWav(id));
      expect(song.info.sampleRate, rate);
      expect(song.channels, ch);
      final frameDiff = song.frames - fx.frameCount;

      // Decoder shift: cross-correlate the first 4 s.
      final n = 4 * rate;
      final lag = crossCorrelationLag(
        monoMix(song.pcm, ch, count: n),
        monoMix(fx.pcm, ch, count: n),
      );

      final json = await app.readProjectJson(id);
      final bpm = (json['bpm'] as num).toDouble();
      final beats = E2EApp.beatSamplesOf(json);
      final offs = signedOffsets(beats, fx.beatSamples);
      final spreadMs =
          (offs.reduce(math.max) - offs.reduce(math.min)) * 1000 / rate;
      final meanOff = offs.reduce((a, b) => a + b) / offs.length;
      report(
        'I2 $container $name',
        'encoded=${enc.frameCount}f/${enc.durationUs}us '
            'decodedFrames=${song.frames} fixtureFrames=${fx.frameCount} '
            'frameDiff=$frameDiff xcorrLag=$lag bpm=$bpm '
            'beats=${beats.length}/${fx.beatSamples.length} '
            'beatOffset mean=${meanOff.toStringAsFixed(1)}f '
            '(${(meanOff * 1000 / rate).toStringAsFixed(2)}ms) '
            'min=${offs.reduce(math.min)} max=${offs.reduce(math.max)} '
            'spread=${spreadMs.toStringAsFixed(2)}ms importTotal=${importMs}ms',
      );

      // Priming + padding of AAC is at most a few 1024-sample frames.
      expect(frameDiff.abs(), lessThanOrEqualTo(4096));
      expect(lag.normalised, greaterThan(0.9), reason: '$lag');
      expect((bpm - 120).abs(), lessThanOrEqualTo(1), reason: 'bpm=$bpm');
      // A constant shift is the decoder's priming; ±1 ms around it.
      expect(spreadMs, lessThanOrEqualTo(2), reason: 'offsets=$offs');
    });
  }

  // ---------------------------------------------------------------------
  // I3 — unsupported file
  // ---------------------------------------------------------------------
  testWidgets('I3 unsupported file (.txt renamed .mp3)', (tester) async {
    await app.launch(tester);
    final src = await app.writeScratch(
      'not_a_song.mp3',
      'This is a plain text file, not audio.\n'.codeUnits,
    );
    await app.startImport(tester, src);
    await pumpUntilFound(tester, find.text('Can’t open this file'));
    expect(
      find.textContaining('isn’t a format we can read', findRichText: true),
      findsOneWidget,
    );
    expect(await app.projectDirs(), isEmpty);
    report('I3', 'error dialog shown, projectDirs=${await app.projectDirs()}');
  });

  // ---------------------------------------------------------------------
  // I4 — cancel during Analyzing
  // ---------------------------------------------------------------------
  testWidgets('I4 cancel during Analyzing', (tester) async {
    await app.launch(tester);
    // Long enough that decode + detection can't finish before the tap.
    final fx = FixtureAudio.generate(seconds: 240);
    final src = await app.writeScratch('fx_long.wav', fx.wavBytes());
    await app.startImport(tester, src);
    await pumpUntilFound(tester, find.text('Finding your beats…'));
    final dirsDuring = await app.projectDirs();
    await tester.tap(find.text('Cancel'));
    await pumpUntilFound(tester, find.text('No beat packs yet'));
    await pumpUntil(
      tester,
      () async => (await app.projectDirs()).isEmpty,
      reason: 'project folder deleted after cancel',
    );
    report('I4', 'dirsWhileAnalyzing=${dirsDuring.length} dirsAfter=0');
  });

  // ---------------------------------------------------------------------
  // I5 — editor edits persist exactly
  // ---------------------------------------------------------------------
  testWidgets('I5 editor edits persist to project.json', (tester) async {
    await app.launch(tester);
    final fx = FixtureAudio.generate();
    final src = await app.writeScratch('fx_edit.wav', fx.wavBytes());
    var s = await app.importToEditor(tester, src);
    final cubit = app.editorCubit(tester);
    final id = s.project.id;
    final project = s.project;
    var expected = [for (final b in project.beats) b.sample];
    expect(expected.length, greaterThan(8));

    Future<void> tapMarker(int index) async {
      final timeline = find.byType(BeatTimeline);
      final box = tester.getRect(timeline);
      final sample = cubit.state is BeatEditorReady
          ? (cubit.state as BeatEditorReady).project.beats[index].sample
          : 0;
      final x =
          box.width / 2 + (sample - cubit.playheadSample) * cubit.pxPerSample;
      await tester.tapAt(box.topLeft + Offset(x, box.height * 0.6));
      await pumpUntil(
        tester,
        () => (cubit.state as BeatEditorReady).selectedIndex == index,
        timeout: const Duration(seconds: 5),
        reason: 'marker $index selected',
      );
    }

    // 1. Tap marker 3 and nudge it +10 ms.
    await tapMarker(3);
    await tester.tap(bySemanticsLabel('Nudge right 10 milliseconds'));
    await tester.pump();
    expected[3] += project.msToSamples(10);

    // 2. Tap marker 6 and delete it, 3. undo the delete.
    await tapMarker(6);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(
      (cubit.state as BeatEditorReady).project.beats.length,
      expected.length - 1,
    );
    await tester.tap(bySemanticsLabel('Undo'));
    await tester.pump();
    expect(
      (cubit.state as BeatEditorReady).project.beats.length,
      expected.length,
    );

    // 4. Deselect (tap empty space between markers 1 and 2), Snap off,
    //    seek on the overview strip, Add at playhead.
    {
      final st = cubit.state as BeatEditorReady;
      final box = tester.getRect(find.byType(BeatTimeline));
      final mid =
          (st.project.beats[1].sample + st.project.beats[2].sample) ~/ 2;
      final x =
          box.width / 2 + (mid - cubit.playheadSample) * cubit.pxPerSample;
      await tester.tapAt(box.topLeft + Offset(x, box.height * 0.6));
      await pumpUntil(
        tester,
        () => (cubit.state as BeatEditorReady).selectedIndex == null,
        timeout: const Duration(seconds: 5),
        reason: 'deselected',
      );
    }
    if ((cubit.state as BeatEditorReady).snap) {
      await tester.tap(find.text('Snap'));
      await pumpUntil(
        tester,
        () => !(cubit.state as BeatEditorReady).snap,
        timeout: const Duration(seconds: 5),
        reason: 'snap off',
      );
    }
    final strip = tester.getRect(find.byType(OverviewStrip));
    // 37% through the song lands between two beats.
    await tester.tapAt(strip.centerLeft + Offset(strip.width * 0.37, 0));
    await tester.pump();
    final before = {
      for (final b in (cubit.state as BeatEditorReady).project.beats) b.sample,
    };
    final playheadAtAdd = cubit.playheadSample;
    await tester.tap(find.text('Add at playhead'));
    await tester.pump();
    final added = (cubit.state as BeatEditorReady).project.beats
        .map((b) => b.sample)
        .where((x) => !before.contains(x))
        .toList();
    expect(added, hasLength(1));
    expect((added.single - playheadAtAdd).abs(), lessThanOrEqualTo(1));
    expected = [...expected, added.single]..sort();

    // 5. Bulk › Shift earlier ×20 (1 ms each) › Apply.
    await tester.tap(find.text('Bulk'));
    await pumpUntilFound(tester, find.text('Shift all beats'));
    for (var i = 0; i < 20; i++) {
      await tester.tap(bySemanticsLabel('Shift earlier'));
      await tester.pump();
    }
    expect((cubit.state as BeatEditorReady).bulkShiftMs, -20);
    await tester.tap(find.text('Apply'));
    await tester.pump();
    final shift = project.msToSamples(-20);
    expected = [for (final x in expected) x + shift];
    expect([
      for (final b in (cubit.state as BeatEditorReady).project.beats) b.sample,
    ], expected);

    // Leave the editor (flushes the debounced save), then reopen.
    await app.backToHome(tester);
    await pumpUntil(
      tester,
      () async => _listEq(
        E2EApp.beatSamplesOf(await app.readProjectJson(id)),
        expected,
      ),
      reason: 'project.json beats == expected',
    );
    await tester.tap(find.text('fx_edit'));
    s = await app.waitForEditor(tester);
    final reopened = [for (final b in s.project.beats) b.sample];
    expect(reopened, expected);
    expect(E2EApp.beatSamplesOf(await app.readProjectJson(id)), expected);
    report('I5', 'beats=${expected.length} persisted exactly; shift=$shift');
  });

  // ---------------------------------------------------------------------
  // I6 — WAV pack
  // ---------------------------------------------------------------------
  testWidgets('I6 export WAV pack (song + guide + preview)', (tester) async {
    await app.launch(tester);
    final fx = FixtureAudio.generate();
    final src = await app.writeScratch('fx_wav_pack.wav', fx.wavBytes());
    final s = await app.importToEditor(tester, src);
    final id = s.project.id;
    await tester.tap(find.text('Export'));
    await pumpUntilFound(tester, find.text('Export beat pack'));
    await tester.tap(bySemanticsLabel('Include preview mix'));
    await pumpUntilFound(tester, find.text('Export 3 files'));
    final options = (app.exportCubit(tester).state as ExportEditing).options;
    final planned = planBeatPack(s.project, options);
    final sw = Stopwatch()..start();
    await tester.tap(find.text('Export 3 files'));
    await pumpUntilFound(tester, find.text('Share'));
    final exportMs = sw.elapsedMilliseconds;
    final pack = (app.exportCubit(tester).state as ExportDone).pack;

    // Planned names, nothing else in the folder.
    final names = [for (final f in pack.files) p.basename(f.path)];
    expect(names, [for (final f in planned.files) f.fileName]);
    final onDisk = [
      await for (final e in Directory(pack.directoryPath).list())
        p.basename(e.path),
    ]..sort();
    expect(onDisk, [...names]..sort());

    final songWav = app.paths.songWav(id);
    final song = await readPcm16(songWav);
    final songFile = pack.files.firstWhere(
      (f) => f.kind == ExportFileKind.song,
    );
    expect(
      bytesEqual(
        await File(songFile.path).readAsBytes(),
        await File(songWav).readAsBytes(),
      ),
      isTrue,
      reason: 'exported song must be byte-identical to song.wav',
    );

    final visible = planned.visibleBeatSamples;
    for (final kind in [ExportFileKind.guide, ExportFileKind.preview]) {
      final f = pack.files.firstWhere((f) => f.kind == kind);
      final w = await readPcm16(f.path);
      expect(w.info.sampleRate, song.info.sampleRate, reason: '$kind rate');
      expect(w.channels, song.channels, reason: '$kind channels');
      expect(w.frames, song.frames, reason: '$kind frames');
      expect(
        await File(f.path).length(),
        w.info.dataOffset + w.frames * w.channels * 2,
        reason: '$kind data size',
      );
    }
    final guide = await readPcm16(
      pack.files.firstWhere((f) => f.kind == ExportFileKind.guide).path,
    );
    final clickLen = renderClick(
      options.clickStyle,
      song.info.sampleRate,
    ).length;
    _expectClicksExactlyAt(guide, visible, clickLen);

    await tester.tap(find.text('Share'));
    await tester.pump();
    expect(app.share.calls.last, pack.filePaths);
    await tester.tap(find.text('Save to Files'));
    await pumpUntilFound(tester, find.text('Saved 3 files'));
    expect(app.audio.saveCalls.last, pack.filePaths);
    report(
      'I6',
      'files=$names clicks=${visible.length} frames=${song.frames} '
          'songByteIdentical=true export=${exportMs}ms',
    );
  });

  // ---------------------------------------------------------------------
  // I7 — M4A pack: song and guide stay in sync
  // ---------------------------------------------------------------------
  for (final (rate, ch, name) in [
    (44100, 2, 'fx_m4a_44k'),
    (48000, 1, 'fx_m4a_48k'),
  ]) {
    testWidgets('I7 export M4A pack $name', (tester) async {
      await app.launch(tester);
      final fx = FixtureAudio.generate(sampleRate: rate, channels: ch);
      final src = await app.writeScratch('$name.wav', fx.wavBytes());
      final s = await app.importToEditor(tester, src);
      final id = s.project.id;
      await tester.tap(find.text('Export'));
      await pumpUntilFound(tester, find.text('Export beat pack'));
      await tester.tap(find.text('M4A'));
      await pumpUntilFound(tester, find.text(kM4aWarning));
      final options = (app.exportCubit(tester).state as ExportEditing).options;
      expect(options.format, AudioFormat.m4a);
      final planned = planBeatPack(s.project, options);
      final sw = Stopwatch()..start();
      await tester.tap(find.text('Export 2 files'));
      await pumpUntilFound(tester, find.text('Share'));
      final exportMs = sw.elapsedMilliseconds;
      final pack = (app.exportCubit(tester).state as ExportDone).pack;
      final songM4a = pack.files
          .firstWhere((f) => f.kind == ExportFileKind.song)
          .path;
      final guideM4a = pack.files
          .firstWhere((f) => f.kind == ExportFileKind.guide)
          .path;
      expect(p.extension(songM4a), '.m4a');
      expect(p.extension(guideM4a), '.m4a');

      final songProbe = await app.audio.probeMedia(songM4a);
      final guideProbe = await app.audio.probeMedia(guideM4a);
      expect(songProbe.sampleRate, rate);
      expect(songProbe.channels, ch);
      expect(guideProbe.sampleRate, rate);
      expect(
        guideProbe.channels,
        planned.files
            .firstWhere((f) => f.kind == ExportFileKind.guide)
            .channels,
      );

      // Decode both back with the app's own decoder.
      final decSongPath = app.scratchPath('$name.song.dec.wav');
      final decGuidePath = app.scratchPath('$name.guide.dec.wav');
      await app.audio.decodeToWav(
        jobId: 'dec-song',
        inputPath: songM4a,
        outputPath: decSongPath,
      );
      await app.audio.decodeToWav(
        jobId: 'dec-guide',
        inputPath: guideM4a,
        outputPath: decGuidePath,
      );
      final songWav = await readPcm16(app.paths.songWav(id));
      final decSong = await readPcm16(decSongPath);
      final decGuide = await readPcm16(decGuidePath);

      // Expected (uncompressed) guide, rendered with the app's own code.
      final expGuidePath = app.scratchPath('$name.guide.expected.wav');
      await renderGuideTrack(
        songWavPath: app.paths.songWav(id),
        outputWavPath: expGuidePath,
        beatSamples: planned.visibleBeatSamples,
        style: options.clickStyle,
        channels: decGuide.channels,
      );
      final expGuide = await readPcm16(expGuidePath);

      final n = 4 * rate;
      final songLag = crossCorrelationLag(
        monoMix(decSong.pcm, decSong.channels, count: n),
        monoMix(songWav.pcm, songWav.channels, count: n),
      );
      final guideLag = crossCorrelationLag(
        monoMix(decGuide.pcm, decGuide.channels, count: n),
        monoMix(expGuide.pcm, expGuide.channels, count: n),
      );
      report(
        'I7 $name',
        'songProbe=${songProbe.frameCount}f/${songProbe.durationUs}us '
            'guideProbe=${guideProbe.frameCount}f decodedSong=${decSong.frames}f '
            'decodedGuide=${decGuide.frames}f songWav=${songWav.frames}f '
            'songLag=$songLag guideLag=$guideLag '
            'syncDiff=${songLag.lag - guideLag.lag} export=${exportMs}ms',
      );
      expect(songLag.normalised, greaterThan(0.9));
      expect(guideLag.normalised, greaterThan(0.5));
      expect((songLag.lag - guideLag.lag).abs(), lessThanOrEqualTo(1));
    });
  }

  // ---------------------------------------------------------------------
  // I8 — filter "every 2nd" + mono guide
  // ---------------------------------------------------------------------
  testWidgets('I8 export with every-2nd filter and mono guide', (tester) async {
    await app.launch(tester);
    // Settings › Mono guide track.
    await pumpUntilFound(tester, bySemanticsLabel('Settings'));
    await tester.tap(bySemanticsLabel('Settings'));
    await pumpUntilFound(
      tester,
      bySemanticsLabel('Mono guide track (smaller file)'),
    );
    await tester.tap(bySemanticsLabel('Mono guide track (smaller file)'));
    await pumpUntil(
      tester,
      () async =>
          (await SharedPreferences.getInstance()).getBool(
            SettingsRepositoryImpl.MONO_GUIDE_TRACK,
          ) ==
          true,
      reason: 'mono guide saved',
    );
    await tester.pageBack();
    await pumpUntilFound(tester, find.text('No beat packs yet'));

    final fx = FixtureAudio.generate();
    final src = await app.writeScratch('fx_every2.wav', fx.wavBytes());
    await app.importToEditor(tester, src);
    final cubit = app.editorCubit(tester);
    await tester.tap(find.text('Re-detect'));
    await pumpUntilFound(tester, find.text('Every 2nd'));
    await tester.tap(find.text('Every 2nd'));
    await tester.pump();
    await pumpUntil(
      tester,
      () => !(cubit.state as BeatEditorReady).retracking,
      reason: 'preview ready',
    );
    await tester.tap(find.text('Detect beats'));
    await pumpUntil(
      tester,
      () =>
          (cubit.state as BeatEditorReady).activeSheet == EditorSheet.none &&
          (cubit.state as BeatEditorReady).project.detection.filter ==
              BeatFilter.every2nd,
      reason: 'every-2nd committed',
    );
    final project = (cubit.state as BeatEditorReady).project;
    final visibleIdx = visibleBeatIndices(project);
    final visible = [for (final i in visibleIdx) project.beats[i].sample];
    final hidden = [
      for (var i = 0; i < project.beats.length; i++)
        if (!visibleIdx.contains(i)) project.beats[i].sample,
    ];
    expect(hidden, isNotEmpty);

    await tester.tap(find.text('Export'));
    await pumpUntilFound(tester, find.text('Export 2 files'));
    final options = (app.exportCubit(tester).state as ExportEditing).options;
    expect(options.monoGuide, isTrue);
    await tester.tap(find.text('Export 2 files'));
    await pumpUntilFound(tester, find.text('Share'));
    final pack = (app.exportCubit(tester).state as ExportDone).pack;
    final guide = await readPcm16(
      pack.files.firstWhere((f) => f.kind == ExportFileKind.guide).path,
    );
    expect(guide.channels, 1);
    final clickLen = renderClick(
      options.clickStyle,
      guide.info.sampleRate,
    ).length;
    _expectClicksExactlyAt(guide, visible, clickLen);
    for (final h in hidden) {
      expect(guide.pcm[h], 0, reason: 'hidden beat at $h must be silent');
    }
    report(
      'I8',
      'beats=${project.beats.length} visible=${visible.length} '
          'hidden=${hidden.length} guideChannels=${guide.channels}',
    );
  });

  // ---------------------------------------------------------------------
  // I9 — cancel export
  // ---------------------------------------------------------------------
  testWidgets('I9 cancel export, then export again', (tester) async {
    await app.launch(tester);
    final fx = FixtureAudio.generate(seconds: 180);
    final src = await app.writeScratch('fx_cancel_export.wav', fx.wavBytes());
    final s = await app.importToEditor(
      tester,
      src,
      timeout: const Duration(minutes: 4),
    );
    final id = s.project.id;
    await tester.tap(find.text('Export'));
    await pumpUntilFound(tester, find.text('Export beat pack'));
    await tester.tap(find.text('M4A'));
    await tester.tap(bySemanticsLabel('Include preview mix'));
    await pumpUntilFound(tester, find.text('Export 3 files'));
    await tester.tap(find.text('Export 3 files'));
    await pumpUntilFound(tester, find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await pumpUntilFound(tester, find.text('Export 3 files'));

    Future<List<String>> packDirs() async {
      final d = Directory(app.paths.exportsDir(id));
      if (!await d.exists()) return const [];
      return [
        await for (final e in d.list())
          if (e is Directory) p.basename(e.path),
      ];
    }

    await pumpUntil(
      tester,
      () async => (await packDirs()).isEmpty,
      reason: 'cancelled pack folder removed',
    );

    await tester.tap(find.text('WAV'));
    await tester.tap(find.text('Export 3 files'));
    await pumpUntilFound(
      tester,
      find.text('Share'),
      timeout: const Duration(minutes: 3),
    );
    final pack = (app.exportCubit(tester).state as ExportDone).pack;
    for (final f in pack.files) {
      expect(await File(f.path).exists(), isTrue);
    }
    expect(await packDirs(), hasLength(1));
    report('I9', 'cancel removed folder; re-export files=${pack.files.length}');
  });

  // ---------------------------------------------------------------------
  // I11 — first run
  // ---------------------------------------------------------------------
  testWidgets('I11 first run: onboarding, second launch, coach marks once', (
    tester,
  ) async {
    await app.launch(tester, onboardingDone: false, coachMarksDone: false);
    await pumpUntilFound(tester, find.text('Skip'));
    await tester.tap(find.text('Skip').first);
    await pumpUntilFound(tester, find.text('No beat packs yet'));

    // Second launch: services rebuilt, settings re-read from disk.
    await app.launch(tester, wipe: false);
    await pumpUntilFound(tester, find.text('No beat packs yet'));
    expect(find.text('Skip'), findsNothing);

    final fx = FixtureAudio.generate();
    final src = await app.writeScratch('fx_first_run.wav', fx.wavBytes());
    await app.importToEditor(tester, src);
    await pumpUntilFound(tester, find.text('Your beats live here'));
    await tester.tap(find.text('Next'));
    await pumpUntilFound(tester, find.text('Pick how you mark'));
    await tester.tap(find.text('Next'));
    await pumpUntilFound(tester, find.text('Export when it looks right'));
    await tester.tap(find.text('Got it'));
    await pumpUntil(
      tester,
      () => find.text('Export when it looks right').evaluate().isEmpty,
      reason: 'coach marks dismissed',
    );
    await pumpUntil(
      tester,
      () async =>
          (await SharedPreferences.getInstance()).getBool(
            SettingsRepositoryImpl.COACH_MARKS_DONE,
          ) ==
          true,
      reason: 'coach marks saved',
    );
    await app.backToHome(tester);
    await tester.tap(find.text('fx_first_run'));
    await app.waitForEditor(tester);
    await tester.pump();
    expect(find.text('Your beats live here'), findsNothing);
    report('I11', 'onboarding→Skip→Home; relaunch→Home; coach marks once');
  });

  // ---------------------------------------------------------------------
  // I12 (partial) — 174 BPM: Auto-detect › 2× when detection picks 87.
  // The tempo-ramp half of I12 has no fixture yet.
  // ---------------------------------------------------------------------
  testWidgets('I12 174 BPM fixture, 2x tempo choice', (tester) async {
    await app.launch(tester);
    final fx = FixtureAudio.generate(bpm: 174, seconds: 12);
    final src = await app.writeScratch('fx_174.wav', fx.wavBytes());
    final s = await app.importToEditor(tester, src);
    final cubit = app.editorCubit(tester);
    final firstBpm = s.project.bpm;
    var usedDouble = false;
    if (firstBpm != null && (firstBpm - 87).abs() <= 1) {
      await tester.tap(find.text('Re-detect'));
      await pumpUntilFound(tester, find.text('2×'));
      await tester.tap(find.text('2×'));
      await tester.pump();
      await pumpUntil(
        tester,
        () => !(cubit.state as BeatEditorReady).retracking,
        reason: '2x preview ready',
      );
      await tester.tap(find.text('Detect beats'));
      await pumpUntil(
        tester,
        () => (cubit.state as BeatEditorReady).activeSheet == EditorSheet.none,
        reason: 'committed',
      );
      usedDouble = true;
    }
    final project = (cubit.state as BeatEditorReady).project;
    final beats = [for (final b in project.beats) b.sample];
    final offs = signedOffsets(beats, fx.beatSamples);
    final worstMs = offs.map((o) => o.abs()).reduce(math.max) * 1000 / 44100;
    report(
      'I12',
      'firstBpm=$firstBpm usedDouble=$usedDouble finalBpm=${project.bpm} '
          'beats=${beats.length}/${fx.beatSamples.length} '
          'worst=${worstMs.toStringAsFixed(2)}ms',
    );
    expect((project.bpm! - 174).abs(), lessThanOrEqualTo(1));
    expect(worstMs, lessThanOrEqualTo(10));
  });

  // ---------------------------------------------------------------------
  // I13 — delete project
  // ---------------------------------------------------------------------
  testWidgets('I13 delete project', (tester) async {
    await app.launch(tester);
    final fx = FixtureAudio.generate();
    final src = await app.writeScratch('fx_delete.wav', fx.wavBytes());
    final s = await app.importToEditor(tester, src);
    final id = s.project.id;
    await app.backToHome(tester);
    await pumpUntilFound(tester, find.text('fx_delete'));
    expect(await app.projectDirs(), [id]);
    await tester.longPress(find.text('fx_delete'));
    await pumpUntilFound(tester, find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await pumpUntilFound(tester, find.text('Delete "fx_delete"?'));
    await tester.tap(find.text('Delete'));
    await pumpUntilFound(tester, find.text('No beat packs yet'));
    await pumpUntil(
      tester,
      () async => !await Directory(app.paths.projectDir(id)).exists(),
      reason: 'project folder deleted',
    );
    report('I13', 'folder gone, empty state shown');
  });
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Every click starts exactly on a beat in [beats] (frame before is silent,
/// the beat frame is not) and the track is silent outside the clicks.
void _expectClicksExactlyAt(PcmFile w, List<int> beats, int clickLen) {
  final ch = w.channels;
  bool silent(int f) {
    for (var c = 0; c < ch; c++) {
      if (w.pcm[f * ch + c] != 0) return false;
    }
    return true;
  }

  final sorted = [...beats]..sort();
  for (final b in sorted) {
    expect(silent(b), isFalse, reason: 'no click at beat $b');
    if (b > 0) expect(silent(b - 1), isTrue, reason: 'sound before beat $b');
  }
  // Outside [b, b + clickLen) everything must be zero.
  var next = 0;
  var loud = 0;
  for (var f = 0; f < w.frames; f++) {
    while (next < sorted.length && sorted[next] + clickLen <= f) {
      next++;
    }
    final inClick = next < sorted.length && f >= sorted[next];
    if (!inClick && !silent(f)) loud++;
  }
  expect(loud, 0, reason: '$loud non-zero frames outside clicks');
}
