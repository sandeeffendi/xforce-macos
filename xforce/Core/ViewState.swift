//
//  ViewState.swift
//  xforce
//

import Foundation

/// The load state of a screen's content.
///
/// Deliberately non-generic while there is no domain model. Once a view model loads real
/// data, give `loaded` an associated value and make this generic over it.
nonisolated enum ViewState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
