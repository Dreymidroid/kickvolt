# Handoff: M8 — Onboarding, how-to, settings (no paywall yet)

Self-contained brief for an agent implementing milestone M8 of KickVolt.
Part 1 is the prompt to paste. Parts 2–11 are the spec. Verification
against §10 happens afterwards, in a separate session.

**No payments in M8 (decided 2026-11-26).** Payments come much later. M8
ships **no paywall, no RevenueCat, no export limit and no "Pro" in the
UI**. Everything is free. The `EntitlementService` from M6 stays the one
place that would gate features, still returning "everything allowed", so
payments can be added later without touching features. What's known about
RevenueCat is kept in the appendix for that later milestone.

(The file keeps its name so existing links work.)

**Preconditions:** M6 is verified and merged into `main`. M7 and M4b are
merged too, or deferred by the user: if M7 isn't on `main`, the guide
video stays "Coming soon"; if M4b isn't, there's nothing extra here.

**Decisions to settle with the user before pasting** (defaults are what
the brief says if nobody changes them):

| # | Question | Default |
|---|---|---|
| D1 | Release readiness (app icon, launch screen, Android release signing, iOS signing in Codemagic, `PrivacyInfo.xcprivacy`, store listings): in M8 or a separate step? | **Separate step** (§7). |
| D2 | Feedback email and privacy-policy URL. | Placeholders in `AppConstants`; the user fills them in before release. |

---

## 1. Prompt (paste this to the agent)

> You are implementing milestone **M8 (Onboarding, how-to, settings)** of
> KickVolt, a Flutter app in the current repository
> (`https://github.com/Dreymidroid/kickvolt`, branch `main`).
>
> Before writing any code, read these in full:
> 1. `docs/handoff/M8-onboarding-settings-paywall.md` (this brief — it is
>    the spec; note: **no paywall and no payments**)
> 2. `CLAUDE.md`, `.ai/rules/structure.md`, `.ai/rules/state_management.md`
>    (project rules; they override your defaults)
> 3. `PLAN.md`, especially §6 "M8", §8 (decisions: dark only, app ID) and
>    §9 (what has been built)
> 4. `design/kickvolt-design/HANDOFF.md` and the screens `Main`,
>    `Onboarding2`, `Onboarding3`, `Coach1`–`Coach3`, `HowToCapCut`,
>    `HowToVN`, `Settings`, `Home` (`png/` = visual truth,
>    `screens/*.html` = exact copy and sizes). Ignore `Paywall`.
> 5. The code listed in §3 of the brief.
>
> Then:
> - Check that `main` contains M6 (`lib/core/entitlements/`). If not, stop
>   and say so.
> - Create a branch `m8/onboarding-settings` from `main`.
> - Implement §4–§6. Do **not** do anything in §9 (out of scope) — in
>   particular no paywall, no purchase SDK, no export counting, no "Pro"
>   labels.
> - The only new package allowed is `url_launcher` (§5). Confirm every API
>   you call in your pub cache before using it.
> - Write the pure-Dart tests in §8 **first** (first-run state, settings
>   mapping), then make them pass. Then cubit and widget tests.
> - Before you finish, run, in this order:
>   `dart run build_runner build --delete-conflicting-outputs`,
>   `dart format .`, `flutter analyze`, `flutter test`. All must be
>   clean/green. Run `flutter test` at least twice.
> - Commit in small logical commits (end each message with your usual
>   co-author line), push the branch, and **do not merge** or open a PR.
> - Finish with the report in §11.
>
> If the brief is ambiguous, pick the simplest option that matches the
> designs and keeps every feature free; note the decision in your report
> and carry on. Do not loosen a test tolerance to make it pass; if a check
> can't be met, say so in the report. Report honestly what you could not
> compile or run.

---

## 2. Context

KickVolt: import a song, mark beats, export a beat pack (song + click
guide track, optional preview mix and guide video) for CapCut/VN. M1–M7
built the pipeline (see `PLAN.md` §9). M8 adds what a first-time user
needs:

- First-run onboarding (3 screens) and coach marks (3 overlays) in the
  editor.
- How-to screens for CapCut and VN.
- The Settings screen (export defaults, haptics, latency calibration, help).
- Removing the leftover Pro/limit hints (Home "free left" chip, PRO
  badges).

Environment notes:
- Windows dev machine; no device; local Android build broken; iOS only on
  Codemagic. Widget tests are the acceptance bar.
