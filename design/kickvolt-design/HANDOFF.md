# KickVolt: design handoff for Claude Code

Build the KickVolt Flutter app (iOS + Android) from these designs.

- `png/`: one 2× screenshot per screen (390×844 logical). This is the visual source of truth.
- `screens/`: the HTML source for each screen. Read it for exact sizes, colours, radii and copy. Ignore `<x-dc>`, `<helmet>`, `support.js` and the `data-dc-script` block; they belong to the design tool.
- `screens/canvas.json`: the canvas layout and the flow order (`order`).

## What the app does
The user imports a song, marks its beats (auto-detect, then fine-tune or tap along), and exports a **beat pack**:
1. **Song:** the clean audio.
2. **Guide track:** silent audio the same length as the song, with a short, sharp click on every marked beat. In CapCut or VN, the user puts it under the song, runs auto-beat on it, then mutes it.
3. **Guide video** (Pro): a black clip that flashes and shows the beat number on each beat.
4. **Preview mix:** the song with the clicks audible.

Audience: TikTok/Reels/Shorts editors working one-handed. Copy says "beats", "drops" and "sections", never "transients" or "onsets".

## Screens (flow order)
| Screen file | What it is |
|---|---|
| Main, Onboarding2, Onboarding3 | Onboarding: the problem, how a beat pack works, file/photo permissions |
| HomeEmpty, Home | Projects list (mini waveform, name, beats, BPM, length, last edited) and its empty state |
| ImportSheet, Analyzing, ImportError | Import from Files, the music library or a video; beat detection in progress; unsupported-file error |
| EditorEmpty … EditorBulk | Beat Editor states: empty, auto-detect sheet, detected, marker selected, tap-to-mark, playing, bulk actions |
| Coach1–3, EditorDetectFailed | First-run coach marks; "no steady beat found" error |
| Export, Exporting, ExportFailed, ExportSuccess | Export options, progress, failure, success / open in CapCut or VN |
| HowToCapCut, HowToVN | Four-step guide for using the pack in each editor |
| Settings, Paywall | Defaults, haptics, theme; Pro upsell |

## Design tokens
```
background   #0B0B10     surface1 #14141C   surface2 #1C1C27   surface3 #272735
border       #2C2C3C     text1    #F4F4F8   text2    #A6A6B8   text3    #8A8AA0
accent/volt  #C6FF3D (beats, primary actions, focus; text on it = #0B0B10)
error        #FF6B6B     warning  #FF8A4C
sections     intro/outro #9B8CFF  verse #45D4FF  build #FF6FB5  drop #FF8A4C (regions at ~7% alpha, labels at 18%)
waveform     played #ECEAFF, unplayed #7D7AA8, soft violet glow
glow         drop-shadow 0 0 6px volt @ 75%; primary buttons 0 0 28px volt @ 28%
fonts        Space Grotesk (headings), Inter (UI), JetBrains Mono (times, BPM, counts)
radii        buttons 16, cards 18–24, sheets 28 (top), chips/pills = full
touch        minimum 44 px; primary buttons 52–64 px tall
```
Dark theme first. Put these in a `ThemeData` and a `KvColors` ThemeExtension.

## Beat Editor (the core screen)
The layout from top to bottom:
1. Top bar: back, song name, "N beats · BPM", undo/redo, Export pill
2. Whole-song overview strip with section tints and a viewport box
3. Time ruler
4. Section labels
5. Zoomable waveform (pinch to zoom, drag to scrub) with a fixed centre playhead and a time bubble
6. Chips: BPM, Snap to grid, Clicks (click preview), zoom level
7. Transport: speed control (0.5×/.75×/1×), back 2 s, Play, forward 2 s
8. Context panel
9. Tool tabs: Auto, Tap, Edit, Sections, Bulk

Marker styles:
- **Regular beat:** thin volt line at 50% opacity with a dot head.
- **Strong beat:** solid glowing line with a numbered pill.
- **Drop:** a glowing "DROP" flag.
- **Selected:** a white line with a white numbered ring, plus a floating info card.

Context panel per tab:
- **Edit:** summary, add at playhead, re-detect. With a marker selected: nudge −10/−1/+1/+10 ms, type (Beat/Strong/Drop), Delete.
- **Tap:** a large tap pad that marks a beat on each tap, with latency compensation ("lag fix").
- **Bulk:** clear a range (dragged red handles on the waveform), shift all beats ± ms.
- **Auto:** a bottom sheet with sensitivity, a filter (every / strong / drops / every 2nd / every 4th), a live estimate and a Detect button.

Draw the waveform and markers with `CustomPainter`.

## Haptics (`HapticFeedback`)
- selectionClick: a marker is placed, snapped or nudged
- lightImpact: a strong beat passes the playhead (only when Clicks is on)
- heavyImpact: a drop passes the playhead
- success pattern: detection or export finished
- warning: delete or clear range
- Settings has a switch to turn all haptics off.

## Suggested stack (adjust to taste)
- **State:** Riverpod or BLoC. Use an immutable beat list with undo/redo history (Freezed).
- **Audio:** `just_audio` for playback and speed; `ffmpeg_kit` (or a maintained fork) to decode, extract audio from video, and render the guide track and video.
- **Beat detection:** an on-device onset/tempo detector (e.g. aubio through FFI, or a Dart port), with sensitivity and filter applied after detection.
- **Files and sharing:** `file_picker`, `on_audio_query` (music library), `image_picker` (video), `share_plus`, and URL schemes to open CapCut/VN (check that the schemes exist).
- **Paywall:** RevenueCat. Prices are placeholders.

## Open items to confirm
- VN's menu labels for auto-beat (the CapCut guide uses Beats › Auto generate)
- Free tier limit (designed as 3 exports a week)
- Click sound set (Snap, Rim, Blip, Kick) and the export file naming
