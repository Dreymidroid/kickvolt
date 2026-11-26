# Handoff: M4b — Advanced detection

Self-contained brief for an agent implementing milestone M4b of KickVolt.
Part 1 is the prompt to paste. Parts 2–11 are the spec. Verification
against §10 happens afterwards, in a separate session.

**Scheduling:** branches from today's `main` (M1–M5 merged). It touches
`beat_detection`, the Auto-detect sheet and the project model. M6
(export) touches different code, so the two can run at the same time;
whichever merges second rebases (expect small conflicts in
`lib/core/di/locator.dart` and the editor cubit).

**Free for everyone.** The design lists "Advanced detection" as a Pro
feature, but there are no payments yet. Nothing here is gated; don't add
Pro badges or checks.

---

## 1. Prompt (paste this to the agent)

> You are implementing milestone **M4b (Advanced detection)** of KickVolt,
> a Flutter app in the current repository
> (`https://github.com/Dreymidroid/kickvolt`, branch `main`).
>
> Before writing any code, read these in full:
> 1. `docs/handoff/M4b-advanced-detection.md` (this brief — it is the spec)
> 2. `docs/handoff/M4-beat-detection.md` (the engine you extend)
> 3. `CLAUDE.md`, `.ai/rules/structure.md`, `.ai/rules/state_management.md`
>    (project rules; they override your defaults)
> 4. `PLAN.md`, especially §3 "one timebase" (non-negotiable), §6 "M4",
>    and §9 (what M1–M5 built, known limits — note the 174 → 87 BPM case)
> 5. The code listed in §3 of the brief.
>
> Then:
> - Create a branch `m4b/advanced-detection` from `main`.
> - Implement §4–§7. Do **not** do anything in §9 (out of scope).
> - **No new packages.**
> - Write the synthetic-audio tests in §8 **first** (they are the real
>   acceptance bar), then make them pass. **Every existing detection test
>   must still pass unchanged** — steady songs must give the same beats as
>   before (§4.5).
> - Before you finish, run, in this order:
>   `dart run build_runner build --delete-conflicting-outputs`,
>   `dart format .`, `flutter analyze`, `flutter test`. All must be
>   clean/green. Run `flutter test` at least twice; a test that passes only
>   sometimes is a failure.
> - Commit in small logical commits (end each message with your usual
>   co-author line), push the branch, and **do not merge** or open a PR.
> - Finish with the report in §11.
>
> If the brief is ambiguous, pick the option that keeps beats as integer
> sample indices, keeps heavy work off the UI isolate and leaves results
> on steady songs unchanged; note the decision in your report and carry
> on. Do not edit `android/`, `ios/` or `pigeons/`. Do not loosen a test
> tolerance or edit an existing test's expectations to make it pass; if a
> check can't be met, say so in the report.

---

## 2. Context

KickVolt marks a song's beats and exports a click guide track for
CapCut/VN. M4 built a pure-Dart detector (`PLAN.md` §6 M4, §9): spectral
flux onset envelope (kick/snare band < 4 kHz) → prior-weighted tempo with
octave checks → Ellis dynamic-programming tracker at **one constant
period** → sample-accurate attack refinement → classification. Its known
weaknesses are exactly what the design's "Advanced detection: half-time,
swing and tempo changes" promises to fix:

1. **Wrong tempo octave.** 174 BPM drum-and-bass reads 87; half-time
   hip-hop can come out at 70 or 140. The user has no way to say "no,
   double it".
2. **Tempo changes.** The tracker assumes one tempo for the whole song.
   Live recordings drift, DJ edits and medleys step between tempos, and
   "sped up" TikTok edits often ramp. Beats slide off the music.
3. **Swing / shuffle.** Swung eighth notes put strong onsets at 2/3 of a
   beat. That invites 3/2 tempo errors (e.g. 90 BPM shuffle read as 135)
   and pulls tracked beats toward the off-beats.

M4b adds: a **tempo choice** the user controls (½× / 2× / alternatives),
a **tempo-changes mode** that tracks a varying tempo, and **swing-robust**
tempo and tracking. Quarter-note beats stay the unit; nothing adds
off-beat markers (§9).

**Core rule:** beats are `int` sample-frame indices into `song.wav`,
clamped to `[0, sampleCount − 1]`. Never store seconds.

Environment notes:
- Windows dev machine; everything here is pure Dart and testable locally.
- Generated test audio must fade every note out (a hard cut is a real
  click that turns up as a false onset).
- Detection must stay **loudness-independent** (M4 normalises the peak
  first; `music_detection_test.dart` checks a 30 dB range). Keep it so.
- On Windows an open file handle blocks deleting its folder. Re-tracking
  reads `song.wav` in an isolate that may be cancelled: open it only while
  reading and close it in `finally` (M4's verification fixed exactly this
  bug).

