import 'package:freezed_annotation/freezed_annotation.dart';

import 'beat.dart';
import 'song_section.dart';

part 'beat_project.freezed.dart';

@freezed
abstract class BeatProject with _$BeatProject {
  const BeatProject._();

  const factory BeatProject({
    required String id,
    required String name,
    required int durationMs,
    required int bpm,
    required List<Beat> beats,
    required List<SongSection> sections,

    /// Peak amplitude (0–1) per [peakBinMs] slice of the song.
    required List<double> peaks,
    @Default(10) int peakBinMs,
  }) = _BeatProject;

  int get beatCount => beats.length;

  /// Whether [ms] sits on the BPM grid (within a millisecond).
  bool isOnGrid(int ms) {
    final grid = 60000 / bpm;
    return (ms - (ms / grid).round() * grid).abs() <= 1;
  }

  /// Drops are strong beats too, so they count towards "strong".
  int get strongCount => beats.where((b) => b.type != BeatType.beat).length;

  int get dropCount => beats.where((b) => b.type == BeatType.drop).length;

  /// Max peak between [fromMs] and [toMs].
  double peakBetween(double fromMs, double toMs) {
    if (peaks.isEmpty) return 0;
    final a = (fromMs / peakBinMs).floor().clamp(0, peaks.length - 1);
    final b = (toMs / peakBinMs).ceil().clamp(a + 1, peaks.length);
    var m = 0.0;
    for (var i = a; i < b; i++) {
      if (peaks[i] > m) m = peaks[i];
    }
    return m;
  }

  /// Mean peak between [fromMs] and [toMs] (used for the overview strip).
  double meanBetween(double fromMs, double toMs) {
    if (peaks.isEmpty) return 0;
    final a = (fromMs / peakBinMs).floor().clamp(0, peaks.length - 1);
    final b = (toMs / peakBinMs).ceil().clamp(a + 1, peaks.length);
    var sum = 0.0;
    for (var i = a; i < b; i++) {
      sum += peaks[i];
    }
    return sum / (b - a);
  }

  SongSection? sectionAt(int ms) {
    for (final s in sections) {
      if (ms >= s.startMs && ms < s.endMs) return s;
    }
    return null;
  }
}
