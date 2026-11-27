import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_native/audio_api.g.dart';
import 'package:kickvolt/core/audio_native/audio_native_client.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioHostApi extends Mock implements AudioHostApi {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAudioHostApi host;
  late AudioNativeClient client;

  setUp(() {
    host = _MockAudioHostApi();
    client = AudioNativeClient(host: host);
  });

  group('AudioErrorKind.fromCode', () {
    test('maps every documented native error code including encode_failed', () {
      expect(
        AudioErrorKind.fromCode('drm_protected'),
        AudioErrorKind.drmProtected,
      );
      expect(AudioErrorKind.fromCode('cloud_item'), AudioErrorKind.cloudItem);
      expect(
        AudioErrorKind.fromCode('no_audio_track'),
        AudioErrorKind.noAudioTrack,
      );
      expect(
        AudioErrorKind.fromCode('unsupported_format'),
        AudioErrorKind.unsupportedFormat,
      );
      expect(
        AudioErrorKind.fromCode('decode_failed'),
        AudioErrorKind.decodeFailed,
      );
      expect(
        AudioErrorKind.fromCode('encode_failed'),
        AudioErrorKind.encodeFailed,
      );
      expect(AudioErrorKind.fromCode('disk_full'), AudioErrorKind.diskFull);
      expect(
        AudioErrorKind.fromCode('permission_denied'),
        AudioErrorKind.permissionDenied,
      );
      expect(AudioErrorKind.fromCode('cancelled'), AudioErrorKind.cancelled);
      expect(
        AudioErrorKind.fromCode('something_unexpected'),
        AudioErrorKind.unknown,
      );
    });
  });

  group('AudioNativeClient M6 methods', () {
    test('encodeM4a forwards progress and returns MediaInfo', () async {
      when(() => host.encodeM4a('job-1', '/in.wav', '/out.m4a', 192000))
          .thenAnswer((_) async {
            client.onProgress('job-1', 0.25);
            client.onProgress('job-1', 0.75);
            return MediaInfo(
              sampleRate: 44100,
              channels: 2,
              durationUs: 1000000,
              frameCount: 44100,
            );
          });

      final progress = <double>[];
      final info = await client.encodeM4a(
        jobId: 'job-1',
        wavPath: '/in.wav',
        outPath: '/out.m4a',
        onProgress: progress.add,
      );

      expect(info.sampleRate, 44100);
      expect(info.channels, 2);
      expect(info.durationUs, 1000000);
      expect(info.frameCount, 44100);
      expect(progress, [0.25, 0.75]);
    });

    test('encodeM4a maps PlatformException(encode_failed) to typed AudioNativeException', () async {
      when(() => host.encodeM4a(any(), any(), any(), any())).thenThrow(
        PlatformException(code: 'encode_failed', message: 'Unsupported rate'),
      );

      await expectLater(
        client.encodeM4a(
          jobId: 'job-2',
          wavPath: '/in.wav',
          outPath: '/out.m4a',
        ),
        throwsA(
          isA<AudioNativeException>()
              .having((e) => e.kind, 'kind', AudioErrorKind.encodeFailed)
              .having((e) => e.message, 'message', 'Unsupported rate'),
        ),
      );
    });

    test('encodeM4a maps disk_full and cancelled PlatformExceptions', () async {
      when(() => host.encodeM4a('job-disk', any(), any(), any()))
          .thenThrow(PlatformException(code: 'disk_full', message: 'ENOSPC'));
      when(() => host.encodeM4a('job-cancel', any(), any(), any()))
          .thenThrow(PlatformException(code: 'cancelled', message: 'Stopped'));

      await expectLater(
        client.encodeM4a(
          jobId: 'job-disk',
          wavPath: '/in.wav',
          outPath: '/out.m4a',
        ),
        throwsA(
          isA<AudioNativeException>().having(
            (e) => e.kind,
            'kind',
            AudioErrorKind.diskFull,
          ),
        ),
      );

      await expectLater(
        client.encodeM4a(
          jobId: 'job-cancel',
          wavPath: '/in.wav',
          outPath: '/out.m4a',
        ),
        throwsA(
          isA<AudioNativeException>().having(
            (e) => e.kind,
            'kind',
            AudioErrorKind.cancelled,
          ),
        ),
      );
    });

    test('probeMedia, saveToFiles, beginBackgroundWork, endBackgroundWork delegate to host', () async {
      when(() => host.probeMedia('/song.m4a')).thenAnswer(
        (_) async => MediaInfo(
          sampleRate: 48000,
          channels: 1,
          durationUs: 2000000,
          frameCount: 96000,
        ),
      );
      when(() => host.saveToFiles(['/a.wav', '/b.wav']))
          .thenAnswer((_) async => 2);
      when(() => host.beginBackgroundWork('export'))
          .thenAnswer((_) async => 42);
      when(() => host.endBackgroundWork(42)).thenAnswer((_) async {});

      final info = await client.probeMedia('/song.m4a');
      expect(info.sampleRate, 48000);
      expect(info.channels, 1);
      expect(info.frameCount, 96000);

      final saved = await client.saveToFiles(['/a.wav', '/b.wav']);
      expect(saved, 2);

      final token = await client.beginBackgroundWork('export');
      expect(token, 42);
      await client.endBackgroundWork(token);
      verify(() => host.endBackgroundWork(42)).called(1);
    });

    test('requestAudioPermission delegates granted/denied results and maps PlatformException', () async {
      when(() => host.requestAudioPermission()).thenAnswer((_) async => true);
      expect(await client.requestAudioPermission(), isTrue);

      when(() => host.requestAudioPermission()).thenAnswer((_) async => false);
      expect(await client.requestAudioPermission(), isFalse);

      when(() => host.requestAudioPermission()).thenThrow(
        PlatformException(code: 'permission_denied', message: 'Denied'),
      );
      await expectLater(
        client.requestAudioPermission(),
        throwsA(
          isA<AudioNativeException>().having(
            (e) => e.kind,
            'kind',
            AudioErrorKind.permissionDenied,
          ),
        ),
      );
    });
  });
}