## 3. Existing code you'll touch

| Path | What it is today |
|---|---|
| `lib/features/beat_detection/domain/beat_analyzer.dart` (~1,130 lines) | `analyzeWavFile(...)` → `BeatAnalysis`. Streaming STFT (2048/512, centred frames), `_computeOnsetEnvelope`, `_TempoEstimate` (autocorrelation, log-normal prior at 120 BPM, multipliers `[1, 2, 0.5, 1.5, 2/3]`, kick/snare onsets for the octave choice), `_trackBeatsEllis(periodFrames)`, `_refineBeatsToSample`, `_computeFinalBpmFromBeats`, `_computeCombinedConfidence`. |
| `lib/features/beat_detection/domain/entities/beat_analysis.dart` | `BeatAnalysis { sampleRate, sampleCount, hopSize, bpm, confidence, beatPhaseSample, candidates: List<CandidateBeat>, frameLowEnergy, frameOverallEnergy }`. **The onset envelope isn't kept**, so re-tracking today means re-analysing the whole song. |
| `lib/features/beat_detection/data/analysis_cache_codec.dart` | `analysis.bin` codec (`KVAN` magic + `analysisCacheFormatVersion`); an unknown version throws `FormatException`. |
| `lib/features/beat_detection/data/analysis_isolate_runner.dart`, `data/repositories/beat_detection_repository.dart` | Isolate runner (progress, cooperative cancel, 2 s grace then kill) and `BeatDetectionRepository` (`analyze`, `classify`). |
| `lib/features/beat_detection/domain/beat_classifier.dart`, `section_builder.dart`, `beat_filter_view.dart` | Classification (strong/downbeat/drop, sensitivity), sections, filter view. Downbeats use `index % 4`. |
| `lib/features/projects/domain/entities/detection_settings.dart` (+ model, mapper, `currentProjectSchemaVersion`) | `DetectionSettings { sensitivity = 0.5, filter, status }`. |
| `lib/features/projects/domain/entities/project.dart` | `bpm`, `beatPhaseSample` drive the editor grid (Snap, `SnapRange`, `isOnGrid`). |
| `lib/features/beat_editor/presentation/widgets/auto_detect_sheet.dart` | Sensitivity slider, "Mark" filter chips, "Preview on the waveform ≈ N beats · BPM", Detect beats. Previews are instant because classification runs on the cached analysis. |
| `lib/features/beat_editor/bloc/beat_editor_cubit.dart` | `commitAutoDetect` / `markDropsOnly` go through the `ReplaceAll` command (restores beats, sections, bpm, phase, detection on undo). Snap is enabled only when `project.bpm != null`. |
| `test/features/beat_detection/…`, `test/fixtures/synthetic_audio.dart`, `synthetic_music.dart` | Click-track and music-like fixtures (`writeSyntheticSong`), detector/music/classify/filter/sections tests. |

## 4. Engine changes (pure Dart)

### 4.1 Cache what re-tracking needs

Add to `BeatAnalysis` and `analysis.bin` (bump `analysisCacheFormatVersion`;
an old-version file is simply re-analysed, never an error shown to the
user):

- `onsetEnvelope` (`Float32List`, one value per hop frame — ~62 KB for
  3 minutes at 44.1 kHz) and the kick/snare envelope if the tempo code
  needs it separately;
- `tempoCandidates`: up to 5 distinct tempi (BPM, period in frames,
  weighted score, normalised 0–1), best first, including the octave
  relatives of the winner (×2, ×½, ×3/2, ×2/3) when in 40–240 BPM;
- `localTempo`: the tempo curve from §4.3 (one period value per analysis
  block, e.g. every 1 s), and a `tempoStability` measure (e.g. relative
  spread of local periods after outlier removal);
- `swing`: estimated swing ratio (§4.4) and its confidence.

### 4.2 Tempo choice (half-time / double-time)

New pure function `retrack(BeatAnalysis, TrackingOptions)` →
`List<CandidateBeat>` (+ bpm, phase), where `TrackingOptions` holds the
chosen tempo (period) and the tempo mode. It runs the Ellis DP on the
cached envelope with the chosen period and then the existing sample
refinement (which reads small PCM windows from `song.wav`). So:

- Classification stays instant (< 5 ms).
- Re-tracking (DP + refinement) runs in the analysis isolate with cancel.
  Target: < 1 s for a 3-minute 44.1 kHz song on the dev machine (report
  the number). Cache the last re-track result per option set in memory so
  toggling back is instant.
- The **default** choice is the analyser's winner, so steady-song results
  are unchanged (§4.5).
- The automatic choice keeps M4's 40–220 BPM range and prior (so
  defaults don't change). Choices the user makes (½×, 2×, candidates) may
  go up to 240 BPM.

### 4.3 Tempo changes (varying tempo)

