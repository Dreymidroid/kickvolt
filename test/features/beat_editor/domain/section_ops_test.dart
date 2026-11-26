import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/beat_editor/beat_editor.dart';
import 'package:kickvolt/features/projects/projects.dart';

void main() {
  const n = 100000;
  const two = [
    Section(startSample: 0, endSample: 50000, name: 'Verse', colorArgb: 1),
    Section(startSample: 50000, endSample: n, name: 'Drop', colorArgb: 2),
  ];

  List<Beat> beats(List<int> samples) => [
    for (final s in samples) Beat(sample: s),
  ];

  group('splitSectionAt', () {
    test('snaps to the nearest beat inside the section', () {
      final out = splitSectionAt(
        sections: two,
        beats: beats([10000, 20000, 30000]),
        playheadSample: 21000,
        sampleCount: n,
      )!;
      expect(out.map((s) => s.endSample), [20000, 50000, n]);
      expect(areSectionsValid(out, n), isTrue);
    });

    test('ignores a nearer beat in the neighbouring section', () {
      // Playhead just inside "Drop"; the nearest beat overall is in "Verse".
      final out = splitSectionAt(
        sections: two,
        beats: beats([49900, 80000]),
        playheadSample: 50100,
        sampleCount: n,
      )!;
      expect(out.map((s) => s.endSample), [50000, 80000, n]);
      expect(out[0].name, 'Verse');
      expect(areSectionsValid(out, n), isTrue);
    });

    test('splits at the playhead when the section has no beats', () {
      final out = splitSectionAt(
        sections: two,
        beats: beats([1000, 2000]),
        playheadSample: 70000,
        sampleCount: n,
      )!;
      expect(out.map((s) => s.endSample), [50000, 70000, n]);
      expect(areSectionsValid(out, n), isTrue);
    });

    test('with no sections, creates "Song" and splits it', () {
      final out = splitSectionAt(
        sections: const [],
        beats: beats([40000]),
        playheadSample: 41000,
        sampleCount: n,
      )!;
      expect(out.first.name, 'Song');
      expect(out.map((s) => s.endSample), [40000, n]);
      expect(areSectionsValid(out, n), isTrue);
    });

    test('a split on an existing boundary is refused', () {
      expect(
        splitSectionAt(
          sections: two,
          beats: const [],
          playheadSample: 50000,
          sampleCount: n,
        ),
        isNull,
      );
    });
  });
}
