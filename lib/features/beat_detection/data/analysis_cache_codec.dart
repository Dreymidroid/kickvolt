import 'dart:typed_data';

import '../domain/entities/beat_analysis.dart';

/// Current binary format version for `analysis.bin` (bumped to 2 for M4b §4.1).
const int analysisCacheFormatVersion = 2;

const String _magic = 'KVAN';
const int _headerBytes = 56;
const int _candidateBytes = 20;
const int _tempoCandidateBytes = 12;

/// Encodes a [BeatAnalysis] into the compact little-endian `analysis.bin`
/// format (`KVAN` magic + v2 header + candidates + Float32 frame arrays +
/// onset envelopes + tempo candidates + local tempo curve).
///
/// Header layout (56 bytes):
/// - `0..4`: `'KVAN'` magic
/// - `4..6`: `uint16` version (`2`)
/// - `6..8`: `uint16` nTempoCandidates
/// - `8..12`: `uint32` sampleRate
/// - `12..16`: `uint32` sampleCount
/// - `16..20`: `uint32` hopSize
/// - `20..24`: `float32` bpm
/// - `24..28`: `float32` confidence
/// - `28..32`: `uint32` beatPhaseSample
/// - `32..36`: `uint32` nCandidates
/// - `36..40`: `uint32` nFrames (`frameLowEnergy` & `frameOverallEnergy` length)
/// - `40..44`: `uint32` nOnsetFrames (`onsetEnvelope` & `lowMidOnsetEnvelope` length)
/// - `44..48`: `uint32` nLocalTempo (`localTempo` length)
/// - `48..52`: `float32` tempoStability
/// - `52..56`: `float16/float32` -> we store `swing.ratio` and `swing.confidence`
///   in the body or expand header to 60 bytes.
const int _v2HeaderBytes = 60;

Uint8List encodeBeatAnalysis(BeatAnalysis a) {
  final nCand = a.candidates.length;
  final nFrames = a.frameLowEnergy.length;
  if (a.frameOverallEnergy.length != nFrames) {
    throw ArgumentError(
      'frameLowEnergy (${a.frameLowEnergy.length}) and '
      'frameOverallEnergy (${a.frameOverallEnergy.length}) must have the same length',
    );
  }
  final nOnset = a.onsetEnvelope.length;
  final hasLowMid = a.lowMidOnsetEnvelope.length == nOnset && nOnset > 0;
  final nTempoCand = a.tempoCandidates.length;
  final nLocal = a.localTempo.length;

  final totalBytes =
      _v2HeaderBytes +
      nCand * _candidateBytes +
      nFrames * 4 * 2 +
      nOnset * 4 * 2 +
      nTempoCand * _tempoCandidateBytes +
      nLocal * 4;
  final out = Uint8List(totalBytes);
  final bd = ByteData.sublistView(out);

  for (var i = 0; i < 4; i++) {
    out[i] = _magic.codeUnitAt(i);
  }
  bd.setUint16(4, analysisCacheFormatVersion, Endian.little);
  bd.setUint16(6, nTempoCand, Endian.little);
  bd.setUint32(8, a.sampleRate, Endian.little);
  bd.setUint32(12, a.sampleCount, Endian.little);
  bd.setUint32(16, a.hopSize, Endian.little);
  bd.setFloat32(20, a.bpm, Endian.little);
  bd.setFloat32(24, a.confidence, Endian.little);
  bd.setUint32(28, a.beatPhaseSample, Endian.little);
  bd.setUint32(32, nCand, Endian.little);
  bd.setUint32(36, nFrames, Endian.little);
  bd.setUint32(40, nOnset, Endian.little);
  bd.setUint32(44, nLocal, Endian.little);
  bd.setFloat32(48, a.tempoStability, Endian.little);
  bd.setFloat32(52, a.swing.ratio, Endian.little);
  bd.setFloat32(56, a.swing.confidence, Endian.little);

  var offset = _v2HeaderBytes;
  for (var i = 0; i < nCand; i++) {
    final c = a.candidates[i];
    bd.setUint32(offset, c.index, Endian.little);
    bd.setUint32(offset + 4, c.sample, Endian.little);
    bd.setFloat32(offset + 8, c.strength, Endian.little);
    bd.setFloat32(offset + 12, c.lowEnergy, Endian.little);
    bd.setUint32(offset + 16, 0, Endian.little);
    offset += _candidateBytes;
  }

  for (var i = 0; i < nFrames; i++) {
    bd.setFloat32(offset, a.frameLowEnergy[i], Endian.little);
    offset += 4;
  }
  for (var i = 0; i < nFrames; i++) {
    bd.setFloat32(offset, a.frameOverallEnergy[i], Endian.little);
    offset += 4;
  }

  for (var i = 0; i < nOnset; i++) {
    bd.setFloat32(offset, a.onsetEnvelope[i], Endian.little);
    offset += 4;
  }
  for (var i = 0; i < nOnset; i++) {
    bd.setFloat32(
      offset,
      hasLowMid ? a.lowMidOnsetEnvelope[i] : 0.0,
      Endian.little,
    );
    offset += 4;
  }

  for (var i = 0; i < nTempoCand; i++) {
    final tc = a.tempoCandidates[i];
    bd.setFloat32(offset, tc.bpm, Endian.little);
    bd.setFloat32(offset + 4, tc.periodFrames, Endian.little);
    bd.setFloat32(offset + 8, tc.score, Endian.little);
    offset += _tempoCandidateBytes;
  }

  for (var i = 0; i < nLocal; i++) {
    bd.setFloat32(offset, a.localTempo[i], Endian.little);
    offset += 4;
  }

  return out;
}

