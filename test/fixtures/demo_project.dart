import 'dart:math' as math;
import 'dart:typed_data';

import 'package:kickvolt/core/audio_math/overview.dart';
import 'package:kickvolt/core/audio_math/pcm_window_loader.dart';
import 'package:kickvolt/core/audio_math/peaks.dart';
import 'package:kickvolt/features/import/import.dart';
import 'package:kickvolt/features/projects/projects.dart';

/// Generates the "Midnight Run" demo song in sample frames (default 44.1 kHz):
/// 128 BPM, 358 beats, strong every 4th, three drops.
Project createDemoProject({
  String id = 'demo',
  int sampleRate = 44100,
  double? bpm = 128.0,
  int? beatPhaseSample,
  bool includeBeats = true,
}) {
  const designBpm = 128.0;
  final beatFrames = sampleRate * 60 / designBpm;
  final sampleCount = (360 * beatFrames).round(); // 168.75 s

  int beatSample(int beatIndex) => (beatIndex * beatFrames).round();

  final sections = <Section>[
    Section(
      startSample: beatSample(0),
      endSample: beatSample(16),
      name: SectionPreset.intro.name,
      colorArgb: SectionPreset.intro.colorArgb,
    ),
    Section(
      startSample: beatSample(16),
      endSample: beatSample(36),
      name: SectionPreset.verse.name,
      colorArgb: SectionPreset.verse.colorArgb,
    ),
    Section(
      startSample: beatSample(36),
      endSample: beatSample(68),
      name: SectionPreset.drop.name,
      colorArgb: SectionPreset.drop.colorArgb,
    ),
    Section(
      startSample: beatSample(68),
      endSample: beatSample(144),
      name: SectionPreset.verse.name,
      colorArgb: SectionPreset.verse.colorArgb,
    ),
    Section(
      startSample: beatSample(144),
      endSample: beatSample(172),
      name: SectionPreset.build.name,
      colorArgb: SectionPreset.build.colorArgb,
    ),
    Section(
      startSample: beatSample(172),
      endSample: beatSample(223),
      name: SectionPreset.drop.name,
      colorArgb: SectionPreset.drop.colorArgb,
    ),
    Section(
      startSample: beatSample(223),
      endSample: beatSample(296),
      name: SectionPreset.verse.name,
      colorArgb: SectionPreset.verse.colorArgb,
    ),
    Section(
      startSample: beatSample(296),
      endSample: beatSample(338),
      name: SectionPreset.drop.name,
      colorArgb: SectionPreset.drop.colorArgb,
    ),
    Section(
      startSample: beatSample(338),
      endSample: sampleCount,
      name: SectionPreset.outro.name,
      colorArgb: SectionPreset.outro.colorArgb,
    ),
  ];

  final dropStarts = sections
      .where((s) => s.name == SectionPreset.drop.name)
      .map((s) => s.startSample)
      .toSet();

  final beats = <Beat>[];
  if (includeBeats) {
    for (var i = 0; i < 358; i++) {
      final s = beatSample(i);
      final type = dropStarts.contains(s)
          ? BeatType.drop
          : i % 4 == 0
          ? BeatType.strong
          : BeatType.beat;
      beats.add(Beat(sample: s, type: type));
    }
  }

  final epoch = DateTime.utc(2026, 11, 22, 12, 0);
  return Project(
    id: id,
    title: 'Midnight Run',
    source: const ProjectSource(
      kind: ImportSourceKind.file,
      originalName: 'Midnight Run.m4a',
      copiedFileName: 'source.m4a',
    ),
    sampleRate: sampleRate,
    channels: 2,
    sampleCount: sampleCount,
    beats: beats,
    sections: sections,
    bpm: bpm,
    beatPhaseSample: beatPhaseSample,
    createdAt: epoch,
    updatedAt: epoch,
  );
}

