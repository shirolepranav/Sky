// AppearanceMode.swift
// Phase 16 — the user's light/dark/system choice, persisted and applied at the
// app root via `.preferredColorScheme`. The adaptive tokens in ColorTokens.swift
// respond to whatever interface style this resolves to (system or forced).
// Settings screen: S-SET-10 (AppearanceView). Storage: SharedDefaults.appearanceModeRaw.

import SwiftUI

/// The three appearance choices offered in Settings.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// The `preferredColorScheme` value to apply at the root. `nil` means "follow
    /// the device", which lets iOS drive light/dark automatically.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// Row title in the Appearance picker.
    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// One-line description under each row.
    var subtitle: String {
        switch self {
        case .system: return "Match your device setting"
        case .light:  return "Always the bright, warm theme"
        case .dark:   return "Always the calm night-sky theme"
        }
    }

    /// SF Symbol shown alongside each row.
    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.stars.fill"
        }
    }
}

/// Observable holder for the appearance choice, backed by `SharedDefaults`.
/// Created once in `SkyApp` and injected as an environment object; the Settings
/// screen writes `mode`, the root reads `mode.colorScheme`.
@MainActor
final class AppearanceManager: ObservableObject {
    @Published var mode: AppearanceMode {
        didSet {
            guard mode != oldValue else { return }
            store.appearanceModeRaw = mode.rawValue
        }
    }

    private let store: SharedDefaults

    init(store: SharedDefaults = SharedDefaults()) {
        self.store = store
        self.mode = AppearanceMode(rawValue: store.appearanceModeRaw) ?? .system
    }
}
