/// Typed exceptions thrown by `ProjectRepository` and model parsing.
sealed class ProjectException implements Exception {
  const ProjectException(this.message, {this.projectId});

  final String message;
  final String? projectId;

  @override
  String toString() => message;
}

class ProjectNotFoundException extends ProjectException {
  const ProjectNotFoundException(String projectId)
    : super('Project not found: $projectId', projectId: projectId);
}

class ProjectCorruptException extends ProjectException {
  const ProjectCorruptException(super.message, {super.projectId});
}

class ProjectSchemaVersionException extends ProjectCorruptException {
  const ProjectSchemaVersionException(this.schemaVersion, {super.projectId})
    : super('Unsupported project schemaVersion: $schemaVersion');

  final int? schemaVersion;
}

class InvalidProjectTitleException extends ProjectException {
  const InvalidProjectTitleException() : super('Project title cannot be empty');
}
