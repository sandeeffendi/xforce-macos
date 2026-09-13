//
//  FeedbackService+Environment.swift
//  xforce
//

import SwiftUI

extension EnvironmentValues {

    /// The feedback service, injected the way every other service is.
    ///
    /// A key path rather than `@Environment(SomeService.self)`, which the router and the
    /// content service use: that form resolves an `@Observable` class by its concrete type,
    /// and this is the one service the design deliberately reaches through a protocol. The
    /// injection point is still `XforceApp`, and still one service at a time — no container.
    ///
    /// The default exists so previews and `RouteBuilder` render without ceremony. Every
    /// build of the real app overrides it in `XforceApp`, and every test constructs the view
    /// model directly with the fake, so nothing relies on the default's lifetime.
    @Entry var feedback: any FeedbackService = OnDeviceFeedbackService()
}
