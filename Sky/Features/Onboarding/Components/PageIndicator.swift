// PageIndicator.swift
// Custom paging dots for the onboarding host — Sky_App_Workflow.md §S-ONB-02..05.
//
// We hide the system TabView dots and draw our own so the colors come from
// SkyColor (the system dots can't be tinted to our palette). Onboarding-specific,
// so it lives under Features/Onboarding/Components rather than Core/DesignSystem.

import SwiftUI

struct PageIndicator: View {
    let pageCount: Int
    let currentIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: SkySpacing.s2) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? SkyColor.primarySkyDeep : SkyColor.cloudGrey)
                    .frame(width: index == currentIndex ? 22 : 8, height: 8)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: currentIndex)
        .accessibilityHidden(true) // page content carries the state for VoiceOver
    }
}

#Preview("Page indicator") {
    VStack(spacing: SkySpacing.s6) {
        PageIndicator(pageCount: 5, currentIndex: 0)
        PageIndicator(pageCount: 5, currentIndex: 2)
        PageIndicator(pageCount: 5, currentIndex: 4)
    }
    .padding(SkySpacing.s10)
    .background(SkyColor.warmCream)
}
