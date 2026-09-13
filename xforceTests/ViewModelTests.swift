//
//  ViewModelTests.swift
//  xforceTests
//

import Testing
@testable import xforce

/// Scaffolding view models that still have no domain behaviour.
///
/// Two view models have left this suite. The explain view model drives the loop and is covered
/// by `ExplainViewModelTests`; the graph view model builds the concept map and is covered by
/// `GraphViewModelTests`. Both are exercised through the intent methods a learner's screen
/// would call.
@MainActor
struct ViewModelTests {

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
