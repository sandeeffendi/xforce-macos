//
//  ViewModelTests.swift
//  xforceTests
//

import Testing
@testable import xforce

@MainActor
struct ViewModelTests {

    @Test func explainViewModelLoadsFromIdle() {
        let viewModel = ExplainViewModel()
        #expect(viewModel.state == .idle)

        viewModel.load()

        #expect(viewModel.state == .loaded)
    }

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
