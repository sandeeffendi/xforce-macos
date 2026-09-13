//
//  SettingsScreen.swift
//  xforce
//

import SwiftUI

/// Presented in its own window by the `Settings` scene (⌘,), per macOS convention.
/// It is not a sidebar destination and therefore has no `AppRoute`.
struct SettingsScreen: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section("General") {
                LabeledContent("Version", value: Bundle.main.appVersion)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 200)
        .task { viewModel.load() }
    }
}

private extension Bundle {
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

#Preview("Light") {
    SettingsScreen().preferredColorScheme(.light)
}

#Preview("Dark") {
    SettingsScreen().preferredColorScheme(.dark)
}
