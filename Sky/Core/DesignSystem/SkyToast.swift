// SkyToast.swift
// Reusable confirmation toast — S-CFG-06 and future Settings uses.
// Sky_App_Workflow.md §S-CFG-06. DESIGN_SYSTEM.md §7.
//
// Apply via .skyToast(isPresented:message:onComplete:) on any view.
// Auto-dismisses after 2.5 s; tapping dismisses immediately.
// Transitions: slide-up + fade by default, fade-only under Reduce Motion.

import SwiftUI

struct SkyToast: View {
    let message: String
    var icon: String = "checkmark.circle.fill"
    var onDismiss: () -> Void = {}

    var body: some View {
        HStack(spacing: SkySpacing.s3) {
            Image(systemName: icon)
                .foregroundStyle(SkyColor.mossGreen)
                .font(.system(size: 16, weight: .semibold))
            Text(message)
                .skyText(.label)
        }
        .padding(.horizontal, SkySpacing.s5)
        .padding(.vertical, SkySpacing.s3)
        .background(SkyColor.warmCream, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .accessibilityElement(children: .combine)
        .onTapGesture { onDismiss() }
        .onAppear {
            #if os(iOS)
            UIAccessibility.post(notification: .announcement, argument: message)
            #endif
        }
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            onDismiss()
        }
    }
}

// MARK: – View modifier

private struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    SkyToast(message: message, icon: icon) {
                        withAnimation(.spring(response: 0.25)) {
                            isPresented = false
                        }
                        onComplete()
                    }
                    .padding(.horizontal, SkyLayout.screenMargin)
                    .padding(.bottom, SkySpacing.s6)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
                }
            }
            .animation(.spring(response: 0.25), value: isPresented)
    }
}

extension View {
    /// Overlays a bottom-anchored confirmation toast when `isPresented` is true.
    /// `onComplete` fires once when the toast finishes dismissing (auto or tap).
    func skyToast(
        isPresented: Binding<Bool>,
        message: String,
        icon: String = "checkmark.circle.fill",
        onComplete: @escaping () -> Void = {}
    ) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, icon: icon, onComplete: onComplete))
    }
}

#Preview("SkyToast") {
    ZStack(alignment: .bottom) {
        SkyColor.surface.ignoresSafeArea()
        SkyToast(message: "Saved. Sky's watching.")
            .padding(.horizontal, SkyLayout.screenMargin)
            .padding(.bottom, SkySpacing.s6)
    }
}
