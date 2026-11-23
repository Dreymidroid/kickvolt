import 'dart:math' as math;

import '../../projects/domain/entities/beat.dart';
import '../../projects/domain/entities/detection_settings.dart';
import '../../projects/domain/entities/project.dart';
import '../../projects/domain/entities/section.dart';

/// Precedence when two beats merge onto the same sample index:
/// drop > downbeat > strong > beat.
int beatTypePrecedence(BeatType type) => switch (type) {
  BeatType.drop => 3,
  BeatType.downbeat => 2,
  BeatType.strong => 1,
  BeatType.beat => 0,
};

/// Sorts [beats] by sample, clamps to `[0, sampleCount - 1]`, and resolves
/// duplicate sample indices by keeping the higher-precedence [BeatType].
List<Beat> normalizeBeats(Iterable<Beat> beats, int sampleCount) {
  final lastFrame = math.max(0, sampleCount - 1);
  final bySample = <int, Beat>{};
  for (final b in beats) {
    final s = b.sample.clamp(0, lastFrame);
    final existing = bySample[s];
    if (existing == null ||
        beatTypePrecedence(b.type) > beatTypePrecedence(existing.type)) {
      bySample[s] = b.copyWith(sample: s);
    }
  }
  final out = bySample.values.toList()
    ..sort((a, b) => a.sample.compareTo(b.sample));
  return out;
}

/// Snaps [sample] to the nearest grid line defined by [bpm] and
/// [beatPhaseSample], clamped to `[0, sampleCount - 1]`.
int snapSampleToGrid({
  required int sample,
  required int sampleRate,
  required int sampleCount,
  required double bpm,
  int? beatPhaseSample,
}) {
  final lastFrame = math.max(0, sampleCount - 1);
  if (bpm <= 0 || sampleRate <= 0) return sample.clamp(0, lastFrame);
  final phase = beatPhaseSample ?? 0;
  final grid = sampleRate * 60.0 / bpm;
  final snapped = (phase + ((sample - phase) / grid).round() * grid).round();
  return snapped.clamp(0, lastFrame);
}

/// A reversible edit to a [Project]'s editable state (`beats`, `sections`,
/// `bpm`, `beatPhaseSample`, `detection`).
abstract class EditCommand {
  const EditCommand();

  Project apply(Project p);
  Project revert(Project p);

  /// Marker index to select after [apply], or null.
  int? selectAfterApply(Project result) => null;

  /// Marker index to select after [revert], or null.
  int? selectAfterRevert(Project result) => null;

  /// Merge [next] into this command (for nudge coalescing); null if it can't.
  EditCommand? mergeWith(EditCommand next) => null;
}

/// Inserts one or more beats (add at playhead, long-press, or a tap run).
/// Undo removes only the beats that were actually inserted.
class AddBeats extends EditCommand {
  AddBeats(List<Beat> beats, {this.selectSample})
    : _requested = List<Beat>.unmodifiable(beats);

  final List<Beat> _requested;
  final int? selectSample;
  List<Beat>? _inserted;

  @override
  Project apply(Project p) {
    final lastFrame = math.max(0, p.sampleCount - 1);
    final existingSamples = {for (final b in p.beats) b.sample};
    final addedBySample = <int, Beat>{};
    for (final b in _requested) {
      final s = b.sample.clamp(0, lastFrame);
      if (existingSamples.contains(s)) continue;
      final prev = addedBySample[s];
      if (prev == null ||
          beatTypePrecedence(b.type) > beatTypePrecedence(prev.type)) {
        addedBySample[s] = b.copyWith(sample: s);
      }
    }
    _inserted ??= addedBySample.values.toList()
      ..sort((a, b) => a.sample.compareTo(b.sample));
    if (_inserted!.isEmpty) return p;
    final next = [...p.beats, ..._inserted!]
      ..sort((a, b) => a.sample.compareTo(b.sample));
    return p.copyWith(beats: next);
  }

  @override
  Project revert(Project p) {
    final inserted = _inserted;
    if (inserted == null || inserted.isEmpty) return p;
    final removeSamples = {for (final b in inserted) b.sample};
    final next = p.beats
        .where((b) => !removeSamples.contains(b.sample))
        .toList();
    return p.copyWith(beats: next);
  }

  @override
  int? selectAfterApply(Project result) {
    final s = selectSample;
    if (s == null) return null;
    final idx = result.beats.indexWhere((b) => b.sample == s);
    return idx >= 0 ? idx : null;
  }
}

