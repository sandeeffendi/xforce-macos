//
//  XforceApp.swift
//  xforce
//

import SwiftUI

@main
struct XforceApp: App {

    /// The single source of navigation truth for the main window.
    @State private var router = Router()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(router)
        }

        Settings {
            SettingsScreen()
        }
    }
}
