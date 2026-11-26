# Handoff: M8 — Onboarding, how-to, settings, paywall

Self-contained brief for an agent implementing milestone M8 of KickVolt.
Part 1 is the prompt to paste. Parts 2–11 are the spec. Verification
against §10 happens afterwards, in a separate session.

**Preconditions:** M6 is verified and merged into `main` (M8 replaces its
stub `EntitlementService` and edits its export defaults). M7 is merged
too, or explicitly deferred by the user; if M7 isn't on `main`, the guide
video row stays "Coming soon" and the paywall doesn't list it as live (§6.4).

**Decisions to settle with the user before pasting** (defaults below are
what the brief says if nobody changes them):

| # | Question | Default in this brief |
|---|---|---|
| D1 | "Advanced detection" is a Pro row in the design but no such feature exists. | Hide that row on the Paywall and Settings banner; keep `hasAdvancedDetection` in the service, gating nothing. |
| D2 | Paywall: custom Flutter screen per `Paywall.png` (`purchases_flutter` only) or RevenueCat's dashboard-built paywall (`purchases_ui_flutter`, needs `FlutterFragmentActivity`). | Custom screen; no `purchases_ui_flutter`. |
| D3 | Release readiness (app icon, launch screen, Android release signing, iOS signing in Codemagic, `PrivacyInfo.xcprivacy`, store listings). | **Not in M8**; a separate release step (§9). |
| D4 | Terms, privacy policy and feedback addresses. | Placeholders in `AppConstants`; the user fills them in before release. |
| D5 | Product IDs and prices. | User creates them in App Store Connect / Play Console / RevenueCat (§6.2); code reads the RevenueCat offering, never hard-codes prices. |

---

## 1. Prompt (paste this to the agent)

> You are implementing milestone **M8 (Onboarding, how-to, settings,
> paywall)** of KickVolt, a Flutter app in the current repository
> (`https://github.com/Dreymidroid/kickvolt`, branch `main`).
>
> Before writing any code, read these in full:
> 1. `docs/handoff/M8-onboarding-settings-paywall.md` (this brief — it is
>    the spec, including the decision table at the top)
> 2. `CLAUDE.md`, `.ai/rules/structure.md`, `.ai/rules/state_management.md`
>    (project rules; they override your defaults)
> 3. `PLAN.md`, especially §6 "M8", §8 (decisions: dark only, 30 exports
>    per rolling 7 days, app ID) and §9 (what M1–M7 built)
> 4. `design/kickvolt-design/HANDOFF.md` and the screens `Main`,
>    `Onboarding2`, `Onboarding3`, `Coach1`–`Coach3`, `HowToCapCut`,
>    `HowToVN`, `Settings`, `Paywall`, `Home` (`png/` = visual truth,
>    `screens/*.html` = exact copy and sizes)
> 5. The code listed in §3 of the brief.
>
> Then:
> - Check that `main` contains M6 (`lib/core/entitlements/`). If not, stop
>   and say so.
> - Create a branch `m8/onboarding-paywall` from `main`.
> - Implement §4–§7. Do **not** do anything in §9 (out of scope).
> - New packages allowed: `purchases_flutter` and `url_launcher` only
>   (§6.1). Confirm every API you call in your pub cache before using it;
>   RevenueCat's API changed across major versions, so don't write it from
>   memory.
> - **No API keys in the repo.** RevenueCat keys come from
>   `--dart-define` (§6.3). Don't commit a real key, even a test one.
> - Write the pure-Dart tests in §8 **first** (export quota, entitlement
>   mapping, first-run state), then make them pass. Then cubit and widget
>   tests.
> - Before you finish, run, in this order:
>   `dart run build_runner build --delete-conflicting-outputs`,
>   `dart format .`, `flutter analyze`, `flutter test`. All must be
>   clean/green. Run `flutter test` at least twice.
> - Commit in small logical commits (end each message with your usual
>   co-author line), push the branch, and **do not merge** or open a PR.
> - Finish with the report in §11.
>
> If the brief is ambiguous, pick the option that keeps all "is this
> allowed?" logic inside `EntitlementService` and never blocks a user who
> has paid; note the decision in your report and carry on. Do not loosen a
> test tolerance to make it pass; if a check can't be met, say so in the
> report. Report honestly what you could not compile or run.

