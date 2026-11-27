import 'package:freezed_annotation/freezed_annotation.dart';

import 'beat.dart';
import 'detection_settings.dart';
import 'project_source.dart';
import 'section.dart';

part 'project.freezed.dart';

@freezed
abstract class Project with _$Project {
  const Project._();

  const factory Project({
    required String id,
    required String title,
    required ProjectSource source,
    required int sampleRate,
    required int channels,

    /// Sample frames in `song.wav` — the master timebase.
    required int sampleCount,
    @Default(<Beat>[]) List<Beat> beats,
    @Default(<Section>[]) List<Section> sections,
    double? bpm,
    int? beatPhaseSample,
    @Default(DetectionSettings()) DetectionSettings detection,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Project;

  int get durationMs => sampleCount * 1000 ~/ sampleRate;

  int sampleToMs(int sample) => (sample * 1000 / sampleRate).round();

  int msToSamples(int ms) => (ms * sampleRate / 1000).round();

  int get beatCount => beats.length;

  /// Non-`beat` types (`strong`, `drop`, `downbeat`).
  int get strongCount => beats.where((b) => b.type != BeatType.beat).length;

  int get dropCount => beats.where((b) => b.type == BeatType.drop).length;

  /// Derived from `detection.tempoMode` (§5): single source of truth so
  /// `tempoVaries` and `detection.tempoMode` can never drift out of sync.
  bool get tempoVaries => detection.tempoMode == TempoMode.varying;

  /// Whether [sample] sits on the BPM grid (within ~1 ms in frames).
  bool isOnGrid(int sample) {
    if (tempoVaries) return false;
    final currentBpm = bpm;
    if (currentBpm == null || currentBpm <= 0) return false;
    final phase = beatPhaseSample ?? 0;
    final grid = sampleRate * 60 / currentBpm;
    final rel = sample - phase;
    final nearest = (rel / grid).round() * grid;
    final tolerance = (sampleRate / 1000).round().clamp(1, sampleRate);
    return (rel - nearest).abs() <= tolerance;
  }

  Section? sectionAt(int sample) {
    for (final s in sections) {
      if (sample >= s.startSample && sample < s.endSample) return s;
    }
    return null;
  }
}
