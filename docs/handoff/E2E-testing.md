# KickVolt — End-to-end testing

Two parts:

- **Part A — Automated.** What the unit/widget suite covers today, the
  gaps per milestone, and `integration_test` flows that run the real app
  (real native decode/encode, real files) on an emulator, simulator or
  device, locally and on Codemagic. Part A ends with a prompt you can hand
  to an agent to build it.
- **Part B — Manual, physical devices.** A device matrix, step-by-step
  cases for the whole product with expected results, and a results
  template you fill in.

Do Part A's integration tests after M6 is merged (they need export); add
the M7/M8 flows when those land. Part B can start as soon as a build
installs on a phone — **the first device run is also the first time M1's
native decoders run at all.**

---

## 0. Prerequisites (yours to sort out)

| # | What | Why / how |
|---|---|---|
| P1 | **Fix the local Android build.** Delete `%USERPROFILE%\.gradle\wrapper\dists\gradle-9.3.1-all\9ot9r568e8zfvvd4mn8rbu1j0\gradle-9.3.1-all.zip` and the `.lck` next to it (or the whole `gradle-9.3.1-all` folder), then run `flutter build apk --debug` once on a good connection. | The zip is truncated (~150 MB of ~220 MB), so every Android build fails. Nothing Android has ever compiled locally. |
| P2 | **Run Codemagic once.** Connect the GitHub repo, start the existing `ci` workflow on `main`. | `codemagic.yaml` exists but has never run. It's the only place iOS compiles. Expect Swift/Kotlin compile errors on the first run (M1's decoders have never been built). |
| P3 | **iOS device installs need signing.** Options: (a) an Apple Developer account ($99/yr) + Codemagic automatic signing + TestFlight; (b) a Mac with Xcode and your Apple ID (free provisioning, 7-day apps). From Windows only (a) works. | The CI build is `--no-codesign`, which can't be installed on a phone. |
| P4 | **Android release signing.** Release builds still use the debug key (`android/app/build.gradle.kts`). Fine for sideloading test builds; a Play upload (needed for purchase testing, M8) needs an upload key. | Play internal testing, license testers. |
| P5 | **An Android device** with USB debugging on, or an emulator (Android Studio › Device Manager, API 24 and 34 images). | Local integration tests and manual cases. |
| P6 | **Test songs** you own (not DRM): MP3, M4A/AAC, WAV, one per genre in B3, a 10-minute track, and a short video with audio. Put them on each phone (Files / Downloads). | Manual cases. Never commit them. |
| P7 | CapCut and VN installed on the test phones, latest versions; note their versions in the results. | The product goal (B5). |
| P8 | For M8: RevenueCat project, store products, sandbox testers / license testers (see `docs/revenuecat-setup.md`, written in M8). | Purchase cases. |

---

## Part A — Automated tests

### A1. What exists today

`flutter test` on `main` ran ≈190 test cases for M1–M4; M5 (merged
2026-11-26) added about 50 more. Run `flutter test` and note the current
total. All are pure-Dart unit, cubit or widget tests run on the host; none
runs native code. One known weak spot: `pcm_window_loader_test` (M3) still
waits 50 ms of real time and failed once under heavy load — make it
deterministic.

| Area | Files on `main` | Covers |
|---|---|---|
| Audio maths | `test/core/audio_math/{wav_header,peaks,overview,pcm_window_loader}_test.dart`; M5: `click_synth_test`, `preview_mix_test` | WAV header read/build, peak levels vs brute force, overview bins, PCM windows; click attack/level; preview mix positions and cancel |
| Import | `test/features/import/{bloc,data}/…` | `ImportCubit`/`SourcePickerCubit` flows with a fake `AudioNative`; repository copy → decode → header cross-check (fake decoder writes WAVs) |
| Projects | `test/features/projects/…` | JSON model round trip, atomic writes, index rebuild, Home cubit, "edited" labels |
| Playback | `test/features/playback/playhead_{clock,controller}_test.dart` | Smoothing maths, seek/scrub; `FakeAudioPlayback` |
| Detection | `test/features/beat_detection/…` | Synthetic click tracks (90/120/128 BPM, noise, rates, channels), music-like grooves at three levels, classification, filter, sections, analysis cache |
| Editor | `test/features/beat_editor/…`; M5: `command_stack_test`, `playhead_pass_test`, `beat_editor_m5_test`, `beat_editor_click_preview_test`, `presentation/beat_editor_screen_test` | Cubit edits, selection, detection integration; M5: command stack properties, tap marking, bulk/sections, click preview swaps, first widget tests |
| Settings (M5) | `test/features/settings/…` | Settings repository, calibration maths, output route |