---

## 2. Context

KickVolt: import a song, mark beats, export a beat pack (song + click
guide track, optional preview mix, Pro guide video) for CapCut/VN. M1–M7
built the whole pipeline (see `PLAN.md` §9). M8 adds what a first-time
user and a paying user need:

- First-run onboarding (3 screens) and coach marks (3 overlays) in the
  editor.
- How-to screens for CapCut and VN.
- The Settings screen (export defaults, haptics, latency calibration, help).
- The real `EntitlementService`: free tier **30 exports per rolling 7
  days** (one pack = one export, N from `AppConstants.freeExportsPerWeek`),
  Pro via RevenueCat = guide video + unlimited exports (+ advanced
  detection, see D1).
- The Paywall screen, Home's "N free left" chip, and the gates in Export.

Environment notes:
- Windows dev machine; no device; local Android build broken; iOS only on
  Codemagic. Purchases can't be tried here at all; the service must be
  fully tested against a fake RevenueCat wrapper.
- Material from `package:material_ui/material_ui.dart`; theme `context.kv`,
  `KvText`; reuse `lib/shared/` widgets.
- **Dark theme only** (`PLAN.md` §8.7): the Settings design's Theme row is
  dropped.

## 3. Existing code you'll touch

| Path | What it is today |
|---|---|
| `lib/core/entitlements/entitlement_service.dart` (M6) | Interface (`changes`, `current`, `exportQuota`, `canExport`, `recordExport`) + `UnlimitedEntitlementService` stub registered in the locator. Export calls `canExport`/`recordExport`. |
| `lib/features/export/` (M6/M7) | Export screen with the quota caption ("Uses 1 of your 30 free exports this week", hidden for unlimited) and the Guide video row (gated by `hasGuideVideo`, with a "Pro" callback). |
| `lib/features/settings/` (M5/M6) | `AppSettings` (latency, haptics, `defaultClickStyle`, `defaultAudioFormat`, `includePreviewByDefault`, `monoGuideTrack`, `includeVideoByDefault`), `SettingsRepository`, `LatencyCalibrationRoute`. |
| `lib/core/haptics/haptics.dart` (M5) | Reads `hapticsEnabled`. |
| `lib/features/projects/presentation/pages/home_screen.dart` | "30 free left" chip (static, ~line 450), "How beat packs work" button (~line 361, does nothing), Settings icon (~line 462, "Settings screen arrives in M8"). |
| `lib/features/projects/data/repositories/project_repository.dart` | New projects get `DetectionSettings()` (sensitivity `0.5`). M8's default-sensitivity setting feeds this. |
| `lib/features/beat_editor/presentation/` | Editor screen; coach marks overlay it on first open. |
| `lib/app/app_router.dart`, `app_constants.dart` | Routes (Home is initial); `freeExportsPerWeek = 30`. |
| `pigeons/audio_api.dart`, `AudioHostApiImpl.*` | `listMusicLibrary` asks for the Android audio permission (M1). |
| `android/.../MainActivity.kt` | `FlutterActivity` (only matters if D2 changes to `purchases_ui_flutter`). |
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
  KickVolt" illustration — a static `CustomPainter` or SVG, no assets from
  outside the design), copy from `Main.html`, **Next**, **Skip**.
- Onboarding2: the beat pack (Song / Guide / Video PRO illustration) and
  the three steps, copy from `Onboarding2.html`.
- Onboarding3: permissions. Ask only for what the app actually uses:
  - **Android:** the audio permission (`READ_MEDIA_AUDIO` on API 33+,
    `READ_EXTERNAL_STORAGE` on ≤ 32), through the existing native
    permission path (add a Pigeon method `requestAudioPermission()` that
    reuses M1's `MainActivity` permission routing; don't add
    `permission_handler`).
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
boxes; they must not block on layout. Done or skipped → `coachMarksDone =
true`. No new package; a `Stack` + `CustomPainter` overlay is enough.

### 4.4 How-to (`HowToCapCut`, `HowToVN`)

One route `HowToRoute(initialTab)` with CapCut / VN tabs, four numbered
steps each, copy from the HTML, plus the "Beats a little early or late?
… Bulk › Shift all beats" tip. Reached from Home ("How beat packs work"),
ExportSuccess ("How to use it in CapCut and VN") and Settings (Help).

