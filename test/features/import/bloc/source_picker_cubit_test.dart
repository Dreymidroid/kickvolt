import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/core/audio_native/audio_native_client.dart';
import 'package:kickvolt/features/import/import.dart';
import 'package:mocktail/mocktail.dart';

class MockSourcePicker extends Mock implements SourcePicker {}

void main() {
  const file = PickedSource(
    kind: ImportSourceKind.file,
    location: '/tmp/a.mp3',
    displayName: 'a.mp3',
  );
  final track = LibraryTrack(
    id: '42',
    title: 'Song',
    artist: 'Band',
    durationMs: 1000,
    uri: 'content://media/external/audio/media/42',
  );
  late MockSourcePicker picker;

  setUp(() => picker = MockSourcePicker());

  blocTest<SourcePickerCubit, SourcePickerState>(
    'pickFile emits busy then picked',
    build: () {
      when(() => picker.pickFile()).thenAnswer((_) async => file);
      return SourcePickerCubit(picker: picker);
    },
    act: (c) => c.pickFile(),
    expect: () => const [
      SourcePickerState.busy(),
      SourcePickerState.picked(file),
    ],
  );

  blocTest<SourcePickerCubit, SourcePickerState>(
    'a cancelled picker returns to idle',
    build: () {
      when(() => picker.pickVideo()).thenAnswer((_) async => null);
      return SourcePickerCubit(picker: picker);
    },
    act: (c) => c.pickVideo(),
    expect: () => const [SourcePickerState.busy(), SourcePickerState.idle()],
  );

  blocTest<SourcePickerCubit, SourcePickerState>(
    'iOS library uses the native picker; DRM surfaces as a failure',
    build: () {
      when(() => picker.usesNativeLibraryPicker).thenReturn(true);
      when(() => picker.pickLibraryTrack())
          .thenThrow(const ImportFailure(ImportFailureKind.protected));
      return SourcePickerCubit(picker: picker);
    },
    act: (c) => c.openLibrary(),
    expect: () => [
      const SourcePickerState.busy(),
      isA<SourcePickerFailed>().having(
        (s) => s.failure.kind,
        'kind',
        ImportFailureKind.protected,
      ),
    ],
  );

  blocTest<SourcePickerCubit, SourcePickerState>(
    'Android library lists tracks, then choosing one picks it',
    build: () {
      when(() => picker.usesNativeLibraryPicker).thenReturn(false);
      when(() => picker.listLibraryTracks()).thenAnswer((_) async => [track]);
      return SourcePickerCubit(picker: picker);
    },
    act: (c) async {
      await c.openLibrary();
      c.chooseLibraryTrack(track);
    },
    expect: () => [
      const SourcePickerState.busy(),
      SourcePickerState.library([track]),
      SourcePickerState.picked(
        PickedSource(
          kind: ImportSourceKind.library,
          location: track.uri,
          displayName: 'Song',
          durationMs: 1000,
        ),
      ),
    ],
  );

  test('PickedSource derives title and extension', () {
    const s = PickedSource(
      kind: ImportSourceKind.file,
      location: '/x/My.Song.MP3',
      displayName: 'My.Song.MP3',
    );
    expect(s.title, 'My.Song');
    expect(s.extension, 'mp3');
    expect(
      const PickedSource(
        kind: ImportSourceKind.library,
        location: 'content://x',
        displayName: 'NoExt',
      ).extension,
      '',
    );
  });
}
