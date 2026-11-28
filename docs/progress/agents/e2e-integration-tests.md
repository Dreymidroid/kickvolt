# Agent log — E2E integration tests on the device

- **Branch:** `e2e/integration-tests` (from `main` after M8 is merged), own git worktree.
- **Spec:** `docs/handoff/E2E-testing.md` Part A (§A3), flows I1–I9, I11, I13
  (I10/I12 once M7 is merged; I12 needs a 174 BPM fixture).
- **Device:** Xiaomi 23106RN0DA, Android 14 (API 34), Wi-Fi ADB
  `192.168.100.8:5000`. This is the first time the Kotlin decode/encode
  code runs.
- **Deliverables:** integration tests + bootstrap seam + fixtures, per-flow
  results on the device, measured decoder offsets (I2) and M4A sync
  offsets (I7), fixes for any native bugs found (each one a separate commit
  with a regression test where possible).

## Activity

<!-- The agent appends dated entries below: what it did, commands, results, open issues. -->

### 2026-11-27 19:40 — setup (branch `e2e/integration-tests`)

- Worktree was on `main` (6fa6af5); created `e2e/integration-tests` from
  `m8/onboarding-settings` (dd441d4: M1–M6, M4b, M8).
- `adb devices` → `192.168.100.8:5000	device`.
- **Gradle 9.3.1 not available.** Another process holds
  `~/.gradle/wrapper/dists/gradle-9.3.1-all/.../gradle-9.3.1-all.zip.lck` and
  the `.part` was at ~9 MB of ~220 MB. Measured link speed:
  `curl -r 0-2000000 … gradle-9.3.1-all.zip` → `speed=22368 B/s` (≈3 h for
  the zip, plus AGP 9.1.0 / Kotlin 2.4.0 artifacts, none cached).
  Workaround, **local only, never committed**: build with the toolchain that
  is fully cached on this machine — Gradle 8.14.2, AGP 8.11.1, Kotlin 2.2.20
  (`android/settings.gradle.kts`, `gradle-wrapper.properties`). The Kotlin
  sources and MediaCodec behaviour don't depend on the build-tool version;
  this only affects how the APK is assembled. Trial:
  `flutter build apk --debug` → `BUILD SUCCESSFUL in 6m 5s`,
  `√ Built build\app\outputs\flutter-apk\app-debug.apk`. No Kotlin warnings
  from `com.kickvolt.app` sources. **The committed build files still say
  AGP 9.1.0 / Kotlin 2.4.0 / Gradle 9.3.1; that combination is still
  unbuilt locally.**

### 2026-11-27 19:50 — test code

- `lib/app/bootstrap.dart`: `bootstrap({overrides})`; `main()` is now
  `await bootstrap(); runApp(const KickVoltApp());` (same steps as before).
- `integration_test/support/`: `fixture_audio.dart` (synthetic 120 BPM
  kick + 8th-note hats over a soft pad, generated in Dart at test time, exact
  ground-truth beat samples), `signal.dart` (WAV reader, FFT
  cross-correlation lag), `mp4_to_adts.dart` (rewraps the device-encoded
  M4A's AAC frames as ADTS), `fakes.dart` (fixture picker, share/save/haptics
  recorders), `app_harness.dart` (launch via `bootstrap`, condition-based
  `pumpUntil`, clean docs dir + prefs per flow).
- Host check of the fixtures: `flutter test test/integration_test_support/fixture_audio_test.dart`
  ```
  FIXTURE 44100/2: bpm=120.0 beats=19 truth=19 worst=0.32 ms
  FIXTURE 48000/1: bpm=120.0 beats=19 truth=19 worst=0.27 ms
  00:01 +3: All tests passed!
  ```

### 2026-11-27 20:00 — first device runs

- First `flutter test integration_test/app_test.dart -d 192.168.100.8:5000 --plain-name "I1"`:
  `adb.exe: failed to install …app-debug.apk: Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]`
  (MIUI per-install confirmation, `persist.security.adbinstall=1`). Waited
  until the phone was idle; `adb install -r` then printed `Success`. The
  agent did not tap anything on the phone.
