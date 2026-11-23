import '../../projects/domain/entities/project.dart';
import 'edit_command.dart';

/// Outcome of executing, undoing, or redoing a command on [CommandStack].
class CommandResult {
  const CommandResult({required this.project, required this.selectedIndex});

  final Project project;
  final int? selectedIndex;
}

/// Pure-Dart undo/redo command stack with time-window coalescing.
///
/// Never reads wall-clock time internally — callers pass `at` so coalescing is
/// completely deterministic in unit tests.
class CommandStack {
  CommandStack({
    this.maxEntries = 100,
    this.coalesceWindow = const Duration(seconds: 1),
  });

  final int maxEntries;
  final Duration coalesceWindow;

  final List<EditCommand> _undo = [];
  final List<EditCommand> _redo = [];
  DateTime? _lastAt;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoLength => _undo.length;
  int get redoLength => _redo.length;

  /// Applies [command] to [project], records it (coalescing with the top
  /// entry if within [coalesceWindow] and mergeable), and clears redo.
  CommandResult execute(
    Project project,
    EditCommand command, {
    required DateTime at,
  }) {
    final next = command.apply(project);
    final selected = command.selectAfterApply(next);

    var merged = false;
    if (_undo.isNotEmpty &&
        _lastAt != null &&
        at.difference(_lastAt!) < coalesceWindow) {
      final combined = _undo.last.mergeWith(command);
      if (combined != null) {
        _undo[_undo.length - 1] = combined;
        merged = true;
      }
    }

    if (!merged) {
      _undo.add(command);
      if (_undo.length > maxEntries) {
        _undo.removeAt(0);
      }
    }

    _redo.clear();
    _lastAt = at;
    return CommandResult(project: next, selectedIndex: selected);
  }

  /// Undoes the most recent command, or returns null if nothing to undo.
  CommandResult? undo(Project project) {
    if (_undo.isEmpty) return null;
    final cmd = _undo.removeLast();
    _redo.add(cmd);
    _lastAt = null;
    final reverted = cmd.revert(project);
    return CommandResult(
      project: reverted,
      selectedIndex: cmd.selectAfterRevert(reverted),
    );
  }

  /// Redoes the most recently undone command, or returns null if nothing to redo.
  CommandResult? redo(Project project) {
    if (_redo.isEmpty) return null;
    final cmd = _redo.removeLast();
    _undo.add(cmd);
    _lastAt = null;
    final applied = cmd.apply(project);
    return CommandResult(
      project: applied,
      selectedIndex: cmd.selectAfterApply(applied),
    );
  }

  void clear() {
    _undo.clear();
    _redo.clear();
    _lastAt = null;
  }
}
