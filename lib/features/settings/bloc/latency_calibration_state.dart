part of 'latency_calibration_cubit.dart';

@freezed
sealed class LatencyCalibrationState with _$LatencyCalibrationState {
  const LatencyCalibrationState._();

  const factory LatencyCalibrationState.loading() = LatencyCalibrationLoading;

  const factory LatencyCalibrationState.ready({
    @Default(false) bool playing,
    @Default(false) bool playbackUnavailable,
    @Default(0) int validTapCount,
    @Default(kCalibrationMinTaps) int requiredTaps,
    @Default(CalibrationStatus.needMoreTaps) CalibrationStatus status,
    int? measuredOffsetMs,
    @Default(OutputKind.unknown) OutputKind outputKind,
    @Default(OutputKind.unknown) OutputKind calibratedOn,
    int? reportedOutputLatencyMs,
    @Default(false) bool saved,
  }) = LatencyCalibrationReady;

  const factory LatencyCalibrationState.error({required String error}) =
      LatencyCalibrationError;
}