- I1 run (`--plain-name I1` also matched I11–I13):
  ```
  E2E_RESULT | I1 fx_44k_stereo | frames=441000 pcmIdentical=true bpm=120.0 beats=19/19 worst=0.32ms importTotal=7077ms decode=525ms analyze=595ms
  A RenderFlex overflowed by 4.0 pixels on the right.
    Row:file:///…/lib/features/beat_editor/presentation/widgets/editor_controls.dart:96:14
  ```
  **Bug 1 (app):** transport row needs 332 px, a 360 dp phone gives 328.
  Fix `82a2a5d` (Flexible speed control) + host regression test
  `test/features/beat_editor/presentation/editor_narrow_screen_test.dart`
  (without the fix: `Expected: <= 328.0  Actual: <332.0>`; with it:
  `00:04 +2: All tests passed!`).
- Full run (with the fix in the tree), tail:
  ```
  E2E_RESULT | I1 fx_44k_stereo | frames=441000 pcmIdentical=true bpm=120.0 beats=19/19 worst=0.32ms importTotal=7866ms decode=611ms analyze=653ms
  E2E_RESULT | I1 fx_48k_mono | frames=480000 pcmIdentical=true bpm=120.0 beats=19/19 worst=0.27ms importTotal=3006ms decode=432ms analyze=447ms
  E2E_RESULT | I2 m4a fx_44k_stereo | encoded=443390f/10054200us decodedFrames=443392 fixtureFrames=441000 frameDiff=2392 xcorrLag=lag=2048 (2048.00) r=0.9898 bpm=120.0 beats=19/19 beatOffset mean=2037.4f (46.20ms) min=2034 max=2045 spread=0.25ms importTotal=4926ms
  E2E_RESULT | I2 m4a fx_48k_mono | encoded=482304f/10048000us decodedFrames=482304 fixtureFrames=480000 frameDiff=2304 xcorrLag=lag=2048 (2048.00) r=0.9902 bpm=120.0 beats=19/19 beatOffset mean=2038.4f (42.47ms) min=2034 max=2046 spread=0.25ms importTotal=4172ms
  E2E_RESULT | I2 aac fx_44k_stereo | … frameDiff=2392 xcorrLag=lag=2048 … spread=0.25ms
  E2E_RESULT | I2 aac fx_48k_mono | … frameDiff=2304 xcorrLag=lag=2048 … spread=0.25ms
  02:38 +6 -1: I3 unsupported file (.txt renamed .mp3) [E]   (Timed out after 90 s waiting for "Can’t open this file")
  E2E_RESULT | I4 | dirsWhileAnalyzing=1 dirsAfter=0
  02:48 +7 -2: I5 editor edits persist to project.json [E]   (Found 0 widgets with Semantics("Nudge right 10 milliseconds"))
  E2E_RESULT | I6 | files=[fx_wav_pack_beats.wav, fx_wav_pack_song.wav, fx_wav_pack_preview.wav] clicks=19 frames=441000 songByteIdentical=true export=1230ms
  E2E_RESULT | I7 fx_m4a_44k | … songLag=lag=2048 (2048.00) r=0.9898 guideLag=lag=2048 (2048.00) r=0.7499 syncDiff=0 export=10260ms
  E2E_RESULT | I7 fx_m4a_48k | … songLag=lag=2048 (2048.00) r=0.9902 guideLag=lag=2048 (2048.00) r=0.6377 syncDiff=0 export=11714ms
  03:37 +10 -3: I8 export with every-2nd filter and mono guide [E]   (pageBack: no CupertinoNavigationBarBackButton)
  E2E_RESULT | I9 | cancel removed folder; re-export files=3
  E2E_RESULT | I11 | onboarding→Skip→Home; relaunch→Home; coach marks once
  E2E_RESULT | I12 | firstBpm=174.0 usedDouble=false finalBpm=174.0 beats=34/34 worst=0.32ms
  05:48 +13 -4: I13 delete project [E]   (Timed out waiting for "Delete "fx_delete"?")
  05:50 +13 -4: Some tests failed.
  ```
  The four failures are test-harness issues (taps during sheet animations,
  a wait returning before a frame, `pageBack` on a screen without an
  AppBar). Fixed in `8bf0f72`.
