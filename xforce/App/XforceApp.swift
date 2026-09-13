//
//  XforceApp.swift
//  xforce
//

import SwiftData
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

    /// The single source of truth for the learner's own work. There is no second store: the
    /// ontology is read-only bundle data and is never written at runtime.
    private let container: ModelContainer

    /// Reads and writes that store. Injected individually, like the services beside it.
    @State private var scheduling: SchedulingService

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Note.self, ConceptProgress.self)
        } catch {
            // The store holds every note the learner has written. Carrying on without it would
            // mean sessions that look committed and are not, so there is nothing to degrade to.
            fatalError("The store holding your notes and progress could not be opened: \(error)")
        }

        self.container = container
        _scheduling = State(initialValue: SchedulingService(container: container))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(router)
                .environment(content)
                .environment(\.feedback, feedback)
                .environment(scheduling)
        }

        Settings {
            SettingsScreen()
        }
    }
}
