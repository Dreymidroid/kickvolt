import 'dart:math' as math;
import 'dart:typed_data';

import 'package:kickvolt/core/audio_math/overview.dart';
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
  Future<void> saveProject(Project project) async {
    if (saveError != null) throw saveError!;
    _projects[project.id] = project;
    savedProjects.add(project);
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
