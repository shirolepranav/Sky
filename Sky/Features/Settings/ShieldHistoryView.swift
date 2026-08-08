// ShieldHistoryView.swift
// Debug-only reader for the ShieldAudit trail (S-SET-09 → Inspect → Shield history).
//
// Exists because the shield is written from processes that run while the app is
// closed, so "my apps unlocked and I don't know why" cannot be answered from the
// Xcode console after the fact. Shows the newest entry first.
//
// Debug builds only — see the #if DEBUG wrapping DebugMenuView.

#if DEBUG
import SwiftUI

struct ShieldHistoryView: View {
    @State private var lines: [String] = []

    var body: some View {
        List {
            if lines.isEmpty {
                Text("No shield activity recorded yet.")
                    .skyText(.body, color: SkyColor.inkMuted)
            } else {
                Section("Newest first") {
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
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SkyColor.surface.ignoresSafeArea())
        .navigationTitle("Shield history")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("debug.shieldHistory")
        .onAppear { lines = ShieldAudit.formattedLines() }
    }
}

#Preview("Shield history") {
    NavigationStack { ShieldHistoryView() }
}
#endif
