import '../../projects/domain/entities/beat.dart';
import '../../projects/domain/entities/detection_settings.dart';
import '../../projects/domain/entities/project.dart';

/// Pure view filter over [beats] according to [filter].
///
/// Returns indices into [beats] (never deletes or mutates stored beats):
/// - [BeatFilter.every]: all indices `0..beats.length - 1`
/// - [BeatFilter.strong]: indices where `type != BeatType.beat`
/// - [BeatFilter.drops]: indices where `type == BeatType.drop`
/// - [BeatFilter.every2nd]: every 2nd beat counting from the first downbeat
///   (index parity relative to it; if no downbeat, from beat 0)
/// - [BeatFilter.every4th]: every 4th beat counting the same way (bar starts)
List<int> visibleBeatIndicesForList(List<Beat> beats, BeatFilter filter) {
  if (beats.isEmpty) return const <int>[];
  switch (filter) {
    case BeatFilter.every:
      return List<int>.generate(beats.length, (i) => i);
    case BeatFilter.strong:
      return <int>[
        for (var i = 0; i < beats.length; i++)
          if (beats[i].type != BeatType.beat) i,
      ];
    case BeatFilter.drops:
      return <int>[
        for (var i = 0; i < beats.length; i++)
          if (beats[i].type == BeatType.drop) i,
      ];
    case BeatFilter.every2nd:
      final anchor = _firstDownbeatIndex(beats);
      return <int>[
        for (var i = 0; i < beats.length; i++)
          if ((i - anchor) % 2 == 0) i,
      ];
    case BeatFilter.every4th:
      final anchor = _firstDownbeatIndex(beats);
      return <int>[
        for (var i = 0; i < beats.length; i++)
          if ((i - anchor) % 4 == 0) i,
      ];
  }
}

/// Pure helper returning the visible beat indices into `project.beats`
/// for `project.detection.filter`.
List<int> visibleBeatIndices(Project project) =>
    visibleBeatIndicesForList(project.beats, project.detection.filter);

int _firstDownbeatIndex(List<Beat> beats) {
  for (var i = 0; i < beats.length; i++) {
    if (beats[i].type == BeatType.downbeat) return i;
  }
  return 0;
}
