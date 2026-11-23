import 'package:freezed_annotation/freezed_annotation.dart';

part 'detection_settings.freezed.dart';

enum BeatFilter { every, strong, drops, every2nd, every4th }

enum DetectionStatus { notRun, succeeded, failed }

@freezed
abstract class DetectionSettings with _$DetectionSettings {
  const factory DetectionSettings({
    @Default(0.5) double sensitivity,
    @Default(BeatFilter.every) BeatFilter filter,
    @Default(DetectionStatus.notRun) DetectionStatus status,
  }) = _DetectionSettings;
}
