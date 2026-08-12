# Open decision — platform floor for night verification

**Raised:** 2026-08-12 · **Revisit:** after iOS 27 GA (~2026-09-14) · **Status:** open

## The proposal on the table

Raise the minimum to iOS 27, lean on on-device Apple Intelligence (Foundation Models
multimodal image input) to make verification work at any hour, ship a disclaimer that
the app "works best on iOS 27", and keep LiDAR/depth as the path for older devices.

Rationale given: launch can slip a month, most users update, and supporting iOS 17
is wasted effort that hampers performance.

## What has to be corrected before deciding

**1. iOS 27 and Apple Intelligence are separate gates.**

| | Hardware floor | Oldest iPhone |
|---|---|---|
| iOS 27 | A13 Bionic | iPhone 11 (2019) |
| Apple Intelligence | A17 Pro | iPhone 15 **Pro** (2023) |

An iOS 27 minimum does not deliver Apple Intelligence. It drops iPhone 11–14 while
still leaving most remaining users without Foundation Models. iPhone 15 / 15 Plus do
not qualify either — A16.

**2. The launch math is poor.** iOS 26 reached ~35% adoption at 30 days (79% only by
the following summer). Apple Intelligence-capable devices are ~940M of ~2.5B active,
about 37%, and that includes iPad and Mac. Gating on both at an October 2026 launch
means shipping to roughly a fifth of iPhone users. Newer devices update faster so the
true figure beats a naive multiply, but not by enough to matter.

**3. "Hampers performance" is inverted.** A deployment target costs `if #available`
branches, not runtime speed. And the LLM is the *slow* path: seconds per image versus
milliseconds for a Core ML classifier, against ~180 sampled frames per verification.

**4. An LLM is the wrong shape for a gate.** Even where available:
- Non-deterministic — the same video can yield different verdicts. On a gate that
  unlocks someone's apps, a retry that passes on an identical scene reads as broken.
- Returns text, not a calibrated score. `VerificationThresholds.swift` is
  "the single tunable source"; an LLM offers no number to tune and no operating point.
- Cannot be validated — no held-out accuracy, no false-positive/negative rates, on a
  gate that has an adversary.
- A general model doing a binary job a ~5 MB classifier does better and testably.

**5. One real point in favour.** iOS 27 brings new Vision APIs
(`GenerateIterativeSegmentationRequest`, objectness saliency) that need only iOS 27 —
*not* Apple Intelligence hardware — so they reach every iOS 27 device. That is a
better argument for an iOS 27 floor than the LLM is. It still does not pay off at
launch-time adoption levels.

## Current recommendation

- **Core ML night-sky classifier as the primary signal.** It is the "works at any hour"
  answer, and full device coverage is a bonus rather than a compromise.
- **Depth / LiDAR as the anti-spoof bonus** where hardware allows — it is the one
  signal that defeats a phone pointed at a screen showing sky.
- **Foundation Models as an optional second opinion on ambiguous cases only**, never
  as the gate. Gate it behind `if #available(iOS 27)` plus a capability check.
- **Stay on iOS 17.** An earlier draft of this doc floated iOS 18 as a middle ground;
  that was unfounded and is withdrawn. iOS 18 supports the identical device list to
  iOS 17 (iPhone XS/XR+), so it excludes no hardware — but it buys Sky nothing either,
  and notably did *not* fix the Screen Time problems that would matter here (unstable
  `ApplicationToken`s, the 6 MB `DeviceActivityMonitor` memory limit). Everything in
  this plan — Core ML, Vision, `AVCaptureDepthDataOutput`, CoreMotion — runs on iOS 17.
  Raise the floor when a specific API you need requires it, never on principle.

## What to check when revisiting (from ~2026-09-14)

1. **Real iOS 27 adoption** at 2 and 4 weeks post-GA — does it beat iOS 26's 35%/30d?
2. **Spike results.** Did the 8-scene matrix (Settings → debug menu → Inspect →
   "Signal probe") show depth separating night sky from indoor ceiling? Specifically
   scene 2 on a non-LiDAR device — risk R1. If stereo depth is dead at night, depth is
   LiDAR-only and the classifier carries night alone.
3. **Classifier feasibility.** Were training images collected? Create ML on iOS 17's
   Neural Scene Analyzer needs only a few hundred per class.
4. **Measure Foundation Models latency on a real device** before assuming it is
   viable in the verification path at all.
5. Re-read `Sky/Features/Verification/VisionAnalysis/Debug/` — the spike files carry
   the measured numbers.

## Related

- `CLAUDE.md` → Gotchas → "Night verification does not work"
- `Sky/Features/Verification/VisionAnalysis/SkyPixelCounter.swift` — the incumbent
  whose HSV thresholds (`v >= 0.35` / `v >= 0.75`) return ~0 in darkness
- `Sky/Features/Settings/NightModeView.swift` — the setting that currently promises
  after-dark verification and cannot deliver it
