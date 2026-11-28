import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/audio_math/click_synth.dart';
import '../../../core/audio_native/audio_native_client.dart';
import '../../../core/di/locator.dart';
import '../../../core/entitlements/entitlement_service.dart';
import '../../../core/haptics/haptics.dart';
import '../../projects/data/repositories/project_repository.dart';
import '../../projects/domain/entities/project.dart';
import '../../settings/data/repositories/settings_repository.dart';
import '../data/export_isolate_runner.dart';
import '../data/repositories/export_repository.dart';
import '../data/share_service.dart';
import '../domain/beat_pack_plan.dart';
import '../domain/entities/beat_pack.dart';
import '../domain/entities/export_failure.dart';
import '../domain/entities/export_options.dart';
import 'export_state.dart';

export 'export_state.dart';

class ExportCubit extends Cubit<ExportState> {
  ExportCubit({
    ExportRepository? repository,
    ProjectRepository? projectRepository,
    SettingsRepository? settingsRepository,
    EntitlementService? entitlements,
    Haptics? haptics,
    ShareService? shareService,
    AudioNative? audio,
  }) : _repository = repository ?? locator<ExportRepository>(),
       _projects = projectRepository ?? locator<ProjectRepository>(),
       _settings = settingsRepository ?? locator<SettingsRepository>(),
       _entitlements = entitlements ?? locator<EntitlementService>(),
       _haptics = haptics ?? locator<Haptics>(),
       _share = shareService ?? locator<ShareService>(),
       _audio = audio ?? locator<AudioNative>(),
       super(const ExportState.loading());

  final ExportRepository _repository;
  final ProjectRepository _projects;
  final SettingsRepository _settings;
  final EntitlementService _entitlements;
  final Haptics _haptics;
  final ShareService _share;
  final AudioNative _audio;

  Project? _project;
  ExportOptions _options = const ExportOptions();
  ExportQuota _quota = const ExportQuota.unlimited();
  bool _videoAllowed = true;
  ExportCancelToken? _token;
  bool _starting = false;

  Future<void> load(String projectId) async {
    emit(const ExportState.loading());
    try {
      final project = await _projects.getProject(projectId);
      final settings = await _settings.load();
      final quota = await _entitlements.exportQuota();
      final entitlements = await _entitlements.current();
      if (isClosed) return;
      _project = project;
      _quota = quota;
      _videoAllowed = entitlements.hasGuideVideo;
      _options = ExportOptions(
        clickStyle: settings.defaultClickStyle,
        format: settings.defaultAudioFormat,
        includePreview: settings.includePreviewByDefault,
        includeVideo: _videoAllowed && settings.includeVideoByDefault,
        monoGuide: settings.monoGuideTrack,
      );
      _emitEditing();
    } catch (e) {
      if (!isClosed) emit(ExportState.error(e.toString()));
    }
  }

  void _emitEditing() {
    final project = _project;
    if (project == null || isClosed) return;
    emit(
      ExportState.editing(
        project: project,
        options: _options,
        plan: planBeatPack(project, _options),
        quota: _quota,
        videoAllowed: _videoAllowed,
      ),
    );
  }

  void _update(ExportOptions options) {
    if (state is! ExportEditing) return;
    _options = options;
    _emitEditing();
  }

  void setClickStyle(ClickStyle style) =>
      _update(_options.copyWith(clickStyle: style));

  void setFormat(AudioFormat format) =>
      _update(_options.copyWith(format: format));

  void setIncludePreview(bool value) =>
      _update(_options.copyWith(includePreview: value));

  /// Guide video toggle; ignored unless `hasGuideVideo` (M7 §6).
  void setIncludeVideo(bool value) {
    if (!_videoAllowed) return;
    _update(_options.copyWith(includeVideo: value));
  }

  /// The locked Guide video row was tapped. Does nothing until payments
  /// exist (no paywall, M7 §6); the one place a future paywall plugs in.
  void onVideoLocked() {}