/// Removes one beat at [index]. Undo restores it with its exact type and index.
class DeleteBeat extends EditCommand {
  const DeleteBeat({required this.index, required this.beat});

  final int index;
  final Beat beat;

  @override
  Project apply(Project p) {
    if (index < 0 || index >= p.beats.length) return p;
    final next = [...p.beats]..removeAt(index);
    return p.copyWith(beats: next);
  }

  @override
  Project revert(Project p) {
    final next = [...p.beats];
    final insertAt = index.clamp(0, next.length);
    next.insert(insertAt, beat);
    next.sort((a, b) => a.sample.compareTo(b.sample));
    return p.copyWith(beats: next);
  }

  @override
  int? selectAfterRevert(Project result) {
    final idx = result.beats.indexWhere((b) => b.sample == beat.sample);
    return idx >= 0 ? idx : null;
  }
}

/// Nudges a single beat at [index] from [fromSample] to [toSample].
/// Consecutive nudges of the same beat within the coalesce window merge.
class MoveBeat extends EditCommand {
  const MoveBeat({
    required this.index,
    required this.fromSample,
    required this.toSample,
  });

  final int index;
  final int fromSample;
  final int toSample;

  @override
  Project apply(Project p) {
    if (index < 0 || index >= p.beats.length) return p;
    final lastFrame = math.max(0, p.sampleCount - 1);
    final target = toSample.clamp(0, lastFrame);
    final next = [...p.beats]
      ..[index] = p.beats[index].copyWith(sample: target);
    return p.copyWith(beats: next);
  }

  @override
  Project revert(Project p) {
    if (index < 0 || index >= p.beats.length) return p;
    final next = [...p.beats]
      ..[index] = p.beats[index].copyWith(sample: fromSample);
    return p.copyWith(beats: next);
  }

  @override
  int? selectAfterApply(Project result) =>
      index >= 0 && index < result.beats.length ? index : null;

  @override
  int? selectAfterRevert(Project result) =>
      index >= 0 && index < result.beats.length ? index : null;

  @override
  EditCommand? mergeWith(EditCommand next) {
    if (next is MoveBeat &&
        next.index == index &&
        next.fromSample == toSample) {
      return MoveBeat(
        index: index,
        fromSample: fromSample,
        toSample: next.toSample,
      );
    }
    return null;
  }
}

/// Changes a single beat's [BeatType].
class SetBeatType extends EditCommand {
  const SetBeatType({
    required this.index,
    required this.oldType,
    required this.newType,
  });

  final int index;
  final BeatType oldType;
  final BeatType newType;

  @override
  Project apply(Project p) {
    if (index < 0 || index >= p.beats.length) return p;
    final next = [...p.beats]..[index] = p.beats[index].copyWith(type: newType);
    return p.copyWith(beats: next);
  }

  @override
  Project revert(Project p) {
    if (index < 0 || index >= p.beats.length) return p;
    final next = [...p.beats]..[index] = p.beats[index].copyWith(type: oldType);
    return p.copyWith(beats: next);
  }

  @override
  int? selectAfterApply(Project result) =>
      index >= 0 && index < result.beats.length ? index : null;

  @override
  int? selectAfterRevert(Project result) =>
      index >= 0 && index < result.beats.length ? index : null;
}

/// Shifts every beat and `beatPhaseSample` by [deltaSamples], clamping delta
/// so no beat leaves `[0, sampleCount - 1]`.
class ShiftAll extends EditCommand {
  ShiftAll({required this.deltaSamples});

  final int deltaSamples;
  List<Beat>? _previousBeats;
  int? _previousPhase;
  bool _captured = false;

  @override
  Project apply(Project p) {
    if (!_captured) {
      _previousBeats = p.beats;
      _previousPhase = p.beatPhaseSample;
      _captured = true;
    }
    final lastFrame = math.max(0, p.sampleCount - 1);
    final int effectiveDelta;
    if (p.beats.isEmpty) {
      effectiveDelta = deltaSamples;
    } else {
      final minSample = p.beats.first.sample;
      final maxSample = p.beats.last.sample;
      effectiveDelta = deltaSamples.clamp(-minSample, lastFrame - maxSample);
    }

    final nextBeats = [
      for (final b in p.beats) b.copyWith(sample: b.sample + effectiveDelta),
    ];
    final nextPhase = p.beatPhaseSample == null
        ? null
        : (p.beatPhaseSample! + effectiveDelta).clamp(0, lastFrame);

    return p.copyWith(beats: nextBeats, beatPhaseSample: nextPhase);
  }

