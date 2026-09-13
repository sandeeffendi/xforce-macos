//
//  SettingsViewModel.swift
//  xforce
//

import Observation

/// Scaffolding view model: holds screen state and exposes intent, with no domain behaviour
/// yet. `load()` will become async and populate a model once requirements exist.
@MainActor
@Observable
final class SettingsViewModel {

    private(set) var state: ViewState = .idle

    func load() {
        state = .loaded
    }
}
