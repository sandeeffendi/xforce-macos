//
//  PlaceholderView.swift
//  xforce
//

import SwiftUI

/// Scaffolding component: a themed card describing a screen that has no behaviour yet.
///
/// Remove it once every feature renders real content.
struct PlaceholderView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.Color.brand)

            Text(title)
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Color.primaryText)

            Text(message)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(Theme.Spacing.xLarge)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .strokeBorder(Theme.Color.separator)
        )
    }
}

#Preview("Light") {
    PlaceholderView(
        title: "Explain",
        message: "Placeholder content for the scaffolding phase.",
        systemImage: "text.bubble"
    )
    .padding()
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    PlaceholderView(
        title: "Explain",
        message: "Placeholder content for the scaffolding phase.",
        systemImage: "text.bubble"
    )
    .padding()
    .preferredColorScheme(.dark)
}
