// NimbusPNGExporter.swift
// One-time development utility to generate NimbusCloudy.png / @2x / @3x for
// ShieldConfigurationExtension/Assets.xcassets/NimbusCloudy.imageset/.
//
// Usage (run once, then delete this file or leave it gated behind #if DEBUG):
//   1. Open the Preview below in Xcode (requires iOS Simulator).
//   2. Tap "Export NimbusCloudy PNGs".
//   3. Copy the three files from the printed path into the imageset folder.
//
// After copying, UIImage(named: "NimbusCloudy") in SkyShieldConfiguration
// will load the correct mascot at the device's screen scale.

#if DEBUG
import SwiftUI

struct NimbusPNGExporter: View {
    @State private var status = "Tap the button to export."

    var body: some View {
        VStack(spacing: 24) {
            NimbusView(state: .cloudyGrey, size: 180)

            Text(status)
                .font(.system(.caption, design: .monospaced))
                .multilineTextAlignment(.leading)
                .padding(.horizontal)

            Button("Export NimbusCloudy PNGs") { export() }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(Color(hex: "FFF6E5"))
    }

    private func export() {
        guard let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else {
            status = "Could not locate Documents directory."
            return
        }

        // NimbusView natural aspect is width × (width × 0.78).
        let pt: CGFloat = 120
        var lines: [String] = []

        for scale in [1, 2, 3] {
            let renderer = ImageRenderer(
                content: NimbusView(state: .cloudyGrey, size: pt)
                    .frame(width: pt, height: pt * 0.78)
            )
            renderer.scale = CGFloat(scale)

            guard let png = renderer.uiImage?.pngData() else {
                lines.append("@\(scale)x — render failed")
                continue
            }

            let suffix = scale == 1 ? "" : "@\(scale)x"
            let filename = "NimbusCloudy\(suffix).png"
            let dest = docs.appendingPathComponent(filename)
            do {
                try png.write(to: dest)
                lines.append("✓ \(filename)\n  \(dest.path)")
            } catch {
                lines.append("✗ \(filename): \(error.localizedDescription)")
            }
        }

        status = lines.joined(separator: "\n\n")
        lines.forEach { print($0) }
    }
}

#Preview("NimbusPNGExporter — run once in Simulator to generate shield assets") {
    NimbusPNGExporter()
}
#endif
