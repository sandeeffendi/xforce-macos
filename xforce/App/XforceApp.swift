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

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(router)
                .environment(content)
        }

        Settings {
            SettingsScreen()
        }
    }
}
