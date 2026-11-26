import 'export_options.dart';

/// One planned file in a [BeatPackPlan].
class PlannedExportFile {
  const PlannedExportFile({
    required this.kind,
    required this.fileName,
    required this.channels,
    required this.frameCount,
    required this.estimatedWavBytes,
    this.clickCount,
  });

  final ExportFileKind kind;
  final String fileName;
  final int channels;
  final int frameCount;
  final int estimatedWavBytes;
  final int? clickCount;
}

/// Pure plan deciding file names, visible beat samples, and byte estimates
/// from a project and [ExportOptions] (§4.1, §4.6, §4.7).
class BeatPackPlan {
  const BeatPackPlan({
    required this.projectId,
    required this.sanitizedTitle,
    required this.options,
    required this.sampleRate,
    required this.songChannels,
    required this.frameCount,
    required this.durationMs,
    required this.visibleBeatSamples,
    required this.files,
    required this.estimatedDiskBytes,
  });

  final String projectId;
  final String sanitizedTitle;
  final ExportOptions options;
  final int sampleRate;
  final int songChannels;
  final int frameCount;
  final int durationMs;
  final List<int> visibleBeatSamples;
  final List<PlannedExportFile> files;
  final int estimatedDiskBytes;

  int get clickCount => visibleBeatSamples.length;
  int get fileCount => files.length;
}

/// A finished file inside an exported [BeatPack].
class ExportedFile {
  const ExportedFile({
    required this.path,
    required this.kind,
    required this.displayName,
    required this.frameCount,
    required this.byteSize,
    this.clickCount,
  });

  final String path;
  final ExportFileKind kind;
  final String displayName;
  final int frameCount;
  final int byteSize;
  final int? clickCount;
}

/// Completed beat pack returned by [ExportRepository.export] (§4.1).
class BeatPack {
  const BeatPack({
    required this.projectId,
    required this.packId,
    required this.directoryPath,
    required this.format,
    required this.sampleRate,
    required this.frameCount,
    required this.durationMs,
    required this.clickCount,
    required this.files,
  });

  final String projectId;
  final String packId;
  final String directoryPath;
  final AudioFormat format;
  final int sampleRate;
  final int frameCount;
  final int durationMs;
  final int clickCount;
  final List<ExportedFile> files;

  List<String> get filePaths => [for (final f in files) f.path];
}

/// Per-file progress row reported to the UI during export (§7.2).
class ExportFileProgress {
  const ExportFileProgress({
    required this.kind,
    required this.fileName,
    required this.fraction,
    required this.completed,
  });

  final ExportFileKind kind;
  final String fileName;
  final double fraction;
  final bool completed;
}

/// Live export progress reported to `ExportCubit` (§4.1, §7.2).
class ExportProgress {
  const ExportProgress({
    required this.overallFraction,
    required this.stepText,
    required this.files,
  });

  final double overallFraction;
  final String stepText;
  final List<ExportFileProgress> files;
}