- Material from `package:material_ui/material_ui.dart`; theme `context.kv`,
  `KvText`; reuse `lib/shared/` widgets.
- **Dark theme only** (`PLAN.md` §8.7): the Settings design's Theme row is
  dropped.

## 3. Existing code you'll touch

| Path | What it is today |
|---|---|
| `lib/core/entitlements/entitlement_service.dart` (M6) | Interface + `UnlimitedEntitlementService` stub (everything allowed, quota unlimited). **Leave as is.** Export already hides its quota caption for an unlimited quota. |
| `lib/features/export/` (M6/M7) | Export screen; check no "PRO" badge or limit copy is visible with the stub. |
| `lib/features/settings/` (M5/M6) | `AppSettings` (latency, haptics, `defaultClickStyle`, `defaultAudioFormat`, `includePreviewByDefault`, `monoGuideTrack`, `includeVideoByDefault`), `SettingsRepository`, `LatencyCalibrationRoute`. |
| `lib/core/haptics/haptics.dart` (M5) | Reads `hapticsEnabled`. |
| `lib/features/projects/presentation/pages/home_screen.dart` | "30 free left" chip (static, ~line 450), "How beat packs work" button (~line 361, does nothing), Settings icon (~line 462, "Settings screen arrives in M8"). |
| `lib/features/projects/data/repositories/project_repository.dart` | New projects get `DetectionSettings()` (sensitivity `0.5`). M8's default-sensitivity setting feeds this. |
| `lib/features/beat_editor/presentation/` | Editor screen; coach marks overlay it on first open. |
| `lib/app/app_router.dart`, `app_constants.dart` | Routes (Home is initial); `freeExportsPerWeek = 30` (unused until payments). |
| `pigeons/audio_api.dart`, `AudioHostApiImpl.*`, `MainActivity.kt` | `listMusicLibrary` asks for the Android audio permission (M1), routed through `MainActivity`. |
| `ios/Runner/Info.plist` | Has `NSAppleMusicUsageDescription`, `NSPhotoLibraryUsageDescription`. |

## 4. Onboarding, coach marks, how-to

### 4.1 First run

- `AppSettings.onboardingDone` (bool, default false) and
  `coachMarksDone` (bool, default false).
- App start: if `!onboardingDone`, the initial route is Onboarding; else
  Home. Decide at startup before the first frame (no Home flash). Use an
  auto_route guard or a redirect, not a manual push in `initState`.

### 4.2 Screens (`Main`, `Onboarding2`, `Onboarding3`)

- Main: the problem ("Editor auto-beat" guessed/missed vs "Marked in
  KickVolt" illustration — a static `CustomPainter`), copy from
  `Main.html`, **Next**, **Skip**.
- Onboarding2: the beat pack (Song / Guide / Video illustration) and the
  three steps, copy from `Onboarding2.html`. **Drop the "PRO" badge** on
  Video; if M7 isn't on `main`, show only Song and Guide.
- Onboarding3: permissions. Ask only for what the app actually uses:
  - **Android:** the audio permission (`READ_MEDIA_AUDIO` on API 33+,
    `READ_EXTERNAL_STORAGE` on ≤ 32), through the existing native
    permission path (add a Pigeon method `requestAudioPermission()` that
    reuses M1's `MainActivity` permission routing; don't add
    `permission_handler`). Regenerate Pigeon and `dart format` the
    generated Dart file (CI diffs it).
  - **iOS:** the music library (`MPMediaLibrary.requestAuthorization`)
    via the same Pigeon method. Files needs no permission.
  - **Photos & videos (optional):** `image_picker` uses PHPicker on iOS 14+
    and the Android photo picker, which need no permission. Keep the row
    as information ("Optional") with no prompt. Say so in the report.
  - "Allow access" → request → Home. "Not now" → Home. Either sets
    `onboardingDone`. A denied permission is fine: Files import still
    works, and the library sheet already shows the denied error (M1).
- Skip on any page → Home with `onboardingDone = true`.

### 4.3 Coach marks (`Coach1`–`Coach3`)

On the first editor open with `coachMarksDone == false`: a dimmed overlay
with a highlighted cut-out and a card ("1 of 3 Your beats live here…",
"2 of 3 Pick how you mark…", "3 of 3 Export when it looks right…"),
**Skip tips** / **Next** / **Got it**. Cut-outs track the real widgets
(waveform, tool tabs, Export pill) via `GlobalKey`s and their render
boxes. Done or skipped → `coachMarksDone = true`. No new package; a
`Stack` + `CustomPainter` overlay is enough.

### 4.4 How-to (`HowToCapCut`, `HowToVN`)

One route `HowToRoute(initialTab)` with CapCut / VN tabs, four numbered
steps each, copy from the HTML, plus the "Beats a little early or late?
… Bulk › Shift all beats" tip. Reached from Home ("How beat packs work"),
ExportSuccess ("How to use it in CapCut and VN") and Settings (Help).

Copy corrections (research 2026-11-26):

- **CapCut step 3:** keep the design's "open **Beats**, turn on **Auto
  generate**" (from the design; not verifiable from CapCut's public help —
  checked during the device test, `E2E-testing.md` B5).