Run them:

```powershell
flutter test
```

### A2. Gaps per milestone

| Milestone | Missing (host tests) | Missing (needs a device → A3/Part B) |
|---|---|---|
| M1 Import | Widget tests for ImportSheet, Analyzing, ImportError; error-code mapping for every native code | **Real decode** of MP3/M4A/AAC/WAV/video, DRM and cloud errors, Android content URIs, music library |
| M2 Projects | Home widget tests (rename, delete, empty state) | Real documents directory, app restart persistence |
| M3 Waveform | Painter golden or structure tests at several zooms | just_audio playback, speed, 60 fps |
| M4 Detection | Real-music fixtures (only synthetic audio so far) | Detection on decoded real songs |
| M5 Editor | Fill any gaps found when M5 is verified | Tap timing, latency, Bluetooth routes, click preview by ear |
| M6 Export | (M6 brief lists them) | **M4A encode**, Save to Files, share sheet, backgrounding |
| M7 Video | (M7 brief) | **H.264 encode**, flash frames visible in editors |
| M8 | (M8 brief) | Purchases, restore, permissions, first run |

The last column is the reason for A3: the native half of the app (decode,
encode, save, permissions) has no automated test at all.

### A3. Integration tests (`integration_test/`)

#### A3.1 Setup

- `pubspec.yaml` dev dependency: `integration_test: { sdk: flutter }`
  (it ships with the Flutter SDK; the pub.dev package of that name is an
  old copy — don't use it).
- Tests live in `integration_test/*_test.dart`, each calling
  `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`.
- **A test seam in the app:** add `lib/app/bootstrap.dart` with
  `Future<void> bootstrap({void Function(GetIt locator)? overrides})` that
  `main()` calls with no overrides. Integration tests call it with
  overrides, then `pumpWidget(const App())`. Override only what can't be
  scripted:
  - `SourcePicker` → `FixtureSourcePicker` that returns a `PickedSource`
    for a fixture file it wrote to the temp directory. **Everything after
    the pick is real**: copy into the project, native `decodeToWav`, peaks,
    detection, editor, export, native encode.
  - `ShareService` → a recorder (the system share sheet can't be driven).
  - `saveToFiles` → recorder (the native folder picker can't be driven).
  - `PurchasesClient` (M8) → fake.
  - `Haptics` → recorder.
- **Fixtures** (`integration_test/fixtures/`): short (8–10 s) audio files
  made once with ffmpeg from a synthetic WAV (120 BPM, kick + hat clicks
  with fades over a soft pad, 44.1 kHz stereo; and a 48 kHz mono one):
  `.wav`, `.mp3` (LAME), `.m4a` (AAC-LC), `.aac` (ADTS), and a `.mp4`
  video (black frames + that audio). Store them as base64 strings in Dart
  files (`fixtures.g.dart`, generated by `tool/make_e2e_fixtures.dart`
  from the binary files) so they're part of the test code, **not** app
  assets — they must never ship in the app. Keep the ground-truth beat
  samples next to them.
- Waiting: native jobs take real time, so tests wait **for a condition**
  (a helper that pumps 100 ms frames until a finder/file exists, failing
  after a generous deadline), never for a fixed duration. Debounced saves
  are flushed by leaving the editor (cubit `close()`), not by waiting.
  This keeps them deterministic under load (fixed waits flaked in M2–M4).

#### A3.2 Flows

Each flow starts from a clean app documents directory.

| ID | Flow | Assertions (read back **on the device**) |
|---|---|---|
| I1 | Import WAV fixture → Analyzing → editor | `song.wav` header: same rate/channels/frames as the fixture; detected BPM 120 ± 1; beats within ±10 ms of ground truth; Home lists the project after going back |
| I2 | Import MP3, M4A, AAC, MP4-video fixtures | Native decode succeeds; rate and channels as encoded; frame count within the codec's priming/padding of the WAV fixture (state the measured difference per format — this is the first real data on decoder padding); BPM 120 ± 1; beat offsets vs ground truth constant within ±1 ms (a constant shift = decoder priming; record it) |
| I3 | Unsupported file (a `.txt` renamed `.mp3`) | Import error screen with the "unsupported" copy; no project folder left |
| I4 | Cancel during Analyzing | Back on Home; project folder deleted |
| I5 | Editor edits (needs M5) | Tap a marker, nudge +10 ms, delete another, undo, add at playhead, Bulk shift −20 ms; leave the editor; reopen → `project.json` beats equal the expected integer samples exactly |
| I6 | Export WAV pack (needs M6) | Files exist with the planned names; song file **byte-identical** to `song.wav`; guide and preview: rate, channels and **frame count equal** `song.wav`'s (from headers and data sizes); for every visible beat the guide's first non-zero sample is exactly the beat sample; silence elsewhere; share recorder received all paths |
| I7 | Export M4A pack | `probeMedia`: rate/channels match; decode both M4As back with the app's own `decodeToWav`; measure the song's offset vs `song.wav` (cross-correlation) and the guide's click offset vs the beats; **the two offsets are equal within 1 sample** (that's the sync that matters in CapCut/VN); record the absolute offset |
| I8 | Export with filter "every 2nd" and mono guide | Guide has 1 channel; clicks only on visible beats |
| I9 | Cancel export | Pack folder gone; a new export succeeds |
| I10 | Guide video (needs M7) | `probeMedia`: H.264, 30 fps, duration within 1 frame of the song, has audio; audio decodes to the guide track's frame count |
| I11 | First run (needs M8) | Fresh install shows onboarding; Skip → Home; second launch → Home; coach marks once |
| I12 | Quota (needs M8, fake purchases + injected clock) | 30 exports allowed, 31st shows the paywall prompt; fake `pro` → unlimited |
| I13 | Delete project | Folder gone; Home empty state |

Disk-full, DRM and cloud items can't be produced reliably on CI; they
stay in host tests (fakes) and Part B.

#### A3.3 Where they run

**Locally (Windows, Android only):** with P1 fixed and a device or
emulator connected:

```powershell
flutter devices
```

```powershell
flutter test integration_test -d <device-id>
```

iOS simulators need a Mac; use Codemagic.

**Codemagic:** add a separate workflow (manual trigger or nightly, not on
every push — it's slow). Commands below follow Codemagic's testing docs
(<https://docs.codemagic.io/yaml-testing/testing/>, updated 2026-06-26);
check the simulator device/runtime names with `xcrun simctl list` in a
first run.

```yaml
  e2e-ios:
    name: Integration tests (iOS simulator)
    instance_type: mac_mini_m2
    max_build_duration: 60
    environment:
      flutter: 3.47.2
      xcode: latest
    triggering:
      events: []        # start manually
    scripts:
      - name: Get packages
        script: flutter pub get
      - name: Boot simulator
        script: |
          xcrun simctl shutdown all
          TEST_DEVICE=$(xcrun simctl create test-device \
            com.apple.CoreSimulator.SimDeviceType.iPhone-16 \
            com.apple.CoreSimulator.SimRuntime.iOS-18-5)
          xcrun simctl boot $TEST_DEVICE
          echo "TEST_DEVICE=$TEST_DEVICE" >> $CM_ENV
      - name: Integration tests
        script: |
          mkdir -p test-results
          flutter -d $TEST_DEVICE test --machine integration_test \
            > test-results/flutter.json
        test_report: test-results/flutter.json
```

**Android on Codemagic:** Codemagic's docs state that Apple-silicon Macs
can't run Android emulators (no nested virtualization) and point to
third-party device services. Options, in order of preference:

1. Run the Android integration tests **locally** on a real device (P1, P5).
2. A Codemagic **Linux** instance with an emulator, if your plan includes
   Linux machines — the docs show
   `flutter emulators --launch emulator &`, `adb wait-for-device`,
   `flutter -d emulator-5554 test integration_test`, but don't say which
   instance types support it; confirm with a first run.
3. Firebase Test Lab or emulator.wtf from a Codemagic step (extra
   account; not set up).

#### A3.4 Prompt to build Part A (paste to an agent after M6 is merged)

> In the KickVolt repo (branch `main`), read `docs/handoff/E2E-testing.md`
> Part A, `CLAUDE.md` and `.ai/rules/*`. Create branch `e2e/integration-tests`.
> Add `integration_test` (SDK), the `bootstrap({overrides})` seam, the
> fixture generator and fixtures (§A3.1), and flows I1–I9 and I13 (the
> rest when M7/M8 are on `main`). Add the `e2e-ios` Codemagic workflow
> without changing the existing `ci` workflow. Don't change app behaviour
> beyond the seam. Waits are condition-based only. Run `dart format
> --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter
> test` (host suite still green); run the integration tests on any device
> you have and report exactly which ran where and which didn't. Push the
> branch; don't merge or open a PR. Report: commits, test results per
> device, the measured decoder offsets (I2) and M4A sync offsets (I7), and
> anything you couldn't run.

---

## Part B — Manual testing on physical devices

### B0. Device matrix

Use at least the first, third and fourth rows; all five before a release.

| Code | Device | OS | Why |
|---|---|---|---|
| D1 | Current iPhone (e.g. iPhone 16/17) | latest iOS | Main iOS target |
| D2 | iPhone 7 / SE (1st gen) / 6s kept on iOS 15 | iOS 15.x | Minimum iOS (`PLAN.md` §8.3); old AVFoundation, low RAM |
| D3 | Recent Pixel | latest Android | Reference Android, Media3/ExoPlayer, AAC/H.264 codecs |
| D4 | Low-end Android, 2–3 GB RAM | API 24–26 (Android 7.0–8.0) | Minimum SDK; slow CPU; old `MediaCodec` quirks; storage permission model ≤ 32 |
| D5 | Samsung Galaxy (A-series or S-series) | One UI, recent | Samsung audio stack and aggressive background killing |

Builds: test the **release** build for timings and memory
(`flutter build apk --release`, sideloaded; iOS via TestFlight), the
**profile** build for frame timing (`flutter run --profile`), and note the
exact build (commit SHA) in the results.

### B1. Import

| ID | Steps | Expected |
|---|---|---|
| B1.1 | Import an MP3 from Files | Analyzing shows decode progress then detection steps; editor opens with beats; duration matches the song |
| B1.2 | Same for M4A, AAC, WAV (16-bit and 24-bit), FLAC if you have one | All import; 24-bit WAV decodes to 16-bit; same duration as the file |
| B1.3 | Import an unsupported file (a PDF or text file) | Import error: unsupported; no project left on Home |
| B1.4 | iOS: Music library → an Apple Music (DRM) song | DRM error copy ("protected"); no crash; no project |
| B1.5 | iOS: Music library → a purchased song not downloaded to the phone | "Not downloaded" (cloud item) error copy |
| B1.6 | Import a video from the camera roll | Audio extracted; duration = video's audio |
| B1.7 | Video with no audio track | "No audio" error |
| B1.8 | Android: Music library with permission **denied** (deny the prompt; also "Don't ask again") | Clear message with a way to Settings; Files import still works |
| B1.9 | Android: grant the permission | Library list shows songs; import works; on API 24–32 the storage permission is asked instead of `READ_MEDIA_AUDIO` |
| B1.10 | Import a **10-minute** song (D2, D4 especially) | Completes; note decode + detection time and peak memory (Xcode Instruments / Android Studio profiler or `adb shell dumpsys meminfo com.kickvolt.app`); no crash/OOM |
| B1.11 | Cancel during decode, and again during detection | Back on Home; no half project; importing again works |
| B1.12 | Low disk: fill the phone until < ~100 MB free, import a long song | Disk-full error copy; no partial folder |
| B1.13 | Background the app during import, return after 30 s; also lock the screen | Import finishes or fails with a clear message; never a stuck spinner |
| B1.14 | Kill the app during import, reopen | Home has no broken project (or it's cleaned up) |

### B2. Playback and waveform

| ID | Steps | Expected |
|---|---|---|
| B2.1 | Play, pause, ±2 s, scrub by dragging | Audio follows; playhead never jumps backwards while playing |
| B2.2 | Speeds 0.5×, 0.75×, 1× while playing | Pitch preserved; playhead speed matches; no drift after 1 min (compare with a beat marker) |
| B2.3 | Pinch zoom from whole song to max; scroll at each level | Smooth; markers thin out when dense; time ruler readable |
| B2.4 | **60 fps:** `flutter run --profile` on D3 and D4, open DevTools › Performance, play at max and min zoom, pinch, scrub | UI and raster threads under 16 ms for > 95 % of frames; note worst frames per device |
| B2.5 | Headphones unplugged / Bluetooth disconnected while playing | Playback pauses |
| B2.6 | Phone call / Siri / alarm while playing | Pauses; resumes cleanly or stays paused |

### B3. Beat detection on real songs

For each: import, look at the Auto-detect result, play with Clicks on (M5)
and listen. Record BPM shown vs the song's known BPM, and "beats on the
beat?" Yes/Mostly/No.

| ID | Song type | Expected |
|---|---|---|
| B3.1 | Four-on-the-floor house/EDM, 120–128 BPM | BPM exact; clicks on every kick |
| B3.2 | Pop with a quiet intro | Intro may be sparse; beats lock once drums start |
| B3.3 | Half-time hip-hop / trap, 70–75 or 140–150 BPM | Either the half or double reading; note which; markers on the beat |
| B3.4 | Drum-and-bass 170–175 BPM | **Known limit:** reads ≈ 87; markers still on beats (every other) |
| B3.5 | Afrobeats / amapiano (syncopated) | Note result |
| B3.6 | Acoustic / no drums | Either reasonable beats or the "no steady beat" sheet |
| B3.7 | Tempo change / live recording | Note drift |
| B3.8 | Very loud master and a very quiet track | Same quality (detection is loudness-independent) |
| B3.9 | Filter: every / strong / drops / every 2nd / every 4th | Marker counts change; data unchanged when switching back |

### B4. Editing, tap-to-mark, latency, click preview (M5)

| ID | Steps | Expected |
|---|---|---|
| B4.1 | Select a marker, nudge ±1/±10 ms, change type, delete; undo/redo each | Each step undoes exactly; haptic on place/nudge, warning on delete |
| B4.2 | Long-press to add; Snap on/off | Added at the press (snapped if on) |
| B4.3 | Bulk: drag handles, Clear range, undo; Shift all −20 ms, undo | As described; undo restores exactly |
| B4.4 | Sections: split, rename, recolour, delete | Colours and names on the waveform |
| B4.5 | Latency calibration with the **built-in speaker** | ≥ 16 taps → a value (typically 20–120 ms); Save |
| B4.6 | Same with **wired** headphones (or USB-C/Lightning adapter) | Usually lower than speaker; saved as wired |
| B4.7 | Same with **Bluetooth** headphones | Warning shown before calibrating; value typically 150–300 ms |
| B4.8 | Switch output after calibrating (speaker → BT) | Tap panel shows the Bluetooth warning |
| B4.9 | Tap-to-mark at 1× along a song with clear beats, each output | Tapped markers land on the beat within ~±20 ms (check by zooming in) |
| B4.10 | Clicks on at **0.5× and 1×**, listen with wired headphones | Clicks sit exactly on the kicks at both speeds; no flam; "Updating clicks…" after an edit, then the new click is heard |
| B4.11 | Haptics off in Settings | No haptics anywhere |

### B5. The product goal: CapCut and VN (M6)

Do this for **each editor × each platform × WAV and M4A**, with two songs
(one 4-on-the-floor, one hip-hop). This is the test that matters most.

1. In KickVolt, export a pack (song + guide), Share › Save to Files (iOS)
   or Save to Files (Android) into a folder you can find.
2. **CapCut:** new project → import the song and the guide (audio) → place
   both at 0:00, guide under the song → select the guide → Beats → Auto
   generate. Mute the guide (volume 0).
3. **VN:** new project → + › Music › Yours › ⋮ › File App → import both as
   music → both at 0:00 → tap the guide → Beats → Auto Beats → ✓. Mute
   the guide.
4. Zoom into the timeline at several points (start, middle, end, around a
   drop). Play.

Expected:
- Every click becomes a beat marker; no missed or extra markers (count a
  few bars).
- Markers line up with the song's beats by ear and visually, at the
  start **and** at the end (no drift over the song).
- Guide and song have the same length in the editor.
- With M4A, note any constant offset compared with WAV (the sync warning
  says it can shift a few ms).
- Note whether the editor's auto-beat needs a sensitivity/frequency slider
  change to catch every click (VN has a frequency slider).
- Record CapCut/VN versions and the exact menu labels you saw (they feed
  the How-to copy; VN's labels were confirmed from its help pages, CapCut's
  only from the design).

| ID | Case | Expected |
|---|---|---|
| B5.1 | CapCut, iOS, WAV | As above |
| B5.2 | CapCut, iOS, M4A | As above; note offset |
| B5.3 | CapCut, Android, WAV | As above |
| B5.4 | CapCut, Android, M4A | As above |
| B5.5–B5.8 | VN, same four | As above |
| B5.9 | Preview mix in each editor | Clicks audible on the beat |
| B5.10 | Guide video (M7) in each editor, at 0:00 with the song | Flashes on the beats; numbers increase; same length as the song; cuts on flash frames line up with beats; its audio auto-beats like the guide |

### B6. Export, share, save (M6/M7)

| ID | Steps | Expected |
|---|---|---|
| B6.1 | Export WAV pack, each click style | Files named `<Title>_song.wav`, `<Title>_beats.wav`; click style audible in the guide. Listen to **Kick** on phone speaker and headphones: it's under one cycle of 60→40 Hz and may be a dull pop — note whether CapCut/VN still catch it |
| B6.2 | Title with emoji / slashes / very long | Safe file names; files open |
| B6.3 | Share → AirDrop / messaging app / CapCut / VN in the sheet | Files arrive intact (check duration) |
| B6.4 | Save to Files → pick a folder (iOS Files; Android folder picker incl. Downloads and an SD card if present) | All files there; open in another app |
| B6.5 | Background the app during export (home button), return after 10 s, 30 s, 2 min | Finishes, or ExportFailed "interrupted" with Try again — never stuck |
| B6.6 | Lock the screen during export | Same |
| B6.7 | Kill the app during export, reopen, export again | No leftover `.part`; new export works |
| B6.8 | Low disk during export (WAV of a long song) | Disk-full card with the MB estimate; "Switch to M4A and retry" works |
| B6.9 | Cancel during export | Back to options; no files |
| B6.10 | Export 4 times from one project | Only the last 3 packs kept (app storage doesn't keep growing) |
| B6.11 | Guide video (M7) on D2 and D4 | Encodes (or the clear fallback/error); note time for a 3-min song |

### B7. Onboarding, settings, paywall (M8)

| ID | Steps | Expected |
|---|---|---|
| B7.1 | Fresh install | Onboarding 1–3; Skip works; second launch goes to Home |
| B7.2 | Onboarding "Allow access" (iOS music, Android audio) / "Not now" | Prompts only for what's used; both paths reach Home |
| B7.3 | Coach marks on first editor open | 3 steps; Skip tips; don't return |
| B7.4 | How-to screens | CapCut and VN tabs; copy matches what you saw in B5 |
| B7.5 | Settings: change every default; kill and reopen | Persisted; next export uses them; no Theme row |
| B7.6 | Sandbox purchase (iOS sandbox tester; Android license tester via Play internal track) monthly and yearly | Prices from the store; purchase completes; Pro features unlock immediately; chip hidden/PRO |
| B7.7 | Cancel the purchase sheet | No error; still free |
| B7.8 | Restore purchases on a second device / after reinstall | Pro restored |
| B7.9 | Free tier: export 30 packs (or set N to 3 in a debug build) | 31st blocked with the reset date and Go Pro |
| B7.10 | Rollover: after 7 days (sandbox: change the device date forward 7 days, then back) | Exports available again exactly 7 days after the first; moving the clock back doesn't give extra exports |
| B7.11 | Airplane mode with and without Pro | App works; Pro remains (cached); free quota still counted |
| B7.12 | Subscription expiry (sandbox renewals are minutes long) | Pro ends on expiry; free tier resumes |

### B8. Accessibility and robustness

| ID | Steps | Expected |
|---|---|---|
| B8.1 | VoiceOver (iOS) / TalkBack (Android) through Home → import → editor → export | Every button has a label; you can export a pack without seeing the screen (the waveform itself may be limited — note what isn't reachable) |
| B8.2 | Largest text size / display size | No clipped or overlapping text on Home, Export, Settings, Paywall, onboarding |
| B8.3 | Haptics off (app setting) and system haptics off | No vibration |
| B8.4 | Rotate the phone | Stays portrait or lays out correctly |
| B8.5 | Split screen / Slide Over (iPad, Android multi-window) | No crash |
| B8.6 | 20+ projects on Home | Smooth scrolling; delete/rename work |
| B8.7 | Update install over the previous build | Projects survive; settings survive |

### B9. Results template

Copy this table into `docs/testing/results-<date>.md` (one file per test
session) and fill it in. Result: **Pass**, **Fail**, **Partial**, **Blocked**
(couldn't run), **N/A**.

```markdown
# Test session <YYYY-MM-DD>

Tester: <name> · App commit: <sha> · Build: <debug|profile|release, how installed>
CapCut version: <x> · VN version: <x>

| Device | OS | Build | Case | Result | Notes (numbers, what you saw, screenshot/video link) |
|---|---|---|---|---|---|
| D3 Pixel 8 | Android 16 | release a1b2c3d | B1.1 | Pass | 3:12 MP3, decode 2.1 s, detection 4.0 s |
| D3 Pixel 8 | Android 16 | release a1b2c3d | B3.4 | Partial | DnB 174 → 87 BPM (known limit), markers on beats |
|  |  |  |  |  |  |
```

For every **Fail**, add: steps to reproduce, expected vs actual, and
`adb logcat` / Xcode console output if you can get it. Paste the table
back into the conversation; failures become fixes on the next branch.

---

## Sources

- Codemagic, Running tests (integration tests on simulators/emulators,
  Apple-silicon emulator limit): <https://docs.codemagic.io/yaml-testing/testing/>
- RevenueCat sandbox testing: Apple <https://www.revenuecat.com/docs/test-and-launch/sandbox/apple-app-store>,
  Google Play <https://www.revenuecat.com/docs/test-and-launch/sandbox/google-play-store>,
  Test Store <https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store>
- VN help: add beats <https://vlognow.me/help/beats-clips/add-beats/>,
  import music <https://vlognow.me/help/getting-started/import-music/>
  (both updated 2026-09-20)