Mode `TempoMode { steady, varying }`, plus a suggestion:

- **Local tempo:** tempogram over sliding windows of the onset envelope
  (e.g. 8 s window, 1 s step; autocorrelation per window, same prior and
  octave scoring, but **constrained to the global octave** so a window
  can't flip to half/double). Smooth the per-window period with a Viterbi
  path over candidate periods that penalises jumps (log-period
  difference²), so a genuine step change survives and noise doesn't.
  Interpolate to a per-frame period `P(t)`.
- **Tracker:** the Ellis DP with the transition cost using the local
  period: `C[t] = O[t] + max over τ of (C[τ] − α·(log((t − τ)/P(t)))²)`,
  search window `[t − 2P(t), t − P(t)/2]`. Same α as M4, same
  backtracking, same sample refinement.
- **`tempoStability`** decides the suggestion: if the local tempo spreads
  more than ~2 % (choose and document the threshold from your tests), the
  sheet suggests "Tempo changes" (§6). Default mode stays **steady**;
  the user switches.
- **BPM shown:** in varying mode the project's `bpm` is the median local
  tempo, and the UI shows it with "~" ("~128 BPM, varies").
- **Grid:** the editor grid (`bpm` + `beatPhaseSample`) assumes one tempo.
  In varying mode store `bpm` as the median but mark the project
  `tempoVaries = true` (§5); the editor turns Snap off and disables it
  with the hint "Snap needs a steady tempo", and `SnapRange` is hidden.
  Nothing else in the editor changes.

### 4.4 Swing robustness

Swing moves the off-beat eighth (from 1/2 to ~2/3 of the beat); the beats
themselves stay put. M4b's job is to not be fooled by it:

- **Swing estimate:** after tracking, histogram the onset-envelope peaks
  between consecutive beats by their position as a fraction of the beat
  (0–1). A dominant peak near 0.5 = straight; 0.6–0.75 = swung. Store the
  ratio and a confidence. (Shown in the sheet as "Swing feel" — info only.)
- **Tempo:** when the swing confidence is high, the ×3/2 and ×2/3
  candidates are penalised against the beat-level candidate whose period
  explains both the beat and the swung off-beat (document the rule). A
  90 BPM shuffle must not read 135, nor 60.
- **Tracking:** the M4 snap of each tracked beat to the strongest onset
  within ±P/8 is fine for straight time; check with the swing fixtures
  that it never snaps to a swung off-beat (at 2/3 of a beat it's well
  outside ±1/8, so this should hold — prove it with a test).

### 4.5 No regressions

With the default options (`steady`, analyser's tempo), the beats, BPM and
phase for every existing test fixture must be **identical** to `main`'s
(same samples). Add a test that runs the old fixtures through the new
path and compares with values recorded from `main` before your change
(record them in a first commit).

## 5. Persistence

`DetectionSettings` gains (defaults keep old projects as they are):

- `tempoMode` (`steady` | `varying`, default `steady`);
- `tempoOverrideBpm` (`double?`, default null = the analyser's choice);
- and `Project` gains `tempoVaries` (`bool`, default false) — or derive it
  from `tempoMode`; pick one, keep it in one place, say which.

JSON model, mapper and `currentProjectSchemaVersion` bump with a
migration that defaults the new fields (old `project.json` files load
unchanged; tested). `ReplaceAll` already restores `detection` on undo;
check that it covers the new fields.

## 6. Auto-detect sheet

Keep the existing layout (`EditorAutoDetect.png`); add below Sensitivity
(build in the same style — there's no design for these rows):

- **Tempo** row: "128 BPM" with chips **½×**, **Auto**, **2×**, and a
  "More…" chip listing the other `tempoCandidates` ("Try 96 BPM"). Picking
  one re-tracks (§4.2) with a small "Finding beats…" indicator; the
  waveform preview updates when done. ½× / 2× disabled outside 40–240.
- **Tempo changes** switch ("Steady tempo" / "Tempo changes"). When the
  analysis suggests varying tempo and the switch is off, show
  "The tempo seems to drift. Try Tempo changes." under it.
- **Swing feel** (read-only, only when confident): "Swing feel detected —
  beats stay on the main pulse."
- The preview line "≈ N beats · 128 BPM" uses "~" in varying mode.
- **Detect beats** commits through `ReplaceAll` as today (one undo
  restores everything including the tempo choice and mode).
- Cancel / closing the sheet cancels an in-flight re-track.

The "no steady beat" sheet: add "Try Tempo changes" as an action when the
failure came with low global confidence but decent local confidence.

## 7. Rules

- All new maths is pure Dart in `lib/features/beat_detection/domain/`, no
  Flutter imports; heavy work in the isolate with progress and cooperative
  cancel; file handles closed on every path.
- Integer sample indices everywhere; beats sorted, unique, clamped.
- Loudness-independent; deterministic (no randomness without a fixed seed).
- Barrels updated; UI never calls the analyser or files directly.
- Mark heuristics with `// HEURISTIC` comments, as M4 did.

## 8. Tests required

Deterministic only: no real-time waits (`fakeAsync`, injected clocks,
`close()` to flush). Synthetic songs fade every note out. Write WAVs to
temp directories and analyse through the real file path.

Accuracy bar (same as M4): every detected beat within **±10 ms** of
truth, BPM within **±1** (steady) — measured, not assumed.

| Test | Must cover |
|---|---|
| `tempo_choice_test.dart` | 174 BPM drum-and-bass-like groove (kick on 1, snare on 2 and 4 of the 174 grid, fast hats): Auto may read 87 (record what it reads); choosing **2×** (or the 174 candidate) gives beats every 174-BPM period within ±10 ms. Half-time hip-hop at 70/140: both choices produce on-grid beats. ½×/2× round trip returns the original beats exactly. Candidates are distinct and include the octave relatives. 44.1 and 48 kHz. |
| `varying_tempo_test.dart` | Linear ramp 120 → 130 BPM over 60 s; step 100 → 140 at 30 s; slow drift ±2 % (live feel). **Varying** mode: every beat within ±10 ms of truth across the song. **Steady** mode on the same audio: record the worst error (shows why the mode exists). `tempoStability` suggests varying for the ramp/step and not for steady fixtures. Local tempo never flips octave. |
| `swing_test.dart` | Shuffle grooves at 90 and 120 BPM with swung hats at 0.62 and 0.67: BPM within ±1 of the true beat tempo (not ×3/2 or ×2/3), beats within ±10 ms, no beat on an off-beat; swing ratio estimated within ±0.05; straight fixtures report "straight". |
| `no_regression_test.dart` | All M4 fixtures (click tracks, music-like grooves at 0/−12/−24 dB, drumless) through the new code with default options → identical beats, BPM and phase to values recorded from `main`. |
| `analysis_cache_codec_test.dart` (extend) | Round trip of the new fields; old-version file → re-analysis path, no exception to the user. |
| `retrack_test.dart` | Re-track from cache equals a full analysis with the same options; cancel mid-retrack closes `song.wav` (folder deletable immediately); time for a 3-minute song (report). |
| Project model tests (extend) | New fields round trip; old `project.json` (previous schema) loads with defaults. |
| Cubit tests | Tempo chip → re-track → preview updates; Detect commits; one undo restores the previous beats, bpm, phase, sections and tempo mode/override; varying mode turns Snap off and disables it; closing the sheet cancels a re-track. |
| Widget tests | Auto sheet shows the Tempo row, chips, switch and suggestion; "~" in varying mode; disabled chips at the range edges. |

## 9. Out of scope (do not build)

- Off-beat / eighth-note markers or a new beat type (a possible follow-up:
  swing-aware off-beat markers for faster cuts).
- Time signatures other than 4/4 for downbeats; a per-section tempo map
  the user edits; a tempo-map-aware Snap grid.
- Pro badges, entitlement checks, paywall.
- Any package; any native or Pigeon change.
- Export (M6) changes.

## 10. Acceptance checklist (used for verification)

```powershell
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

- [ ] All §8 tests exist and pass on two consecutive full runs.
- [ ] Existing detection tests unchanged and green; default results on
      M4 fixtures identical to `main`'s.
- [ ] 174 BPM case reachable with one tap (2×), beats within ±10 ms.
- [ ] Varying mode tracks ramps/steps within ±10 ms; suggestion driven by
      `tempoStability`; Snap disabled in varying mode.
- [ ] Shuffle grooves read the right tempo; no beats on swung off-beats.
- [ ] Re-tracking from the cache in the isolate, cancellable, files closed;
      classification still < 5 ms.
- [ ] `analysis.bin` and `project.json` versions bumped with migrations.
- [ ] Undo of Detect restores the tempo choice and mode.
- [ ] No packages, no native changes, nothing gated.
- [ ] Branch `m4b/advanced-detection` pushed; not merged; no PR.

## 11. Report to hand back

1. Branch name and `git log --oneline main..HEAD`.
2. Tails of `flutter analyze` and both `flutter test` runs.
3. A results table: fixture, true BPM, Auto BPM, chosen BPM, mode, beats
   checked, worst error (ms), in both steady and varying mode where
   relevant; swing ratio estimated vs true.
4. Re-track time and full-analysis time for a 3-minute 44.1 kHz song; how
   measured.
5. The thresholds you chose (`tempoStability`, swing confidence, Viterbi
   penalty) and why.
6. File-level summary: new, changed, deleted.
7. Decisions where the brief was ambiguous.
8. What you couldn't meet or verify; say plainly that only synthetic audio
   was tested and nothing ran on a device.
