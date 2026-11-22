import 'dart:math' as math;

import '../../domain/entities/beat.dart';
import '../../domain/entities/beat_project.dart';
import '../../domain/entities/song_section.dart';

abstract class BeatProjectRepository {
  Future<BeatProject> getProject(String id);
}

/// Serves a generated demo song until import, decoding and beat detection
/// exist. Matches the "Midnight Run" project in the designs: 128 BPM,
/// 358 beats, strong every 4th, three drops.
class DemoBeatProjectRepository implements BeatProjectRepository {
  @override
  Future<BeatProject> getProject(String id) async => _midnightRun(id);

  static BeatProject _midnightRun(String id) {
    const bpm = 128;
    const beatMs = 60000 / bpm; // 468.75
    const durationMs = 168750;
    const sections = [
      SongSection(startMs: 0, endMs: 7500, kind: SectionKind.intro),
      SongSection(startMs: 7500, endMs: 16875, kind: SectionKind.verse),
      SongSection(startMs: 16875, endMs: 31875, kind: SectionKind.drop),
      SongSection(startMs: 31875, endMs: 67500, kind: SectionKind.verse),
      SongSection(startMs: 67500, endMs: 80625, kind: SectionKind.build),
      SongSection(startMs: 80625, endMs: 104531, kind: SectionKind.drop),
      SongSection(startMs: 104531, endMs: 138750, kind: SectionKind.verse),
      SongSection(startMs: 138750, endMs: 158438, kind: SectionKind.drop),
      SongSection(startMs: 158438, endMs: durationMs, kind: SectionKind.outro),
    ];
    final dropStarts = sections
        .where((s) => s.kind == SectionKind.drop)
        .map((s) => s.startMs)
        .toSet();

    final beats = <Beat>[];
    for (var i = 0; i < 358; i++) {
      final t = (i * beatMs).round();
      final type = dropStarts.contains(t)
          ? BeatType.drop
          : i % 4 == 0
          ? BeatType.strong
          : BeatType.beat;
      beats.add(Beat(timeMs: t, type: type));
    }

    return BeatProject(
      id: id,
      name: 'Midnight Run',
      durationMs: durationMs,
      bpm: bpm,
      beats: beats,
      sections: sections,
      peaks: _peaks(durationMs, beatMs, sections),
    );
  }

  /// Deterministic fake loudness: section level + a decaying hit on every
  /// beat (bigger on bar starts) + noise.
  static List<double> _peaks(
    int durationMs,
    double beatMs,
    List<SongSection> sections,
  ) {
    const bin = 10;
    final rnd = math.Random(7);
    final out = List<double>.filled(durationMs ~/ bin, 0);
    var s = 0;
    var noise = 0.0;
    for (var i = 0; i < out.length; i++) {
      final t = i * bin;
      while (s < sections.length - 1 && t >= sections[s].endMs) {
        s++;
      }
      final level = switch (sections[s].kind) {
        SectionKind.intro || SectionKind.outro => 0.18,
        SectionKind.verse => 0.2,
        SectionKind.build => 0.26,
        SectionKind.drop => 0.36,
      };
      // Noise changes every 60 ms so bars vary instead of all maxing out.
      if (i % 6 == 0) noise = rnd.nextDouble() * 0.36;
      final beatIndex = (t / beatMs).floor();
      final sinceBeat = t - beatIndex * beatMs;
      final hit =
          (beatIndex % 4 == 0 ? 0.62 : 0.32) * math.exp(-sinceBeat / 40);
      out[i] = (level + hit + noise).clamp(0.0, 1.0);
    }
    return out;
  }
}
