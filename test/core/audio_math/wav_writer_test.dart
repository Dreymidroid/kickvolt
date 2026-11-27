import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_math/wav_header.dart';
import 'package:kickvolt/core/audio_math/wav_writer.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kickvolt_wav_writer_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WavWriter header & round-trip', () {
    for (final channels in [1, 2]) {
      for (final sampleRate in [44100, 48000]) {
        test('writes exact 44-byte header and PCM payload for '
            '${channels == 1 ? 'mono' : 'stereo'} $sampleRate Hz', () async {
          const frameCount = 1234;
          final outPath =
              '${tempDir.path}${Platform.pathSeparator}test_${channels}_$sampleRate.wav';
          final samples = Int16List(frameCount * channels);
          for (var i = 0; i < samples.length; i++) {
            samples[i] = ((i * 97) % 65536) - 32768;
          }

          final writer = await WavWriter.open(
            outputPath: outPath,
            sampleRate: sampleRate,
            channels: channels,
            frameCount: frameCount,
          );
          // Write in three chunks to exercise streaming.
          await writer.writeFrames(
            Int16List.sublistView(samples, 0, 500 * channels),
            500,
          );
          await writer.writeFrames(
            Int16List.sublistView(samples, 500 * channels, 1000 * channels),
            500,
          );
          await writer.writeFrames(
            Int16List.sublistView(
              samples,
              1000 * channels,
              frameCount * channels,
            ),
            frameCount - 1000,
          );
          await writer.finish();

          expect(await File('$outPath.part').exists(), isFalse);
          final outFile = File(outPath);
          expect(await outFile.exists(), isTrue);

          // Read back with readWavInfo.
          final info = await readWavInfo(outFile);
          expect(info.sampleRate, sampleRate);
          expect(info.channels, channels);
          expect(info.bitsPerSample, 16);
          expect(info.dataOffset, 44);
          expect(info.frameCount, frameCount);
          expect(info.dataBytes, frameCount * channels * 2);

          // Verify byte-by-byte for all 44 header bytes.
          final bytes = await outFile.readAsBytes();
          final dataBytes = frameCount * channels * 2;
          final blockAlign = channels * 2;
          final byteRate = sampleRate * blockAlign;
          expect(bytes.length, 44 + dataBytes);

          final bd = ByteData.sublistView(bytes, 0, 44);
          expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
          expect(bd.getUint32(4, Endian.little), 36 + dataBytes);
          expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
          expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
          expect(bd.getUint32(16, Endian.little), 16);
          expect(bd.getUint16(20, Endian.little), 1); // PCM format 1
          expect(bd.getUint16(22, Endian.little), channels);
          expect(bd.getUint32(24, Endian.little), sampleRate);
          expect(bd.getUint32(28, Endian.little), byteRate);
          expect(bd.getUint16(32, Endian.little), blockAlign);
          expect(bd.getUint16(34, Endian.little), 16); // bitsPerSample
          expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
          expect(bd.getUint32(40, Endian.little), dataBytes);

          // Verify PCM payload read back from disk matches written samples.
          final payload = ByteData.sublistView(bytes, 44);
          for (var i = 0; i < samples.length; i++) {
            expect(payload.getInt16(i * 2, Endian.little), samples[i]);
          }
        });
      }
    }

    test('supports 0-frame and 1-frame files', () async {
      final path0 = '${tempDir.path}${Platform.pathSeparator}zero.wav';
      final w0 = await WavWriter.open(
        outputPath: path0,
        sampleRate: 44100,
        channels: 2,
        frameCount: 0,
      );
      await w0.finish();

      final info0 = await readWavInfo(File(path0));
      expect(info0.frameCount, 0);
      expect(info0.dataBytes, 0);
      expect((await File(path0).readAsBytes()).length, 44);

      final path1 = '${tempDir.path}${Platform.pathSeparator}one.wav';
      final w1 = await WavWriter.open(
        outputPath: path1,
        sampleRate: 48000,
        channels: 2,
        frameCount: 1,
      );
      await w1.writeFrames(Int16List.fromList([-12345, 23456]), 1);
      await w1.finish();

      final info1 = await readWavInfo(File(path1));
      expect(info1.frameCount, 1);
      expect(info1.dataBytes, 4);
      final bytes1 = await File(path1).readAsBytes();
      expect(bytes1.length, 48);
      final bd1 = ByteData.sublistView(bytes1, 44);
      expect(bd1.getInt16(0, Endian.little), -12345);
      expect(bd1.getInt16(2, Endian.little), 23456);
    });

    test(
      'written-frames mismatch throws and leaves no .part or final file',
      () async {
        final outPath = '${tempDir.path}${Platform.pathSeparator}mismatch.wav';
        final writer = await WavWriter.open(
          outputPath: outPath,
          sampleRate: 44100,
          channels: 1,
          frameCount: 100,
        );
        await writer.writeFrames(Int16List(60), 60);

        await expectLater(writer.finish(), throwsA(isA<StateError>()));
        expect(await File(outPath).exists(), isFalse);
        expect(await File('$outPath.part').exists(), isFalse);

        // Over-writing beyond declared frameCount also throws and cleans up.
        final outPath2 = '${tempDir.path}${Platform.pathSeparator}over.wav';
        final writer2 = await WavWriter.open(
          outputPath: outPath2,
          sampleRate: 44100,
          channels: 1,
          frameCount: 10,
        );
        await expectLater(
          writer2.writeFrames(Int16List(12), 12),
          throwsA(isA<StateError>()),
        );
        await writer2.abort();
        expect(await File(outPath2).exists(), isFalse);
        expect(await File('$outPath2.part').exists(), isFalse);
      },
    );

    test(
      'cancel/abort leaves no .part and folder deletes immediately on Windows',
      () async {
        final subDir = Directory('${tempDir.path}${Platform.pathSeparator}sub');
        await subDir.create(recursive: true);
        final outPath = '${subDir.path}${Platform.pathSeparator}cancelled.wav';

        final writer = await WavWriter.open(
          outputPath: outPath,
          sampleRate: 44100,
          channels: 2,
          frameCount: 1000,
        );
        await writer.writeFrames(Int16List(400), 200);
        await writer.abort();

        expect(await File(outPath).exists(), isFalse);
        expect(await File('$outPath.part').exists(), isFalse);

        // Must succeed immediately on Windows without a sharing violation.
        await subDir.delete(recursive: true);
        expect(await subDir.exists(), isFalse);
      },
    );
  });
}
