import 'package:freezed_annotation/freezed_annotation.dart';

part 'detection_settings.freezed.dart';

enum BeatFilter { every, strong, drops, every2nd, every4th }

enum DetectionStatus { notRun, succeeded, failed }

/// Whether the song's tempo is constant or varies across the song (§4.3, §5).
enum TempoMode { steady, varying }

@freezed
abstract class DetectionSettings with _$DetectionSettings {
  const factory DetectionSettings({
    @Default(0.5) double sensitivity,
    @Default(BeatFilter.every) BeatFilter filter,
    @Default(DetectionStatus.notRun) DetectionStatus status,
    @Default(TempoMode.steady) TempoMode tempoMode,
    double? tempoOverrideBpm,
  }) = _DetectionSettings;
}