- **Finding (not fixed):** Android's AAC decode path keeps the 2048-sample
  encoder priming (46.4 ms @ 44.1 kHz, 42.7 ms @ 48 kHz) for both M4A and
  ADTS. `WavDecoder` never reads `KEY_ENCODER_DELAY`/`KEY_ENCODER_PADDING`.
  Harmless inside a pack (I7 sync diff 0) but worth handling for imported
  third-party M4As; needs a device run to verify any change.

### 2026-11-27 20:25 — lead update, toolchain reverted, rebase

- Lead: M8 merged (`7578067`), rebase onto `origin/main`; Gradle 9.3.1 is
  re-downloading (~0.8 MB/min); **don't switch Gradle/AGP versions.**
  Reverted the local AGP 8.11.1 / Gradle 8.14.2 override
  (`git checkout -- android/settings.gradle.kts android/gradle/wrapper/gradle-wrapper.properties`).
  All device numbers above were taken with that local toolchain before the
  instruction arrived. `.part` at 20:33: 52 896 037 bytes.
- `git rebase origin/main` → `Successfully rebased and updated refs/heads/e2e/integration-tests.`
- I3, I5, I8, I13 not re-run after the harness fix: waiting for Gradle 9.3.1.

### 2026-11-28 — lead correction, re-runs, I10

- Lead allowed the local-only toolchain override for device runs (Gradle
  9.3.1 download keeps truncating). Re-applied before each run and
  `git checkout -- android/settings.gradle.kts android/gradle/wrapper/gradle-wrapper.properties`
  before each commit. Regenerated linux/macos/windows registrants were
  line-ending noise only (`git diff` empty) → checked out, not committed.
- ADB had dropped (`cannot connect to 192.168.100.8:5000 … (10060)`);
  retried `adb connect` until `connected`. One install hit
  `INSTALL_FAILED_USER_RESTRICTED` again; `adb install -r` → `Success`.
- Run 2 (harness fix `8bf0f72`): I5, I8, I13 pass; I3 still fails, now with
  the screen dump:
  `Texts on screen: [, 100%, Finding your beats…, …, Cancel]`.
  **Bug 2 (app):** failed/cancelled import stuck on Analyzing at 100 % —
  listener `maybePop` refused by a stale `PopScope(canPop: false)`.
  Host regression test (real AppRouter) failed without the fix
  (`Found 1 widget with type "AnalyzingView"`), passes with it
  (`00:02 +2: All tests passed!`). Fix `593ad38`.
- Rebased onto `origin/main` fda51b5 (M7 merged). `SaveRecordingAudioNative`
  forwards `encodeGuideVideo`. Added I10 (probe + audio decode + cancel
  mid-encode). Video frames can't be decoded with the app's APIs, so flash
  frames are not checked pixel-wise.
- Run 3 (build `86b3b1f`), tail:
  ```
  E2E_RESULT | I3 | error dialog shown, projectDirs=[]
  E2E_RESULT | I5 | beats=20 persisted exactly; shift=-882
  E2E_RESULT | I8 | beats=19 visible=9 hidden=10 guideChannels=1
  E2E_RESULT | I10 | hasVideo=true 720x1280 videoFrames=300/300 videoUs=10000000 songUs=10000000 diffUs=0 audio=44100/2 guide=44100/2 flashes=19 decodedAudio=443392f guideFrames=441000f audioLag=lag=2048 (2048.00) r=0.7499 bytes=864639 export=9733ms
  E2E_RESULT | I10 cancel | cancelled mid-video; no pack folder left
  E2E_RESULT | I13 | folder gone, empty state shown
  03:32 +19: All tests passed!
  ```
  Full per-flow numbers: `docs/testing/results-2026-11-27.md`.
- AAC priming (+2048 samples) kept as a documented known issue per lead.
- Host checks on `86b3b1f` + docs:
  `dart format --output=none --set-exit-if-changed lib test integration_test` → `Formatted 233 files (0 changed)`;
  `flutter analyze` → `No issues found! (ran in 45.5s)`;
  `flutter test -j 2 --timeout 120s` → `01:59 +476: All tests passed!`
