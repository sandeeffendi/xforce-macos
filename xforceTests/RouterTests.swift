//
//  RouterTests.swift
//  xforceTests
//

import Testing
@testable import xforce

@MainActor
struct RouterTests {

    @Test func startsAtFirstSectionWithAnEmptyPath() {
        let router = Router()

        #expect(router.section == .explain)
        #expect(router.path.isEmpty)
        #expect(router.canGoBack == false)
    }

    @Test func navigatePushesRoutesInOrder() {
        let router = Router()

        router.navigate(to: .graph)
        router.navigate(to: .explain)

        #expect(router.path == [.graph, .explain])
        #expect(router.canGoBack)
    }

    @Test func popRemovesOnlyTheTopRoute() {
        let router = Router()
        router.navigate(to: .graph)
        router.navigate(to: .explain)

        router.pop()

        #expect(router.path == [.graph])
    }

    @Test func popOnAnEmptyPathIsANoOp() {
        let router = Router()

        router.pop()

        #expect(router.path.isEmpty)
    }

    @Test func popToRootClearsTheWholePath() {
        let router = Router()
        router.navigate(to: .graph)
        router.navigate(to: .explain)

        router.popToRoot()

        #expect(router.path.isEmpty)
    }

    @Test func selectingASectionClearsThePath() {
        let router = Router()
        router.navigate(to: .graph)

        router.select(.graph)

        #expect(router.section == .graph)
        #expect(router.path.isEmpty)
    }

    @Test func selectingTheCurrentSectionStillPopsToRoot() {
        let router = Router()
        router.navigate(to: .graph)

        router.select(.explain)

        #expect(router.section == .explain)
        #expect(router.path.isEmpty)
    }
}

@Suite
struct AppSectionTests {

    @Test func everySectionIsRenderableInTheSidebar() {
        for section in AppSection.allCases {
            #expect(section.title.isEmpty == false)
            #expect(section.systemImage.isEmpty == false)
        }
    }

    @Test func everySectionHasADistinctRootRoute() {
        let roots = AppSection.allCases.map(\.rootRoute)

        #expect(Set(roots).count == AppSection.allCases.count)
    }
}
