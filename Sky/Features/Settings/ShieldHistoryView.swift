// ShieldHistoryView.swift
// Debug-only reader for the ShieldAudit trail (S-SET-09 → Inspect → Shield history).
//
// Exists because the shield is written from processes that run while the app is
// closed, so "my apps unlocked and I don't know why" cannot be answered from the
// Xcode console after the fact. Shows the newest entry first.
//
// The trail also carries notification entries (`notified` / `suppressed`), which
// answer the companion question — "why did Sky buzz me at 11am when I hadn't
// opened anything?". They are broken out into their own section because that is
// the report they exist to diagnose, and they are easy to lose among shield
// writes. A `suppressed` run with no `applied` alongside it is the signature of
// iOS replaying already-crossed thresholds after a re-arm.
//
// Debug builds only — see the #if DEBUG wrapping DebugMenuView.

#if DEBUG
import SwiftUI

struct ShieldHistoryView: View {
    @State private var lines: [String] = []
    @State private var notificationLines: [String] = []

    var body: some View {
        List {
            if !notificationLines.isEmpty {
                Section("Notifications — newest first") {
                    ForEach(Array(notificationLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .skyText(.caption, color: SkyColor.ink)
                            .monospaced()
                    }
                }
            }

            if lines.isEmpty {
                Text("No shield activity recorded yet.")
                    .skyText(.body, color: SkyColor.inkMuted)
            } else {
                Section("All activity — newest first") {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .skyText(.caption, color: SkyColor.ink)
                            .monospaced()
                    }
                }
            }

            Section {
                Button("Clear history", role: .destructive) {
                    ShieldAudit.clear()
                    lines = []
                    notificationLines = []
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Shield history")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("debug.shieldHistory")
        .onAppear {
            lines = ShieldAudit.formattedLines()
            notificationLines = ShieldAudit.notificationLines()
        }
    }
}

#Preview("Shield history") {
    NavigationStack { ShieldHistoryView() }
}
#endif
