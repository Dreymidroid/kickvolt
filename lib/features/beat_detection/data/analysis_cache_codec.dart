import 'dart:typed_data';

import '../domain/entities/beat_analysis.dart';

/// Current binary format version for `analysis.bin`.
const int analysisCacheFormatVersion = 1;

const String _magic = 'KVAN';
const int _headerBytes = 40;
const int _candidateBytes = 20;

/// Encodes a [BeatAnalysis] into the compact little-endian `analysis.bin`
/// format (`KVAN` magic + versioned header + candidates + Float32 frame arrays).
///
/// Why binary (`.bin`) instead of `.json`:
/// A 10-minute song has ~52,000 hop frames (two float32 arrays) and ~1,200
/// candidate beats. Binary encoding is ~440 KB and serializes/deserializes in
/// < 2 ms without string allocation, consistent with `peaks.bin` (`KVPK`) and
/// `overview.bin`.
Uint8List encodeBeatAnalysis(BeatAnalysis a) {
  final nCand = a.candidates.length;
  final nFrames = a.frameLowEnergy.length;
  if (a.frameOverallEnergy.length != nFrames) {
    throw ArgumentError(
      'frameLowEnergy (${a.frameLowEnergy.length}) and '
      'frameOverallEnergy (${a.frameOverallEnergy.length}) must have the same length',
    );
  }

  final totalBytes = _headerBytes + nCand * _candidateBytes + nFrames * 4 * 2;
  final out = Uint8List(totalBytes);
  final bd = ByteData.sublistView(out);

  for (var i = 0; i < 4; i++) {
    out[i] = _magic.codeUnitAt(i);
  }
  bd.setUint16(4, analysisCacheFormatVersion, Endian.little);
  bd.setUint16(6, 0, Endian.little);
  bd.setUint32(8, a.sampleRate, Endian.little);
  bd.setUint32(12, a.sampleCount, Endian.little);
  bd.setUint32(16, a.hopSize, Endian.little);
  bd.setFloat32(20, a.bpm, Endian.little);
  bd.setFloat32(24, a.confidence, Endian.little);
  bd.setUint32(28, a.beatPhaseSample, Endian.little);
  bd.setUint32(32, nCand, Endian.little);
  bd.setUint32(36, nFrames, Endian.little);

  var offset = _headerBytes;
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

  final sampleRate = bd.getUint32(8, Endian.little);
  final sampleCount = bd.getUint32(12, Endian.little);
  final hopSize = bd.getUint32(16, Endian.little);
  final bpm = bd.getFloat32(20, Endian.little);
  final confidence = bd.getFloat32(24, Endian.little);
  final beatPhaseSample = bd.getUint32(28, Endian.little);
  final nCand = bd.getUint32(32, Endian.little);
  final nFrames = bd.getUint32(36, Endian.little);

  if (sampleRate == 0 || hopSize == 0) {
    throw const FormatException(
      'Invalid sampleRate or hopSize in analysis.bin',
    );
  }

  final expectedBytes =
      _headerBytes + nCand * _candidateBytes + nFrames * 4 * 2;
  if (bytes.length != expectedBytes) {
    throw FormatException(
      'Corrupt analysis.bin size: expected $expectedBytes, got ${bytes.length}',
    );
  }

  var offset = _headerBytes;
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

  final frameLow = Float32List(nFrames);
  for (var i = 0; i < nFrames; i++) {
    final v = bd.getFloat32(offset, Endian.little);
    if (!v.isFinite) {
      throw const FormatException('Non-finite float in analysis.bin frameLow');
    }
    frameLow[i] = v;
    offset += 4;
  }

  final frameOverall = Float32List(nFrames);
  for (var i = 0; i < nFrames; i++) {
    final v = bd.getFloat32(offset, Endian.little);
    if (!v.isFinite) {
      throw const FormatException(
        'Non-finite float in analysis.bin frameOverall',
      );
    }
    frameOverall[i] = v;
    offset += 4;
  }

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
  );
}
