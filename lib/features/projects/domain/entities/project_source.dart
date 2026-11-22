import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../import/domain/entities/picked_source.dart';

part 'project_source.freezed.dart';

@freezed
abstract class ProjectSource with _$ProjectSource {
  const factory ProjectSource({
    required ImportSourceKind kind,
    required String originalName,

    /// Relative file name inside the project folder (e.g. `source.m4a`), or
    /// null for iOS music library items.
    String? copiedFileName,
  }) = _ProjectSource;
}
