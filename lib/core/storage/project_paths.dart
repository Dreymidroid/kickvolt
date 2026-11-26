import 'dart:io';

import 'package:path/path.dart' as p;

/// Where a project's files live:
/// `<documents>/projects/<id>/{source.<ext>, song.wav, ...}`.
class ProjectPaths {
  const ProjectPaths(this.documentsDir);

  final String documentsDir;

  String get projectsDir => p.join(documentsDir, 'projects');

  /// Summary index for the Projects home screen.
  String get indexJson => p.join(projectsDir, 'index.json');

  String projectDir(String id) => p.join(projectsDir, id);

  /// Copy of the imported file. [extension] has no leading dot.
  String sourceFile(String id, String extension) => p.join(
    projectDir(id),
    extension.isEmpty ? 'source' : 'source.$extension',
  );

  /// Decoded 16-bit PCM WAV: the master timebase.
  String songWav(String id) => p.join(projectDir(id), 'song.wav');

  /// Coarsest waveform overview (~10 ms bins, 1 byte per bin).
  String overviewBin(String id) => p.join(projectDir(id), 'overview.bin');

  /// Persisted project document.
  /// Multi-level min/max waveform peaks for the editor.
  String peaksBin(String id) => p.join(projectDir(id), 'peaks.bin');

  /// Cached beat-detection analysis (`analysis.bin`).
  String analysisFile(String id) => p.join(projectDir(id), 'analysis.bin');

  /// Pre-rendered click-preview mix (`preview-<n>.wav`).
  String previewWav(String id, int sequence) =>
      p.join(projectDir(id), 'preview-$sequence.wav');

  String projectJson(String id) => p.join(projectDir(id), 'project.json');

  /// Directory containing exported beat packs (`projects/<id>/exports/`).
  String exportsDir(String id) => p.join(projectDir(id), 'exports');

  /// Directory for a single beat pack (`projects/<id>/exports/<stamp>/`).
  String exportPackDir(String id, String stamp) =>
      p.join(exportsDir(id), stamp);

  Future<Directory> createProjectDir(String id) =>
      Directory(projectDir(id)).create(recursive: true);

  /// Deletes all `preview-*` files (including `.part` leftovers) in the project
  /// directory, ignoring individual delete errors if a file is still open.
  Future<void> deletePreviewFiles(String id) async {
    final dir = Directory(projectDir(id));
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path).startsWith('preview-')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> deleteProject(String id) async {
    final dir = Directory(projectDir(id));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
