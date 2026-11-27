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