Overview createDemoOverview({int sampleRate = 44100}) {
  final project = createDemoProject(sampleRate: sampleRate);
  final binFrames = math.max(1, (sampleRate / 100).round());
  final binCount = (project.sampleCount + binFrames - 1) ~/ binFrames;
  final bins = Uint8List(binCount);
  final rnd = math.Random(7);
  final beatFrames = sampleRate * 60 / 128.0;
  var s = 0;
  var noise = 0.0;

  for (var i = 0; i < binCount; i++) {
    final sample = i * binFrames;
    while (s < project.sections.length - 1 &&
        sample >= project.sections[s].endSample) {
      s++;
    }
    final sectionName = project.sections[s].name;
    final level = switch (sectionName) {
      'Intro' || 'Outro' => 0.18,
      'Verse' => 0.20,
      'Build' => 0.26,
      'Drop' => 0.36,
      _ => 0.20,
    };
    if (i % 6 == 0) noise = rnd.nextDouble() * 0.36;
    final beatIndex = (sample / beatFrames).floor();
    final sinceBeatMs = ((sample - beatIndex * beatFrames) * 1000) / sampleRate;
    final hit =
        (beatIndex % 4 == 0 ? 0.62 : 0.32) * math.exp(-sinceBeatMs / 40);
    final amp = (level + hit + noise).clamp(0.0, 1.0);
    bins[i] = (amp * 255).round().clamp(0, 255);
  }
  return Overview(binFrames: binFrames, bins: bins);
}

/// Peaks for the demo song, derived from [createDemoOverview] (symmetric
/// min/max per 64-frame bucket).
PeakPyramid createDemoPeaks({int sampleRate = 44100}) {
  final ov = createDemoOverview(sampleRate: sampleRate);
  final frames = createDemoProject(sampleRate: sampleRate).sampleCount;
  final buckets = (frames + 63) ~/ 64;
  final finest = Int16List(2 * buckets);
  for (var b = 0; b < buckets; b++) {
    final bin = math.min(ov.binCount - 1, b * 64 ~/ ov.binFrames);
    final amp = ov.bins[bin] * 32767 ~/ 255;
    finest[2 * b] = -amp;
    finest[2 * b + 1] = amp;
  }
  return PeakPyramid.fromFinest(frameCount: frames, finest: finest);
}

/// In-memory [ProjectRepository] for beat editor tests.
class FakeDemoProjectRepository implements ProjectRepository {
  FakeDemoProjectRepository([Project? initial]) {
    final p = initial ?? createDemoProject();
    _projects[p.id] = p;
  }

  final Map<String, Project> _projects = {};
  final List<Project> savedProjects = [];
  Object? saveError;

  void put(Project project) => _projects[project.id] = project;

  @override
  Future<Project> getProject(String id) async {
    final p = _projects[id];
    if (p == null) throw ProjectNotFoundException(id);
    return p;
  }

  @override
  Future<Overview> getOverview(String id) async {
    final p = _projects[id];
    return createDemoOverview(sampleRate: p?.sampleRate ?? 44100);
  }

  @override
  Future<PeakPyramid> getPeaks(String id) async =>
      createDemoPeaks(sampleRate: _projects[id]?.sampleRate ?? 44100);

  @override
  Future<String> songPath(String id) async => '/fake/projects/$id/song.wav';

  @override
  Future<void> writeProjectBinaryFile(
    String targetPath,
    List<int> bytes,
  ) async {}

  /// No real file in tests; the editor falls back to the finest level.
  @override
  Future<PcmWindowLoader> openPcmWindow(String id) =>
      throw UnsupportedError('no song.wav in tests');

  /// When set, each save waits on this before completing (to hold a save
  /// "in flight").
  Future<void> Function()? saveGate;

  /// Highest number of saves running at the same time.
  int maxConcurrentSaves = 0;
  int _activeSaves = 0;

  @override
  Future<void> saveProject(Project project) async {
    _activeSaves++;
    if (_activeSaves > maxConcurrentSaves) maxConcurrentSaves = _activeSaves;
    try {
      if (saveGate != null) await saveGate!();
      if (saveError != null) throw saveError!;
      _projects[project.id] = project;
      savedProjects.add(project);
    } finally {
      _activeSaves--;
    }
  }

  @override
  Future<Project> createFromImport(ImportedSong song) =>
      throw UnimplementedError();

  @override
  Future<List<ProjectSummary>> listProjects() async => const [];

  @override
  Future<void> renameProject(String id, String title) async {}

  @override
  Future<void> deleteProject(String id) async => _projects.remove(id);

  @override
  Future<void> cleanUpOrphans() async {}
}
