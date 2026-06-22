# Sky

iOS app (SwiftUI, iOS 17+) that blocks selected social apps after a daily time
budget and requires a verified ~30-second **outdoor video** to unlock them.
Friendly cloud mascot, **Nimbus**. Strict, on-device verification is the entire
product. No skip credits — the only escape is a friction-loaded emergency unlock.
iOS-only, no third-party SDKs, nothing leaves the device.

## Documentation (source of truth)

| Doc | Use it for |
|---|---|
| [`Sky_PRD.md`](Sky_PRD.md) | Product requirements, brand voice, branding constants |
| [`Sky_Technical_Spec.md`](Sky_Technical_Spec.md) | Architecture, frameworks, data model, folder structure, verification thresholds |
| [`Sky_Development_Roadmap.md`](Sky_Development_Roadmap.md) | The 16 build phases, in dependency order, with tests per phase |
| [`Sky_App_Workflow.md`](Sky_App_Workflow.md) | Every screen, journey, state machine, and copy string |
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | Authoritative visual spec — color, type, spacing, components, Nimbus |
| [`CLAUDE.md`](CLAUDE.md) | Working guidance / conventions for this codebase |

## Targets

| Target | Bundle ID | Role |
|---|---|---|
| `Sky` (app) | `com.shirolepranav.sky` | Main app |
| `DeviceActivityMonitorExtension` | `com.shirolepranav.sky.deviceactivity` | Background threshold/midnight callbacks |
| `ShieldConfigurationExtension` | `com.shirolepranav.sky.shieldconfig` | Renders the custom shield |
| `ShieldActionExtension` | `com.shirolepranav.sky.shieldaction` | Handles shield button taps |
| `SkyTests` | `com.shirolepranav.sky.SkyTests` | Unit tests |

All four share App Group `group.com.shirolepranav.sky`. iCloud container:
`iCloud.com.shirolepranav.sky`. Deep-link scheme: `sky://`.

## Build & verify

Full **Xcode 16+** is required to build, run, and preview (iOS SDK, Simulator,
`#Preview`). The project uses file-system synchronized groups, so new files in a
target's folder are picked up automatically — no project-file edits needed.

```bash
xcodebuild -project Sky.xcodeproj -scheme Sky \
  -destination 'generic/platform=iOS Simulator' build
```

On a machine with only Command Line Tools you can type-check the cross-platform
SwiftUI under `Sky/` against the macOS SDK (strip `#Preview` blocks first); see
[`CLAUDE.md`](CLAUDE.md) for the snippet. This validates Swift correctness only —
not iOS layout, the extension targets, or signing.

## Build status

- **Phase 0 — Foundation Setup:** project skeleton, 4 targets, capabilities,
  folder structure, git. ✅ (pending the Apple-account steps in
  [`PHASE_0_CHECKLIST.md`](PHASE_0_CHECKLIST.md))
- **Phase 1 — Design System & Mascot:** tokens, components, Nimbus, preview
  screen. ✅
- Everything else: not started. See the Roadmap.

The app currently launches `DesignSystemPreviewScreen` for visual QA.

## Git workflow

Single branch: **`main`**. Remote: `https://github.com/shirolepranav/Sky.git`.