- **VN step 3:** the design's "open Beat and choose auto-detect" is wrong.
  VN's help (updated 2026-09-20,
  <https://vlognow.me/help/beats-clips/add-beats/>) says: tap the music
  track, select **Beats**, tap **Auto Beats**, adjust the slider, tap
  **Confirm**. Use: "Tap the guide track, open **Beats** and tap **Auto
  Beats**. Then tap ✓. Every click becomes a beat point."
- **VN step 1:** VN documents beats on **music** tracks. Its import path
  for your own audio is **+ › Music › Yours › ⋮ › File App**
  (<https://vlognow.me/help/getting-started/import-music/>). Step 1 copy:
  "Add the song and the guide track as music: Music › Yours › ⋮ › File
  App."
- **"Open CapCut" / "Open VN" buttons:** neither app documents a URL
  scheme or file hand-off (see `docs/handoff/M6-export.md` §6.2). Drop the
  buttons.

### 4.5 Home

- **Remove the "30 free left" chip** (no limit exists yet).
- "How beat packs work" → `HowToRoute`. Gear → `SettingsRoute`.

## 5. Settings (`Settings.png`, minus Pro banner and Theme)

Route `SettingsRoute` from Home's gear icon. Add `url_launcher: ^6.3.3`
(latest on pub.dev, 2026-10-02, <https://pub.dev/packages/url_launcher>)
for the feedback mail and privacy link.

- **No "Get KickVolt Pro" banner.**
- **Export defaults:** Click sound (Snap/Rim/Blip/Kick), Audio format
  (WAV/M4A), Video format (MP4, read-only row; only if M7 is on `main`),
  "Mono guide track (smaller file)" toggle, Preview mix in packs (toggle),
  Guide video in packs (toggle; only with M7), Detection sensitivity
  (Low / Balanced / High → 0.25 / 0.5 / 0.75, used for **new** projects'
  `DetectionSettings.sensitivity`). Each row opens a small picker sheet or
  toggles in place.
- **Feel:** Haptics switch (`hapticsEnabled`); "Tap timing (lag fix)" row
  showing the current offset → `LatencyCalibrationRoute`.
- **Help:** How to use a beat pack → `HowToRoute`; Send feedback →
  `mailto:` with `AppConstants.feedbackEmail` (placeholder, D2); Privacy
  → `AppConstants.privacyUrl` (placeholder); About → "KickVolt v<version>"
  (version from a constant kept equal to `pubspec.yaml`'s `version`, with
  a test that reads `pubspec.yaml` and compares — no `package_info_plus`).
- **No Theme row.**
- `SettingsCubit` over `SettingsRepository`; every change saved
  immediately.

## 6. Pro leftovers

Search the UI for "PRO", "Pro", "free left", "free exports" and the
paywall route. None may be visible with the stub service. Keep the
`EntitlementService` calls in Export (`canExport`, `recordExport`) — they
cost nothing and are where payments plug in later. Don't delete
`AppConstants.freeExportsPerWeek`.

## 7. Release readiness (not built in M8 — D1)

List in the report what's still missing for a store release, so the user
can schedule it: app icon and launch screen (still Flutter defaults),
Android release signing (release builds use the debug key —
`android/app/build.gradle.kts`), iOS signing and TestFlight upload in
Codemagic, `ios/Runner/PrivacyInfo.xcprivacy` (the app and its plugins
use required-reason APIs such as `UserDefaults` via `shared_preferences`
and file timestamps), App Store / Play listings and privacy labels, a real
privacy-policy URL.

## 8. Tests required

Deterministic only: no real-time waits; inject clocks; `fakeAsync`.

| Test | Must cover |
|---|---|
| Settings repository + `settings_cubit_test.dart` | New keys' defaults and round trips; sensitivity mapping; each toggle persists; new projects take the default sensitivity. |
| First run | Router decides Onboarding vs Home from `onboardingDone` before the first frame; Skip / Allow / Not now all set it; coach marks shown once, Skip sets `coachMarksDone`. |
| Widget tests | Onboarding flow (3 pages, Skip, no PRO badge); Coach marks (3 steps, Skip tips); How-to tabs and VN copy (assert the "Auto Beats" text, no Open-app buttons); Settings rows (no Theme row, no Pro banner) open the right sheets/routes; Home has no "free left" chip and its buttons route correctly. |
| No-Pro guard | A widget test pumping Home, Export, Settings and onboarding finds no "PRO"/"Pro"/"free left" text. |
| Version test | About version constant == `pubspec.yaml` `version`. |
| Pigeon | `requestAudioPermission` mapped; generated file formatted. |

## 9. Out of scope (do not build)

- **Paywall, RevenueCat (`purchases_flutter`, `purchases_ui_flutter`),
  export counting, Pro labels, restore purchases** — later milestone.
- Release readiness items in §7 unless the user moved them in (D1).
- Theme switch / light theme.
- Opening CapCut/VN.
- `permission_handler`, `package_info_plus`, any package except
  `url_launcher`.

## 10. Acceptance checklist (used for verification)

```powershell
dart run build_runner build --delete-conflicting-outputs
dart run pigeon --input pigeons/audio_api.dart
dart format lib/core/audio_native/audio_api.g.dart
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

- [ ] All §8 tests pass on two consecutive full runs; no real-time waits.
- [ ] Onboarding on first run only; permission requests limited to §4.2.
- [ ] Coach marks once; How-to with corrected VN copy; no Open-app buttons.
- [ ] Settings per §5 — no Theme row, no Pro banner; every setting
      persisted and used.
- [ ] No paywall, no purchase SDK, no export limit, no visible "Pro"
      anywhere; `EntitlementService` stub untouched.
- [ ] Only `url_launcher` added.
- [ ] Branch `m8/onboarding-settings` pushed; not merged; no PR.

## 11. Report to hand back

1. Branch name and `git log --oneline main..HEAD`.
2. Tails of `flutter analyze` and both `flutter test` runs.
3. Every `url_launcher` API used, with file and line in the pub cache;
   native APIs used for the permission request with doc links.
4. File-level summary: new, changed, deleted.
5. Decisions where the brief was ambiguous (permission flow, coach-mark
   layout, etc.).
6. Placeholders the user must fill (feedback email, privacy URL).
7. The release-readiness list (§7) as it stands.
8. What you could not compile, run or verify — say plainly that nothing
   ran on a device and the native permission code is uncompiled.

---

## Appendix — payments (later milestone, do not build in M8)

Research from 2026-11-26, kept for when payments are scheduled:

- Packages: `purchases_flutter` 11.0.4 and `purchases_ui_flutter` 11.0.4
  (2026-11-18). RevenueCat's ready-made paywalls need iOS 15+ / Android
  API 24+ and `MainActivity` extending `FlutterFragmentActivity`
  (<https://www.revenuecat.com/docs/tools/paywalls/installation>); a custom
  Flutter screen per `Paywall.png` needs only `purchases_flutter`.
- Plan: replace `UnlimitedEntitlementService` with a RevenueCat-backed
  service behind a thin `PurchasesClient` interface; entitlement `pro`;
  offering `default` with `$rc_monthly` / `$rc_annual`; free tier
  `AppConstants.freeExportsPerWeek` (30) per rolling 7 days, one pack = one
  export, clock injected and clock-change safe; prices from the offering,
  never hard-coded; Terms/Privacy links on the paywall.
- Keys: `--dart-define` (or a git-ignored `--dart-define-from-file`
  JSON), never in the repo; a build without keys runs as free tier.
- Sandbox testing: App Store Connect sandbox testers; a StoreKit
  configuration file only applies when launched from Xcode, not
  `flutter run`
  (<https://www.revenuecat.com/docs/test-and-launch/sandbox/apple-app-store>);
  Play license testers + internal testing track, installed from the Play
  link (sideloaded builds can't buy)
  (<https://www.revenuecat.com/docs/test-and-launch/sandbox/google-play-store>);
  RevenueCat Test Store for UI work only, never in a store build
  (<https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store>).
- Design copy: "Unlimited exports — Free: 30 a week" (`PLAN.md` §8.6).
