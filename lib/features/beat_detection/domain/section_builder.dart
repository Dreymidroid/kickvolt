import 'dart:math' as math;
import 'dart:typed_data';

import '../../projects/domain/entities/beat.dart';
import '../../projects/domain/entities/section.dart';

// HEURISTIC: Rough sections so the editor isn't blank (§4.8).
// Splits the song into 4-bar blocks on downbeats, computes mean low-band +
// overall energy per block, labels each block by energy tercile, merges equal
// neighbours, then names runs:
// - A run starting at a drop is Drop
// - 1–2 blocks of rising energy right before a drop are Build
// - The first run is Intro and the last Outro if they're in the lowest tercile
// - Everything else is Verse.
// Invariants: sorted, non-overlapping, contiguous, covering [0, sampleCount),
// boundaries on beat samples (except 0 and sampleCount).
List<Section> buildHeuristicSections({
  required List<Beat> beats,
  required int sampleCount,
  required int hopSize,
  required Float32List frameLowEnergy,
  required Float32List frameOverallEnergy,
}) {
  if (sampleCount <= 0 || beats.isEmpty) return const <Section>[];

  // Collect bar start beats (downbeats and drops, since drops replace downbeats).
  final barBeats = <int>[];
  final dropSamples = <int>{};
  for (var i = 0; i < beats.length; i++) {
    final b = beats[i];
    final s = b.sample;
    if (s <= 0 || s >= sampleCount) continue;
    if (b.type == BeatType.drop) {
      dropSamples.add(s);
      barBeats.add(s);
    } else if (b.type == BeatType.downbeat) {
      barBeats.add(s);
    }
  }

  // If too few downbeats exist, fall back to every 4th beat.
  if (barBeats.length < 4) {
    barBeats.clear();
    for (var i = 0; i < beats.length; i += 4) {
      final s = beats[i].sample;
      if (s > 0 && s < sampleCount) barBeats.add(s);
    }
  }

  // Build 4-bar blocks aligned on downbeats, splitting early when a drop
  // occurs so that drops always start a block boundary.
  final boundaries = <int>[0];
  var barsSinceBoundary = 0;
  for (var i = 0; i < barBeats.length; i++) {
    final s = barBeats[i];
    if (s <= boundaries.last || s >= sampleCount) continue;
    final isDrop = dropSamples.contains(s);
    if (isDrop || barsSinceBoundary >= 4) {
      boundaries.add(s);
      barsSinceBoundary = 1;
    } else {
      barsSinceBoundary++;
    }
  }
  if (boundaries.last < sampleCount) {
    boundaries.add(sampleCount);
  }

  // Merge a tiny trailing block (< 2 bars) into its predecessor unless it
  // starts at a drop.
  if (boundaries.length >= 3) {
    final lastStart = boundaries[boundaries.length - 2];
    final prevStart = boundaries[boundaries.length - 3];
    if (!dropSamples.contains(lastStart) &&
        (sampleCount - lastStart) < (lastStart - prevStart) ~/ 2) {
      boundaries.removeAt(boundaries.length - 2);
    }
  }

  final blockCount = boundaries.length - 1;
  if (blockCount <= 0) return const <Section>[];
  if (blockCount == 1) {
    return <Section>[
      Section(
        startSample: 0,
        endSample: sampleCount,
        name: SectionPreset.verse.name,
        colorArgb: SectionPreset.verse.colorArgb,
      ),
    ];
  }

  // Compute mean (normalised low-band + normalised overall) energy per block
  // by sampling only the block's frame span directly.
  final blockLow = Float64List(blockCount);
  final blockOv = Float64List(blockCount);
  var maxBlockLow = 1e-9;
  var maxBlockOv = 1e-9;
  final nFrames = frameLowEnergy.length;
  final nOvFrames = frameOverallEnergy.length;

  for (var b = 0; b < blockCount; b++) {
    final f0 = (boundaries[b] ~/ hopSize).clamp(0, nFrames);
    final f1 = ((boundaries[b + 1] + hopSize - 1) ~/ hopSize).clamp(
      f0,
      nFrames,
    );
    final count = f1 - f0;
    if (count <= 0) continue;
    // Stride if a block has hundreds of frames so section building is O(blocks)
    // and sub-millisecond even on a 30-minute track.
    final step = count > 64 ? (count >> 5) : 1;
    var sumLow = 0.0;
    var sumOv = 0.0;
    var samples = 0;
    for (var f = f0; f < f1; f += step) {
      sumLow += frameLowEnergy[f];
      if (f < nOvFrames) sumOv += frameOverallEnergy[f];
      samples++;
    }
    final meanLow = sumLow / samples;
    final meanOv = sumOv / samples;
    blockLow[b] = meanLow;
    blockOv[b] = meanOv;
    if (meanLow > maxBlockLow) maxBlockLow = meanLow;
    if (meanOv > maxBlockOv) maxBlockOv = meanOv;
  }

  final blockEnergy = Float64List(blockCount);
  for (var b = 0; b < blockCount; b++) {
    blockEnergy[b] = (blockLow[b] / maxBlockLow) + (blockOv[b] / maxBlockOv);
  }

  // Tercile thresholds over block energies.
  final sortedE = Float64List.fromList(blockEnergy)..sort();
  final t1 = sortedE[sortedE.length ~/ 3];
  final t2 = sortedE[(sortedE.length * 2) ~/ 3];

  final terciles = Int32List(blockCount);
  for (var b = 0; b < blockCount; b++) {
    final e = blockEnergy[b];
    if (t2 > t1) {
      terciles[b] = e <= t1 ? 0 : (e <= t2 ? 1 : 2);
    } else {
      terciles[b] = 1;
    }
  }

  final blockIsDropStart = List<bool>.generate(
    blockCount,
    (b) => dropSamples.contains(boundaries[b]),
  );

  // Mark 1-2 blocks of rising energy right before a drop as Build.
  final blockIsBuild = List<bool>.filled(blockCount, false);
  for (var b = 0; b < blockCount; b++) {
    if (!blockIsDropStart[b]) continue;
    if (b >= 1 && !blockIsDropStart[b - 1]) {
      final prevE = b >= 2 ? blockEnergy[b - 2] : blockEnergy[0];
      if (blockEnergy[b - 1] >= prevE * 0.95 &&
          blockEnergy[b - 1] <= blockEnergy[b]) {
        blockIsBuild[b - 1] = true;
        if (b >= 2 &&
            !blockIsDropStart[b - 2] &&
            b - 2 > 0 &&
            blockEnergy[b - 2] > blockEnergy[b - 3] &&
            blockEnergy[b - 1] >= blockEnergy[b - 2]) {
          blockIsBuild[b - 2] = true;
        }
      }
    }
  }

  final blockLabel = List<String>.filled(blockCount, SectionPreset.verse.name);
  var inDropRun = false;
  var dropTercile = 2;

  for (var b = 0; b < blockCount; b++) {
    if (blockIsDropStart[b]) {
      inDropRun = true;
      dropTercile = terciles[b];
      blockLabel[b] = SectionPreset.drop.name;
    } else if (blockIsBuild[b]) {
      inDropRun = false;
      blockLabel[b] = SectionPreset.build.name;
    } else if (inDropRun && terciles[b] >= math.max(1, dropTercile)) {
      blockLabel[b] = SectionPreset.drop.name;
    } else {
      inDropRun = false;
      blockLabel[b] = 'T${terciles[b]}';
    }
  }

  // Merge adjacent blocks with identical label.
  final runs = <_BlockRun>[];
  for (var b = 0; b < blockCount; b++) {
    final start = boundaries[b];
    final end = boundaries[b + 1];
    final lbl = blockLabel[b];
    final terc = terciles[b];
    if (runs.isNotEmpty && runs.last.rawLabel == lbl) {
      runs.last.endSample = end;
    } else {
      runs.add(
        _BlockRun(
          startSample: start,
          endSample: end,
          rawLabel: lbl,
          tercile: terc,
        ),
      );
    }
  }

  for (var i = 0; i < runs.length; i++) {
    final r = runs[i];
    if (r.rawLabel == SectionPreset.drop.name ||
        r.rawLabel == SectionPreset.build.name) {
      r.finalName = r.rawLabel;
    } else if (i == 0 && r.tercile == 0) {
      r.finalName = SectionPreset.intro.name;
    } else if (i == runs.length - 1 && i > 0 && r.tercile == 0) {
      r.finalName = SectionPreset.outro.name;
    } else {
      r.finalName = SectionPreset.verse.name;
    }
  }

  final merged = <_BlockRun>[];
  for (final r in runs) {
    if (merged.isNotEmpty && merged.last.finalName == r.finalName) {
      merged.last.endSample = r.endSample;
    } else {
      merged.add(r);
    }
  }

  return <Section>[
    for (final r in merged)
      Section(
        startSample: r.startSample,
        endSample: r.endSample,
        name: r.finalName,
        colorArgb: _colorForSectionName(r.finalName),
      ),
  ];
}

int _colorForSectionName(String name) => switch (name) {
  'Intro' => SectionPreset.intro.colorArgb,
  'Verse' => SectionPreset.verse.colorArgb,
  'Build' => SectionPreset.build.colorArgb,
  'Drop' => SectionPreset.drop.colorArgb,
  'Outro' => SectionPreset.outro.colorArgb,
  _ => SectionPreset.verse.colorArgb,
};

class _BlockRun {
  _BlockRun({
    required this.startSample,
    required this.endSample,
    required this.rawLabel,
    required this.tercile,
  });

  final int startSample;
  int endSample;
  final String rawLabel;
  final int tercile;
  String finalName = SectionPreset.verse.name;
}