Copy corrections (research 2026-11-26):

- **CapCut step 3:** keep the design's "open **Beats**, turn on **Auto
  generate**" (from the design; not verifiable from CapCut's public help —
  the user should check it in the current app during the device test).
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
  App." (Shorter phrasing is fine; keep the path.)
- **"Open CapCut" / "Open VN" buttons:** neither app documents a URL
  scheme or file hand-off (see `docs/handoff/M6-export.md` §6.2). Drop the
  buttons. If the user later wants a plain "launch the app" button, that
  needs `LSApplicationQueriesSchemes` and an undocumented scheme — not in
  M8.

## 5. Settings (`Settings.png`, minus Theme)

Route `SettingsRoute` from Home's gear icon.

- **Pro banner:** "Get KickVolt Pro" → Paywall; when Pro: "KickVolt Pro ·
  Active" with "Manage subscription" (opens the store's subscription page
  via `url_launcher`: `https://apps.apple.com/account/subscriptions` on
  iOS; `https://play.google.com/store/account/subscriptions?package=com.kickvolt.app`
  on Android — confirm both URLs against Apple's and Google's docs and cite
  them in the report).
- **Export defaults:** Click sound (Snap/Rim/Blip/Kick), Audio format
  (WAV/M4A), Video format (MP4, read-only row), "Mono guide track (smaller
  file)" toggle, Preview mix in packs (toggle), Guide video in packs
  (toggle; Pro), Detection sensitivity (Low / Balanced / High → 0.25 /
  0.5 / 0.75, used for **new** projects' `DetectionSettings.sensitivity`).
  Each row opens a small picker sheet or toggles in place.
- **Feel:** Haptics switch (`hapticsEnabled`); "Tap timing (lag fix)" row
  showing the current offset → `LatencyCalibrationRoute`.
- **Help:** How to use a beat pack → `HowToRoute`; Send feedback →
  `mailto:` with `AppConstants.feedbackEmail` (placeholder, D4); About →
  "KickVolt v<version>" (version from a constant kept equal to
  `pubspec.yaml`'s `version`, with a test that reads `pubspec.yaml` and
  compares — no `package_info_plus`); Terms and Privacy links
  (`AppConstants.termsUrl`, `privacyUrl`, placeholders).
- **No Theme row.**
- `SettingsCubit` over `SettingsRepository`; every change saved
  immediately.

## 6. Entitlements and paywall

### 6.1 Packages (checked on pub.dev, 2026-11-26)

| Package | Version | Notes |
|---|---|---|
| `purchases_flutter` | 11.0.4 (2026-11-18) | RevenueCat SDK. Needs Flutter ≥ 3.22. <https://pub.dev/packages/purchases_flutter> |
| `url_launcher` | 6.3.3 (2026-10-02) <https://pub.dev/packages/url_launcher> | Terms/Privacy (required on the paywall by App Store rules for subscriptions), feedback mail, manage subscription. |
| `purchases_ui_flutter` | 11.0.4 | **Only if D2 is changed.** Its paywalls need iOS 15+ / Android API 24+ and `MainActivity` to extend `FlutterFragmentActivity` (<https://www.revenuecat.com/docs/tools/paywalls/installation>). |

### 6.2 RevenueCat setup (the user does this; document it in the report)

Write `docs/revenuecat-setup.md` with these steps for the user (no keys):

1. App Store Connect: create the app record (`com.kickvolt.app`), an
   auto-renewable subscription group with a monthly and a yearly product,
   and **Sandbox testers** (Users and Access › Sandbox Testers).
2. Play Console: create the app, the subscriptions (monthly/yearly base
   plans), upload a build to the **internal testing** track, and add
   testers to **License testing** (Setup › License testing). Testers must
   install from the Play testing link; sideloaded APKs can't buy
   (<https://www.revenuecat.com/docs/test-and-launch/sandbox/google-play-store>).
3. RevenueCat: a project with the iOS and Android apps, the products, an
   **entitlement** with identifier `pro` attached to both products, and an
   **offering** `default` (current) with packages `$rc_monthly` and
   `$rc_annual`.
4. iOS sandbox: sign in with the sandbox tester on the device
   (Settings › App Store › Sandbox Account). A StoreKit configuration file
   only works when the app is launched from Xcode, not `flutter run`
   (<https://www.revenuecat.com/docs/test-and-launch/sandbox/apple-app-store>),
   so the device test uses the sandbox account.
5. RevenueCat's **Test Store** key works without store setup for UI
   iteration, but a build with a Test Store key must never be uploaded to
   TestFlight or a Play track
   (<https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store>).

### 6.3 Keys

- `--dart-define=RC_APPLE_KEY=appl_…` and `--dart-define=RC_GOOGLE_KEY=goog_…`,
  read with `String.fromEnvironment`. Document a git-ignored
  `dart_defines/revenuecat.json` used with `--dart-define-from-file`, add
  it to `.gitignore`, and commit a `revenuecat.example.json` with
  placeholders. For Codemagic, the user adds the keys as secure environment
  variables and passes them as `--dart-define`s (document; don't change
  `codemagic.yaml`'s CI workflow beyond a commented example).
- **No key** (debug builds, tests, CI) → the service runs as **free tier
  with purchases unavailable**: the Paywall shows "Purchases aren't set up
  in this build" and the app works otherwise. Never crash, never grant Pro.

### 6.4 `EntitlementService` (the only gate)

Replace the M6 stub with `RevenueCatEntitlementService`:

- Wraps a thin `PurchasesClient` interface (configure, customer info,
  stream of customer-info updates, offerings, purchase a package,
  restore). The impl calls `purchases_flutter`; tests use a fake. Nothing
  else in the app imports `purchases_flutter`.
- `Entitlements` from `CustomerInfo.entitlements.active['pro']`:
  `isPro`, `hasGuideVideo = isPro` (and M7 is on `main`),
  `hasUnlimitedExports = isPro`, `hasAdvancedDetection = isPro` (gates
  nothing, D1).
- **Free quota (pure Dart, `ExportQuotaStore`):** a list of successful
  export timestamps (UTC ms) in `SharedPreferences`; `remaining = N −
  count(t > now − 7 days)`; prune older entries on write; **a pack is
  one** `recordExport()`; clock injected. A timestamp in the future (user
  changed the clock back) counts until it's older than 7 days from the
  *latest* known time — i.e. never let changing the clock give more free
  exports than N in any 7-day window; document the rule. Pro users aren't
  counted. Note in the report: a reinstall resets the count (local only);
  that's accepted for now.
- `canExport() = isPro || remaining > 0`. Offline: use the SDK's cached
  customer info; if none and offline, treat as free tier (the quota still
  works offline).
- `changes` emits on purchase, restore and customer-info updates; Home's
  chip, Export and Settings rebuild from it.
- Grep proof in the report: no `isPro`/quota checks outside the service.

### 6.5 Paywall (`Paywall.png`, custom screen — D2)

- "KickVolt Pro", "For editors who post every day." Rows: Unlimited
  exports — "Free: 30 a week" (`PLAN.md` §8.6, not the design's 3); Guide
  video in every pack (shown only if M7 is on `main`); Advanced detection
  (hidden, D1).
- Packages from the current offering: Yearly ("BEST VALUE") and Monthly,
  with `storeProduct.priceString` — never hard-coded prices. Loading and
  "Couldn't load prices" + Retry states.
- **Start Pro** → purchase the selected package; success → pop with a
  "You're Pro" SnackBar and `successNotification`; user-cancelled → no
  error; other errors → message. **Restore purchases** → restore;
  "Nothing to restore" if no `pro`. Terms / Privacy links; "Cancel
  anytime".
- Entry points: Settings banner, the Guide video row's "Pro" callback on
  Export, the Export button when `canExport()` is false ("You've used your
  30 free exports this week" + **Go Pro** / "Free again on <date>" from the
  oldest counted export + 7 days).

### 6.6 Home

- Chip: "N free left" from `exportQuota()`; hidden for Pro (or "PRO").
  Tapping it opens the Paywall.
- "How beat packs work" → `HowToRoute`. Gear → `SettingsRoute`.

## 7. Release readiness (not built in M8 — D3)

List in the report what's still missing for a store release, so the user
can schedule it: app icon and launch screen (still Flutter defaults),
Android release signing (release builds use the debug key —
`android/app/build.gradle.kts` `signingConfig = debug`), iOS signing and
TestFlight upload in Codemagic, `ios/Runner/PrivacyInfo.xcprivacy` (the
app and its SDKs use required-reason APIs such as `UserDefaults` via
`shared_preferences` and file timestamps), App Store / Play listings and
privacy labels (RevenueCat collects purchase history and an app user ID),
real Terms/Privacy URLs. If the user moved D3 into M8, they'll give you a
separate section; otherwise don't touch these.

## 8. Tests required

Deterministic only: no real-time waits; inject clocks; `fakeAsync`.

| Test | Must cover |
|---|---|
| `export_quota_store_test.dart` | 30 allowed then blocked; the 31st allowed exactly 7 days after the first (boundary: 7 days − 1 ms blocked, 7 days allowed); one pack = one count; pruning; N configurable (3 and 30); clock moved backwards / forwards doesn't grant extra exports in any 7-day window; corrupt stored value → empty list, no crash. |
| `revenuecat_entitlement_service_test.dart` | With a fake `PurchasesClient`: no key → free tier, purchases unavailable, no exception; `pro` active → all flags true and unlimited; not active → quota applies; purchase/restore emit on `changes`; user-cancelled purchase isn't an error; offline with cached info. |
| `settings_cubit_test.dart` + repository | New keys' defaults and round trips; sensitivity mapping; each toggle persists. |
| First run | Router decides Onboarding vs Home from `onboardingDone` before first frame; Skip/Allow/Not now all set it; coach marks shown once, Skip sets `coachMarksDone`. |
| Widget tests | Onboarding flow (3 pages, Skip); Coach marks (3 steps, Skip tips); How-to tabs and VN copy (assert "Auto Beats" text); Settings rows (no Theme row) open the right sheets/routes; Paywall: prices from a fake offering, loading/error, purchase success/cancel/error, restore; Home chip shows "N free left" and opens Paywall; Export blocked state shows the reset date and Go Pro. |
| Version test | About version constant == `pubspec.yaml` `version`. |
| Grep guard (test or CI script) | No `purchases_flutter` import outside the client impl. |

## 9. Out of scope (do not build)

- Release readiness items in §7 unless the user moved them in (D3).
- Theme switch / light theme.
- Server-side quota, accounts, login.
- "Advanced detection" features (D1).
- Opening CapCut/VN.
- `purchases_ui_flutter` unless D2 changed; `permission_handler`;
  `package_info_plus`; any package not in §6.1.

## 10. Acceptance checklist (used for verification)

```powershell
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

- [ ] All §8 tests pass on two consecutive full runs; no real-time waits.
- [ ] Onboarding on first run only; permission requests limited to §4.2.
- [ ] Coach marks once; How-to with corrected VN copy; no Open-app buttons.
- [ ] Settings per §5, no Theme row; every setting persisted and used.
- [ ] One `EntitlementService`; no Pro/quota checks elsewhere (grep shown).
- [ ] Free tier 30 per rolling 7 days, configurable, a pack counts once,
      clock-change safe.
- [ ] RevenueCat behind `PurchasesClient`; no keys in the repo;
      `--dart-define` documented; no-key builds run as free tier.
- [ ] Paywall uses offering prices; purchase, cancel, error, restore
      handled; Terms/Privacy links present.
- [ ] `docs/revenuecat-setup.md` written.
- [ ] Only `purchases_flutter` and `url_launcher` added.
- [ ] Branch `m8/onboarding-paywall` pushed; not merged; no PR.

## 11. Report to hand back

1. Branch name and `git log --oneline main..HEAD`.
2. Tails of `flutter analyze` and both `flutter test` runs.
3. Every `purchases_flutter` / `url_launcher` API used, with file and line
   in the pub cache.
4. Grep output proving no entitlement checks outside the service.
5. File-level summary: new, changed, deleted.
6. Decisions where the brief was ambiguous (clock rule, permission flow,
   coach-mark layout, etc.).
7. What the user must do: RevenueCat/App Store/Play setup steps, the keys
   to define, placeholder URLs to fill.
8. The release-readiness list (§7) as it stands.
9. What you could not compile, run or verify — say explicitly that no
   purchase was made and nothing ran on a device.