  @override
  Project revert(Project p) {
    if (!_captured) return p;
    return p.copyWith(beats: _previousBeats!, beatPhaseSample: _previousPhase);
  }
}

/// Removes every beat (including hidden ones) in `[startSample, endSample]`.
class ClearRange extends EditCommand {
  ClearRange({required this.startSample, required this.endSample});

  final int startSample;
  final int endSample;
  List<Beat>? _removed;

  @override
  Project apply(Project p) {
    final lo = math.min(startSample, endSample);
    final hi = math.max(startSample, endSample);
    final removed = <Beat>[];
    final kept = <Beat>[];
    for (final b in p.beats) {
      if (b.sample >= lo && b.sample <= hi) {
        removed.add(b);
      } else {
        kept.add(b);
      }
    }
    _removed ??= removed;
    return p.copyWith(beats: kept);
  }

  @override
  Project revert(Project p) {
    final removed = _removed;
    if (removed == null || removed.isEmpty) return p;
    final restored = [...p.beats, ...removed]
      ..sort((a, b) => a.sample.compareTo(b.sample));
    return p.copyWith(beats: restored);
  }
}

/// Snaps every beat in `[startSample, endSample]` to the nearest grid line
/// (`bpm` + `beatPhaseSample`). Collisions keep the higher-precedence type
/// (drop > downbeat > strong > beat).
class SnapRange extends EditCommand {
  SnapRange({required this.startSample, required this.endSample});

  final int startSample;
  final int endSample;
  List<Beat>? _previousBeats;

  @override
  Project apply(Project p) {
    _previousBeats ??= p.beats;
    final bpm = p.bpm;
    if (bpm == null || bpm <= 0) return p;
    final lo = math.min(startSample, endSample);
    final hi = math.max(startSample, endSample);

    final mapped = <Beat>[];
    for (final b in p.beats) {
      if (b.sample >= lo && b.sample <= hi) {
        final snapped = snapSampleToGrid(
          sample: b.sample,
          sampleRate: p.sampleRate,
          sampleCount: p.sampleCount,
          bpm: bpm,
          beatPhaseSample: p.beatPhaseSample,
        );
        mapped.add(b.copyWith(sample: snapped));
      } else {
        mapped.add(b);
      }
    }
    return p.copyWith(beats: normalizeBeats(mapped, p.sampleCount));
  }

  @override
  Project revert(Project p) {
    final prev = _previousBeats;
    if (prev == null) return p;
    return p.copyWith(beats: prev);
  }
}

/// Replaces the section list.
class SetSections extends EditCommand {
  const SetSections({required this.oldSections, required this.newSections});

  final List<Section> oldSections;
  final List<Section> newSections;

  @override
  Project apply(Project p) => p.copyWith(sections: newSections);

  @override
  Project revert(Project p) => p.copyWith(sections: oldSections);
}

/// Replaces all five editable fields at once (auto-detect commit and
/// "Mark drops only").
class ReplaceAll extends EditCommand {
  const ReplaceAll({
    required this.oldBeats,
    required this.newBeats,
    required this.oldSections,
    required this.newSections,
    required this.oldBpm,
    required this.newBpm,
    required this.oldBeatPhaseSample,
    required this.newBeatPhaseSample,
    required this.oldDetection,
    required this.newDetection,
  });

  final List<Beat> oldBeats;
  final List<Beat> newBeats;
  final List<Section> oldSections;
  final List<Section> newSections;
  final double? oldBpm;
  final double? newBpm;
  final int? oldBeatPhaseSample;
  final int? newBeatPhaseSample;
  final DetectionSettings oldDetection;
  final DetectionSettings newDetection;

  @override
  Project apply(Project p) => p.copyWith(
    beats: normalizeBeats(newBeats, p.sampleCount),
    sections: newSections,
    bpm: newBpm,
    beatPhaseSample: newBeatPhaseSample,
    detection: newDetection,
  );

  @override
  Project revert(Project p) => p.copyWith(
    beats: oldBeats,
    sections: oldSections,
    bpm: oldBpm,
    beatPhaseSample: oldBeatPhaseSample,
    detection: oldDetection,
  );
}