  /// Starts exporting with the current options. Never starts when the
  /// entitlement service refuses, or when there are no visible beats.
  Future<void> startExport() async {
    final project = _project;
    if (_starting ||
        project == null ||
        (state is! ExportEditing && state is! ExportFailed)) {
      return;
    }
    final plan = planBeatPack(project, _options);
    if (plan.clickCount == 0) return;
    _starting = true;
    final bool allowed;
    try {
      allowed = await _entitlements.canExport();
    } finally {
      _starting = false;
    }
    if (!allowed || isClosed) return;

    final options = _options;
    final token = ExportCancelToken();
    _token = token;
    emit(
      ExportState.exporting(
        options: options,
        plan: plan,
        progress: ExportProgress(
          overallFraction: 0,
          stepText: 'Getting ready…',
          files: [
            for (final f in plan.files)
              ExportFileProgress(
                kind: f.kind,
                fileName: f.fileName,
                fraction: 0,
                completed: false,
              ),
          ],
        ),
      ),
    );

    try {
      final pack = await _repository.export(
        project,
        options,
        cancel: token,
        onProgress: (p) {
          if (!isClosed && !token.isCancelled && state is ExportExporting) {
            emit(
              ExportState.exporting(options: options, plan: plan, progress: p),
            );
          }
        },
      );
      if (isClosed || token.isCancelled) return;
      await _entitlements.recordExport();
      if (isClosed || token.isCancelled) return;
      emit(ExportState.done(pack: pack));
      unawaited(_haptics.successNotification());
    } on ExportCancelledException {
      // cancel() already returned to the options screen.
    } on ExportFailureException catch (e) {
      _fail(token, e.failure);
    } catch (e) {
      _fail(
        token,
        ExportFailure(kind: ExportFailureKind.other, detail: e.toString()),
      );
    } finally {
      if (identical(_token, token)) _token = null;
    }
  }

  void _fail(ExportCancelToken token, ExportFailure failure) {
    final project = _project;
    if (isClosed || token.isCancelled || project == null) return;
    emit(
      ExportState.failed(
        failure: failure,
        project: project,
        options: _options,
        plan: planBeatPack(project, _options),
        quota: _quota,
        videoAllowed: _videoAllowed,
      ),
    );
  }

  /// Cancels a running export, deletes the pack folder and returns to the
  /// options screen.
  Future<void> cancel() async {
    if (state is! ExportExporting) return;
    final token = _token;
    // Leave the exporting state first so late progress/failures are ignored.
    _emitEditing();
    await token?.cancel();
  }

  Future<void> retry() => startExport();

  /// "Switch to M4A/WAV and retry".
  Future<void> switchFormatAndRetry() {
    _options = _options.copyWith(
      format: _options.format == AudioFormat.wav
          ? AudioFormat.m4a
          : AudioFormat.wav,
    );
    return startExport();
  }

  /// "Export without video" after the guide video failed (M7 §6).
  Future<void> retryWithoutVideo() {
    _options = _options.copyWith(includeVideo: false);
    return startExport();
  }

  /// Dismisses the error card.
  void dismissFailure() {
    if (state is ExportFailed) _emitEditing();
  }

  Future<void> share({Rect? sharePositionOrigin}) async {
    final s = state;
    if (s is! ExportDone) return;
    await _share.shareFiles(
      s.pack.filePaths,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Returns how many files were saved (0 when cancelled or on failure).
  Future<int> saveToFiles() async {
    final s = state;
    if (s is! ExportDone) return 0;
    try {
      final saved = await _audio.saveToFiles(s.pack.filePaths);
      if (saved > 0 && !isClosed && state is ExportDone) {
        emit(ExportState.done(pack: s.pack, saved: true));
      }
      return saved;
    } catch (e) {
      debugPrint('Save to Files failed: $e');
      return 0;
    }
  }

  @override
  Future<void> close() async {
    await _token?.cancel();
    return super.close();
  }
}
