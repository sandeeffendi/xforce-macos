//
//  ViewModelTests.swift
//  xforceTests
//

import Testing
@testable import xforce

/// Scaffolding view models that still have no domain behaviour.
///
/// The explain view model has left this suite: it now drives the loop, and is covered by
/// `ExplainViewModelTests` through the intent methods a learner's screen would call.
@MainActor
struct ViewModelTests {

    @Test func graphViewModelLoadsFromIdle() {
        let viewModel = GraphViewModel()
        #expect(viewModel.state == .idle)

        viewModel.load()

        #expect(viewModel.state == .loaded)
    }

    @Test func settingsViewModelLoadsFromIdle() {
        let viewModel = SettingsViewModel()
        #expect(viewModel.state == .idle)

        viewModel.load()

        #expect(viewModel.state == .loaded)
    }
}

@Suite
struct ViewStateTests {

    @Test func failedStatesCompareByMessage() {
        #expect(ViewState.failed("boom") == .failed("boom"))
        #expect(ViewState.failed("boom") != .failed("other"))
    }
}
