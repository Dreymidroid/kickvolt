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
