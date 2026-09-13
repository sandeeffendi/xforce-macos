//
//  GraphScreen.swift
//  xforce
//

import SwiftUI

/// The map of what the learner understands: every concept in the ontology, drawn where it was
/// authored to sit and coloured by how well it is understood.
///
/// The screen reaches the content and the store and nothing else. No model is consulted here,
/// deliberately: reviewing your own progress must never be gated on whether Apple Intelligence
/// is available on this Mac.
///
/// Split in two the way every screen is, because `@Environment` is not readable when the
/// `@State` view model's initial value is computed.
struct GraphScreen: View {
    @Environment(ContentService.self) private var content
    @Environment(SchedulingService.self) private var scheduling

    var body: some View {
        GraphScreenContent(content: content, scheduling: scheduling)
    }
}

private struct GraphScreenContent: View {
    @State private var viewModel: GraphViewModel

    /// Navigation is expressed as intent, never as a destination view. The inspector's
    /// practise control pushes the route the view model named; nothing here builds a screen.
    @Environment(Router.self) private var router

    init(content: ContentService, scheduling: SchedulingService) {
        _viewModel = State(initialValue: GraphViewModel(content: content, scheduling: scheduling))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.none) {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                PlaceholderView(
                    title: "The map could not be drawn",
                    message: message,
                    systemImage: "exclamationmark.triangle"
                )
                .padding(Theme.Spacing.xLarge)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                ConceptGraphView(
                    nodes: viewModel.nodes,
                    edges: viewModel.edges,
                    selectedID: viewModel.selectedConceptID,
                    onSelect: { viewModel.select($0) }
                )

                Divider()

                MasteryLegend()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.windowBackground)
        .navigationTitle(AppSection.graph.title)
        .task { viewModel.load() }
        .inspector(isPresented: inspectorPresented) {
            if let concept = viewModel.selectedConcept {
                ConceptInspector(
                    concept: concept,
                    history: viewModel.history,
                    onStartSession: startSession
                )
                .inspectorColumnWidth(
                    min: Theme.Size.inspectorMinWidth,
                    ideal: Theme.Size.inspectorIdealWidth,
                    max: Theme.Size.inspectorMaxWidth
                )
            }
        }
    }

    /// The inspector follows the selection. Closing it is the learner saying they are done
    /// with that concept, so it clears the selection rather than leaving the graph ringed
    /// around a concept nothing is showing.
    private var inspectorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.isInspectorPresented },
            set: { isPresented in
                guard isPresented == false else { return }
                viewModel.clearSelection()
            }
        )
    }

    /// Pushes the route the view model named. The practice screen it resolves to starts where
    /// every pass through the loop starts, so the gate arrives with it.
    private func startSession() {
        guard let route = viewModel.startSession() else { return }

        router.navigate(to: route)
    }
}

#Preview("Light") {
    GraphScreen()
        .environment(Router())
        .environment(ContentService())
        .environment(SchedulingService.inMemory())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    GraphScreen()
        .environment(Router())
        .environment(ContentService())
        .environment(SchedulingService.inMemory())
        .preferredColorScheme(.dark)
}
