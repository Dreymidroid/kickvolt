import '../../projects/domain/entities/beat.dart';
import '../../projects/domain/entities/section.dart';

/// Checks whether [sections] obeys the editor's section invariants:
/// empty, OR sorted, non-overlapping, contiguous, covering `[0, sampleCount)`.
bool areSectionsValid(List<Section> sections, int sampleCount) {
  if (sections.isEmpty) return true;
  if (sampleCount <= 0) return false;
  if (sections.first.startSample != 0) return false;
  if (sections.last.endSample != sampleCount) return false;
  for (var i = 0; i < sections.length; i++) {
    final s = sections[i];
    if (s.startSample >= s.endSample) return false;
    if (i > 0 && sections[i - 1].endSample != s.startSample) return false;
  }
  return true;
}

/// Splits the section containing [playheadSample], snapping the new boundary
/// to the nearest beat in [beats] (if any).
///
/// If [sections] is empty, first creates one section covering `[0, sampleCount)`
/// named "Song" and splits it if the boundary falls strictly inside `(0, sampleCount)`.
/// Returns null if a valid split cannot be made (e.g. boundary lands on an
/// existing section edge).
List<Section>? splitSectionAt({
  required List<Section> sections,
  required List<Beat> beats,
  required int playheadSample,
  required int sampleCount,
}) {
  if (sampleCount <= 1) return null;

  var base = sections;
  if (base.isEmpty) {
    base = [
      Section(
        startSample: 0,
        endSample: sampleCount,
        name: 'Song',
        colorArgb: SectionPreset.intro.colorArgb,
      ),
    ];
  }

  var splitAt = playheadSample.clamp(0, sampleCount - 1);
  if (beats.isNotEmpty) {
    splitAt = _nearestBeatSample(beats, splitAt);
  }

  final idx = base.indexWhere(
    (s) => splitAt > s.startSample && splitAt < s.endSample,
  );
  if (idx < 0) {
    // If we started from an empty list and couldn't split (e.g. at sample 0),
    // still return the created "Song" section so the user gets a section.
    return sections.isEmpty ? base : null;
  }

  final target = base[idx];
  final nextPreset = sectionPresets[(idx + 1) % sectionPresets.length];
  final firstHalf = target.copyWith(endSample: splitAt);
  final secondHalf = Section(
    startSample: splitAt,
    endSample: target.endSample,
    name: nextPreset.name,
    colorArgb: nextPreset.colorArgb,
  );

  return [
    ...base.sublist(0, idx),
    firstHalf,
    secondHalf,
    ...base.sublist(idx + 1),
  ];
}

/// Renames section at [index] to [name] (trimmed; ignored if empty).
List<Section>? renameSectionAt(List<Section> sections, int index, String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty || index < 0 || index >= sections.length) return null;
  if (sections[index].name == trimmed) return null;
  return [...sections]..[index] = sections[index].copyWith(name: trimmed);
}

/// Recolours section at [index] to [colorArgb].
List<Section>? recolourSectionAt(
  List<Section> sections,
  int index,
  int colorArgb,
) {
  if (index < 0 || index >= sections.length) return null;
  if (sections[index].colorArgb == colorArgb) return null;
  return [...sections]
    ..[index] = sections[index].copyWith(colorArgb: colorArgb);
}

/// Deletes section at [index], merging its span into the previous section
/// (or into the next section if [index] is 0). Deleting the last remaining
/// section returns an empty list.
List<Section>? deleteSectionAt(List<Section> sections, int index) {
  if (index < 0 || index >= sections.length) return null;
  if (sections.length == 1) return const <Section>[];

  final target = sections[index];
  final next = [...sections]..removeAt(index);
  if (index > 0) {
    next[index - 1] = next[index - 1].copyWith(endSample: target.endSample);
  } else {
    next[0] = next[0].copyWith(startSample: target.startSample);
  }
  return next;
}

int _nearestBeatSample(List<Beat> beats, int sample) {
  var lo = 0;
  var hi = beats.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (beats[mid].sample < sample) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  if (lo == 0) return beats.first.sample;
  if (lo >= beats.length) return beats.last.sample;
  final prev = beats[lo - 1].sample;
  final curr = beats[lo].sample;
  return (sample - prev).abs() <= (curr - sample).abs() ? prev : curr;
}
