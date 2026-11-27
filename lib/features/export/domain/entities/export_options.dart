import '../../../../core/audio_math/click_synth.dart';

/// Audio container format for the exported beat pack (§4.1, §4.6).
enum AudioFormat {
  wav('wav', 'WAV'),
  m4a('m4a', 'M4A');

  const AudioFormat(this.extension, this.label);

  final String extension;
  final String label;
}

/// Which file in the beat pack an entry represents.
enum ExportFileKind {
  song('Song'),
  guide('Guide track'),
  preview('Preview mix'),
  video('Guide video');

  const ExportFileKind(this.displayLabel);

  final String displayLabel;
}

/// User-selected options on the Export screen (§4.1).
class ExportOptions {
  const ExportOptions({
    this.includeSong = true,
    this.includeGuide = true,
    this.includePreview = false,
    this.includeVideo = false,
    this.clickStyle = ClickStyle.snap,
    this.format = AudioFormat.wav,
    this.monoGuide = false,
  });

  final bool includeSong;
  final bool includeGuide;
  final bool includePreview;

  /// Guide video (M7). Only honoured when `Entitlements.hasGuideVideo`.
  final bool includeVideo;
  final ClickStyle clickStyle;
  final AudioFormat format;
  final bool monoGuide;

  ExportOptions copyWith({
    bool? includeSong,
    bool? includeGuide,
    bool? includePreview,
    bool? includeVideo,
    ClickStyle? clickStyle,
    AudioFormat? format,
    bool? monoGuide,
  }) {
    return ExportOptions(
      includeSong: includeSong ?? this.includeSong,
      includeGuide: includeGuide ?? this.includeGuide,
      includePreview: includePreview ?? this.includePreview,
      includeVideo: includeVideo ?? this.includeVideo,
      clickStyle: clickStyle ?? this.clickStyle,
      format: format ?? this.format,
      monoGuide: monoGuide ?? this.monoGuide,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportOptions &&
          other.includeSong == includeSong &&
          other.includeGuide == includeGuide &&
          other.includePreview == includePreview &&
          other.includeVideo == includeVideo &&
          other.clickStyle == clickStyle &&
          other.format == format &&
          other.monoGuide == monoGuide;

  @override
  int get hashCode => Object.hash(
    includeSong,
    includeGuide,
    includePreview,
    includeVideo,
    clickStyle,
    format,
    monoGuide,
  );
}
