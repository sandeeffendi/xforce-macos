//
//  XforceApp.swift
//  xforce
//

import SwiftUI

@main
struct XforceApp: App {

    /// The single source of navigation truth for the main window.
    @State private var router = Router()

    /// The read-only ontology and snippets, loaded and validated once at launch. Injected
    /// individually through the environment, the same way the router is.
    @State private var content = ContentService()

    /// The on-device model behind the questioning step. The one service reached through a
    /// protocol, so it is injected by key path rather than by type — see
    /// `FeedbackService+Environment.swift`. Still created once here, still one service at a
    /// time.
    @State private var feedback: any FeedbackService = OnDeviceFeedbackService()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(router)
                .environment(content)
                .environment(\.feedback, feedback)
        }

        Settings {
            SettingsScreen()
        }
    }
}
