//
//  ConceptGraphView.swift
//  xforce
//

import SwiftUI

/// Draws the ontology: a node per concept where it was authored to sit, with the ontology's
/// own edges behind them.
///
/// Nothing here computes a layout. Positions arrive as authored unit coordinates and are only
/// scaled into the space the view is given, which is what makes the map identical on every
/// open and what makes it worth memorising.
struct ConceptGraphView: View {

    let nodes: [ConceptNode]
    let edges: [ConceptEdge]

    /// The concept whose history is open, drawn with a ring so the map says which one the
    /// inspector is talking about.
    let selectedID: String?

    /// What clicking a node means: open that concept's notes.
    let onSelect: (String) -> Void

    /// The mark and its name grow with the learner's text size, and the inset that keeps an
    /// edge-of-the-square node on screen has to grow with them.
    @ScaledMetric(relativeTo: .caption) private var nodeDiameter = Theme.Size.graphNodeDiameter
    @ScaledMetric(relativeTo: .caption) private var labelWidth = Theme.Size.graphNodeLabelWidth

    var body: some View {
        GeometryReader { proxy in
            let layout = GraphLayout(
                size: proxy.size,
                horizontalInset: labelWidth / 2 + Theme.Spacing.small,
                verticalInset: nodeDiameter / 2 + Theme.Spacing.xLarge
            )

            ZStack {
                ConceptEdgeCanvas(edges: edges, points: layout.points(for: nodes))

                ForEach(nodes) { node in
                    ConceptNodeView(
                        node: node,
                        diameter: nodeDiameter,
                        labelWidth: labelWidth,
                        isSelected: node.id == selectedID,
                        onSelect: { onSelect(node.id) }
                    )
                    .position(layout.point(for: node.position))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.medium)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Concept graph")
    }
}

/// Turns an authored unit position into a point inside the space the graph was given.
///
/// The insets are what keep a concept authored at the very edge of the unit square fully on
/// screen: half a mark plus a gap vertically, half a name horizontally, because the name is
/// centred under the mark and is the wider of the two.
private struct GraphLayout {

    let size: CGSize
    let horizontalInset: CGFloat
    let verticalInset: CGFloat

    func point(for position: ConceptPosition) -> CGPoint {
        CGPoint(
            x: horizontalInset + position.x * max(size.width - horizontalInset * 2, 0),
            y: verticalInset + position.y * max(size.height - verticalInset * 2, 0)
        )
    }

    /// Every node's point, keyed by concept id, so the edges can find both of their ends.
    func points(for nodes: [ConceptNode]) -> [String: CGPoint] {
        nodes.reduce(into: [:]) { points, node in
            points[node.id] = point(for: node.position)
        }
    }
}

/// The edges, drawn once into a single canvas rather than as a view each.
///
/// A prerequisite is a solid line and a relationship is a dashed one, so the two kinds are
/// told apart by shape rather than by colour alone.
private struct ConceptEdgeCanvas: View {

    let edges: [ConceptEdge]
    let points: [String: CGPoint]

    var body: some View {
        Canvas { context, _ in
            for edge in edges {
                guard let start = points[edge.from], let end = points[edge.to] else { continue }

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(path, with: .color(Theme.Color.graphEdge), style: strokeStyle(for: edge.kind))
            }
        }
        // The relationships are drawn for the eye. What each concept is and how well it is
        // understood reaches VoiceOver through the nodes themselves.
        .accessibilityHidden(true)
    }

    private func strokeStyle(for kind: ConceptEdge.Kind) -> StrokeStyle {
        switch kind {
        case .prerequisite:
            StrokeStyle(lineWidth: Theme.Size.graphEdgeWidth)
        case .related:
            StrokeStyle(lineWidth: Theme.Size.graphEdgeWidth, dash: [Theme.Size.graphDash])
        }
    }
}

/// One concept: the mark for its mastery level, with the concept's name under it.
///
/// A button rather than a decoration, because the graph is a way into the learner's own
/// record rather than a picture of it. The ring says which concept the inspector is currently
/// talking about; the padding under it is always there, so selecting one never shifts the map.
private struct ConceptNodeView: View {

    let node: ConceptNode
    let diameter: CGFloat
    let labelWidth: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: Theme.Spacing.xSmall) {
                MasteryDot(level: node.mastery, diameter: diameter)
                    .padding(Theme.Spacing.xSmall)
                    .overlay {
                        if isSelected {
                            Circle()
                                .strokeBorder(Theme.Color.brand, lineWidth: Theme.Size.graphNodeBorder)
                        }
                    }

                Text(node.name)
                    .font(Theme.Font.caption)
                    .foregroundStyle(isSelected ? Theme.Color.primaryText : Theme.Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: labelWidth)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.name), \(node.mastery.title)")
        .accessibilityHint("Shows the notes you have written about this concept.")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Light") {
    ConceptGraphView(
        nodes: .previewNodes,
        edges: .previewEdges,
        selectedID: "optionals",
        onSelect: { _ in }
    )
    .background(Theme.Color.windowBackground)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ConceptGraphView(
        nodes: .previewNodes,
        edges: .previewEdges,
        selectedID: "optionals",
        onSelect: { _ in }
    )
    .background(Theme.Color.windowBackground)
    .preferredColorScheme(.dark)
}

private extension [ConceptNode] {

    /// One node per mastery level, so the palette can be read in both appearances while the
    /// shipped ontology is still a single concept.
    static var previewNodes: [ConceptNode] {
        [
            ConceptNode(id: "variables", name: "Variables", position: ConceptPosition(x: 0, y: 0.2), mastery: .strong),
            ConceptNode(id: "optionals", name: "Optionals", position: ConceptPosition(x: 0.4, y: 0), mastery: .developing),
            ConceptNode(id: "closures", name: "Closures", position: ConceptPosition(x: 0.75, y: 0.55), mastery: .weak),
            ConceptNode(id: "protocols", name: "Protocols", position: ConceptPosition(x: 0.2, y: 1), mastery: .untouched),
        ]
    }
}

private extension [ConceptEdge] {

    static var previewEdges: [ConceptEdge] {
        [
            ConceptEdge(from: "variables", to: "optionals", kind: .prerequisite),
            ConceptEdge(from: "optionals", to: "closures", kind: .prerequisite),
            ConceptEdge(from: "variables", to: "protocols", kind: .related),
        ]
    }
}
