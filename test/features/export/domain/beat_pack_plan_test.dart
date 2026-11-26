import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/click_synth.dart';
import 'package:kickvolt/features/beat_detection/beat_detection.dart';
import 'package:kickvolt/features/export/export.dart';
import 'package:kickvolt/features/projects/projects.dart';

import '../../../fixtures/demo_project.dart';

void main() {
  group('sanitizeExportTitle', () {
    test('drops spaces and reserved filesystem characters', () {
      expect(sanitizeExportTitle('Midnight Run'), 'MidnightRun');
      expect(
        sanitizeExportTitle('Song: "Best" /Track\\ *1*? <final>|v2'),
        'SongBestTrack1finalv2',
      );
    });

    test('trims dots and whitespace and drops control characters', () {
      expect(sanitizeExportTitle('  ..My\t\n\x07 Song...  '), 'MySong');
      expect(sanitizeExportTitle('...'), 'KickVolt');
      expect(sanitizeExportTitle('   '), 'KickVolt');
      expect(sanitizeExportTitle(''), 'KickVolt');
    });

    test('preserves Unicode letters and numbers', () {
      expect(sanitizeExportTitle('Café Été 東京 2026'), 'CaféÉté東京2026');
    });

    test('caps at 60 UTF-16 code units without splitting a surrogate pair', () {
      // 59 ASCII 'a' + 1 emoji (2 UTF-16 code units = surrogate pair 🔥).
      // Total would be 61 code units; capping at 60 must drop the surrogate
      // pair rather than leaving a lone high surrogate at index 59.
      final title = '${'a' * 59}🔥b';
      final sanitized = sanitizeExportTitle(title);
      expect(sanitized.length, 59);
      expect(sanitized, 'a' * 59);

      // 58 ASCII 'a' + 1 emoji (2 code units) = 60 code units -> emoji kept intact.
      final fitsEmoji = '${'a' * 58}🔥b';
      final sanitizedFits = sanitizeExportTitle(fitsEmoji);
      expect(sanitizedFits.length, 60);
      expect(sanitizedFits, '${'a' * 58}🔥');
    });
  });

  group('planBeatPack', () {
    test('uses one format for the whole pack and names files _song, _beats, _preview', () {
      final project = createDemoProject(); // Midnight Run, 358 beats, 44.1 kHz

      final wavPlan = planBeatPack(
        project,
        const ExportOptions(
          format: AudioFormat.wav,
          includePreview: false,
          clickStyle: ClickStyle.snap,
        ),
      );
      expect(wavPlan.sanitizedTitle, 'MidnightRun');
      expect(wavPlan.visibleBeatSamples.length, 358);
      expect(wavPlan.files.length, 2);
      // Order: guide -> song (§4.7)
      expect(wavPlan.files[0].kind, ExportFileKind.guide);
      expect(wavPlan.files[0].fileName, 'MidnightRun_beats.wav');
      expect(wavPlan.files[1].kind, ExportFileKind.song);
      expect(wavPlan.files[1].fileName, 'MidnightRun_song.wav');

      final m4aWithPreview = planBeatPack(
        project,
        const ExportOptions(
          format: AudioFormat.m4a,
          includePreview: true,
          clickStyle: ClickStyle.rim,
        ),
      );
      expect(m4aWithPreview.files.length, 3);
      expect(
        m4aWithPreview.files.map((f) => f.fileName).toList(),
        [
          'MidnightRun_beats.m4a',
          'MidnightRun_song.m4a',
          'MidnightRun_preview.m4a',
        ],
      );
    });

    test('uses only visible beats from the project filter, sorted and deduplicated', () {
      final project = createDemoProject(includeBeats: false).copyWith(
        sampleCount: 100000,
        beats: const [
          Beat(sample: 1000, type: BeatType.beat),
          Beat(sample: 2000, type: BeatType.drop),
          Beat(sample: 3000, type: BeatType.strong),
          Beat(sample: 4000, type: BeatType.drop),
        ],
        detection: const DetectionSettings(filter: BeatFilter.drops),
      );

      final plan = planBeatPack(project, const ExportOptions());
      expect(plan.visibleBeatSamples, [2000, 4000]);
      expect(plan.clickCount, 2);
    });

    test('estimates bytes accurately for WAV and M4A (stereo and mono guide)', () {
      const frames = 44100 * 10; // 10 s
      final project = createDemoProject(includeBeats: false).copyWith(
        sampleRate: 44100,
        channels: 2,
        sampleCount: frames,
      );

      const stereoWavBytes = 44 + frames * 2 * 2;
      const monoWavBytes = 44 + frames * 1 * 2;

      final stereoWavPlan = planBeatPack(
        project,
        const ExportOptions(
          format: AudioFormat.wav,
          includePreview: false,
          monoGuide: false,
        ),
      );
      expect(stereoWavPlan.estimatedDiskBytes, stereoWavBytes * 2);

      final monoGuideWavPlan = planBeatPack(
        project,
        const ExportOptions(
          format: AudioFormat.wav,
          includePreview: false,
          monoGuide: true,
        ),
      );
      expect(
        monoGuideWavPlan.estimatedDiskBytes,
        stereoWavBytes + monoWavBytes,
      );

      // M4A estimate: WAV estimate * 0.25 per file (§4.7).
      final m4aPlan = planBeatPack(
        project,
        const ExportOptions(
          format: AudioFormat.m4a,
          includePreview: true,
          monoGuide: false,
        ),
      );
      expect(
        m4aPlan.estimatedDiskBytes,
        (stereoWavBytes * 3 * 0.25).ceil(),
      );
    });
  });
}
