import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/entitlements/entitlement_service.dart';
import '../../projects/domain/entities/project.dart';
import '../domain/entities/beat_pack.dart';
import '../domain/entities/export_failure.dart';
import '../domain/entities/export_options.dart';

part 'export_state.freezed.dart';

@freezed
sealed class ExportState with _$ExportState {
  const factory ExportState.loading() = ExportLoading;

  const factory ExportState.error(String message) = ExportError;

  /// The options screen. [plan] is derived from [project] + [options].
  const factory ExportState.editing({
    required Project project,
    required ExportOptions options,
    required BeatPackPlan plan,
    required ExportQuota quota,
  }) = ExportEditing;

  const factory ExportState.exporting({
    required ExportOptions options,
    required BeatPackPlan plan,
    required ExportProgress progress,
  }) = ExportExporting;

  /// Options screen with the error card on top.
  const factory ExportState.failed({
    required ExportFailure failure,
    required Project project,
    required ExportOptions options,
    required BeatPackPlan plan,
    required ExportQuota quota,
  }) = ExportFailed;

  const factory ExportState.done({
    required BeatPack pack,

    /// True after the user saved the pack to a folder they picked.
    @Default(false) bool saved,
  }) = ExportDone;
}