/// Decodes a [BeatAnalysis] from [bytes], throwing [FormatException] if the
/// magic, version, or byte length is invalid or corrupt.
BeatAnalysis decodeBeatAnalysis(Uint8List bytes) {
  if (bytes.length < _headerBytes ||
      String.fromCharCodes(bytes, 0, 4) != _magic) {
    throw const FormatException('Not an analysis.bin file');
  }

  final bd = ByteData.sublistView(bytes);
  final version = bd.getUint16(4, Endian.little);
  if (version != analysisCacheFormatVersion) {
    throw FormatException('Unsupported analysis.bin version $version');
  }
  if (bytes.length < _v2HeaderBytes) {
    throw const FormatException('Truncated v2 analysis.bin header');
  }

  final nTempoCand = bd.getUint16(6, Endian.little);
  final sampleRate = bd.getUint32(8, Endian.little);
  final sampleCount = bd.getUint32(12, Endian.little);
  final hopSize = bd.getUint32(16, Endian.little);
  final bpm = bd.getFloat32(20, Endian.little);
  final confidence = bd.getFloat32(24, Endian.little);
  final beatPhaseSample = bd.getUint32(28, Endian.little);
  final nCand = bd.getUint32(32, Endian.little);
  final nFrames = bd.getUint32(36, Endian.little);
  final nOnset = bd.getUint32(40, Endian.little);
  final nLocal = bd.getUint32(44, Endian.little);
  final tempoStability = bd.getFloat32(48, Endian.little);
  final swingRatio = bd.getFloat32(52, Endian.little);
  final swingConf = bd.getFloat32(56, Endian.little);

  if (sampleRate == 0 || hopSize == 0) {
    throw const FormatException(
      'Invalid sampleRate or hopSize in analysis.bin',
    );
  }
  if (!tempoStability.isFinite || !swingRatio.isFinite || !swingConf.isFinite) {
    throw const FormatException('Non-finite header float in analysis.bin');
  }

  final expectedBytes =
      _v2HeaderBytes +
      nCand * _candidateBytes +
      nFrames * 4 * 2 +
      nOnset * 4 * 2 +
      nTempoCand * _tempoCandidateBytes +
      nLocal * 4;
  if (bytes.length != expectedBytes) {
    throw FormatException(
      'Corrupt analysis.bin size: expected $expectedBytes, got ${bytes.length}',
    );
  }

  var offset = _v2HeaderBytes;
  final candidates = <CandidateBeat>[];
  for (var i = 0; i < nCand; i++) {
    final index = bd.getUint32(offset, Endian.little);
    final sample = bd.getUint32(offset + 4, Endian.little);
    final strength = bd.getFloat32(offset + 8, Endian.little);
    final lowEnergy = bd.getFloat32(offset + 12, Endian.little);
    offset += _candidateBytes;
    if (!strength.isFinite || !lowEnergy.isFinite) {
      throw const FormatException('Non-finite float in analysis.bin candidate');
    }
    candidates.add(
      CandidateBeat(
        index: index,
        sample: sample,
        strength: strength,
        lowEnergy: lowEnergy,
      ),
    );
  }

  Float32List readFloat32Array(int len, String label) {
    final list = Float32List(len);
    for (var i = 0; i < len; i++) {
      final v = bd.getFloat32(offset, Endian.little);
      if (!v.isFinite) {
        throw FormatException('Non-finite float in analysis.bin $label');
      }
      list[i] = v;
      offset += 4;
    }
    return list;
  }

  final frameLow = readFloat32Array(nFrames, 'frameLow');
  final frameOverall = readFloat32Array(nFrames, 'frameOverall');
  final onsetEnv = readFloat32Array(nOnset, 'onsetEnvelope');
  final lowMidEnv = readFloat32Array(nOnset, 'lowMidOnsetEnvelope');

  final tempoCandidates = <TempoCandidate>[];
  for (var i = 0; i < nTempoCand; i++) {
    final cBpm = bd.getFloat32(offset, Endian.little);
    final cPeriod = bd.getFloat32(offset + 4, Endian.little);
    final cScore = bd.getFloat32(offset + 8, Endian.little);
    offset += _tempoCandidateBytes;
    if (!cBpm.isFinite || !cPeriod.isFinite || !cScore.isFinite) {
      throw const FormatException(
        'Non-finite float in analysis.bin tempoCandidate',
      );
    }
    tempoCandidates.add(
      TempoCandidate(
        bpm: (cBpm * 10.0).round() / 10.0,
        periodFrames: cPeriod,
        score: cScore,
      ),
    );
  }

  final localTempo = readFloat32Array(nLocal, 'localTempo');

  // Round bpm to 0.1 to remove float32 rounding dust (e.g. 128.000003 -> 128.0).
  final cleanBpm = (bpm * 10.0).round() / 10.0;

  return BeatAnalysis(
    sampleRate: sampleRate,
    sampleCount: sampleCount,
    hopSize: hopSize,
    bpm: cleanBpm,
    confidence: confidence,
    beatPhaseSample: beatPhaseSample,
    candidates: candidates,
    frameLowEnergy: frameLow,
    frameOverallEnergy: frameOverall,
    onsetEnvelope: onsetEnv,
    lowMidOnsetEnvelope: lowMidEnv,
    tempoCandidates: tempoCandidates,
    localTempo: localTempo,
    tempoStability: tempoStability,
    swing: SwingEstimate(ratio: swingRatio, confidence: swingConf),
  );
}
