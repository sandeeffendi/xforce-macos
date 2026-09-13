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

    var body: some View {
        GeometryReader { proxy in
            let layout = GraphLayout(size: proxy.size)

            ZStack {
                ConceptEdgeCanvas(nodes: nodes, edges: edges, layout: layout)

                ForEach(nodes) { node in
                    ConceptNodeView(node: node)
                        .position(layout.point(for: node.position))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: Theme.Size.graphCanvasMinHeight)
        .padding(Theme.Spacing.medium)
        .accessibilityLabel("Concept graph")
    }
}

/// Turns an authored unit position into a point inside the space the graph was given.
///
/// The inset is half a node plus a gap, so a concept authored at the very edge of the unit
/// square is still drawn whole, name and all.
private struct GraphLayout {

    let size: CGSize

    private var inset: CGFloat { Theme.Size.graphNodeDiameter / 2 + Theme.Spacing.xLarge }

    func point(for position: ConceptPosition) -> CGPoint {
        CGPoint(
            x: inset + position.x * max(size.width - inset * 2, 0),
            y: inset + position.y * max(size.height - inset * 2, 0)
        )
    }
}

/// The edges, drawn once into a single canvas rather than as a view each.
///
/// A prerequisite is a solid line and a relationship is a dashed one, so the two kinds are
/// told apart by shape rather than by colour alone.
private struct ConceptEdgeCanvas: View {

    let nodes: [ConceptNode]
    let edges: [ConceptEdge]
    let layout: GraphLayout

    var body: some View {
        Canvas { context, _ in
            let points = Dictionary(
                nodes.map { ($0.id, layout.point(for: $0.position)) },
                uniquingKeysWith: { first, _ in first }
            )

            for edge in edges {
                guard let start = points[edge.from], let end = points[edge.to] else { continue }

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(path, with: .color(Theme.Color.separator), style: strokeStyle(for: edge.kind))
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
private struct ConceptNodeView: View {

    let node: ConceptNode

    var body: some View {
        VStack(spacing: Theme.Spacing.xSmall) {
            MasteryDot(level: node.mastery, diameter: Theme.Size.graphNodeDiameter)

            Text(node.name)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Theme.Size.graphNodeLabelWidth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.name), \(node.mastery.title)")
    }
}

#Preview("Light") {
    ConceptGraphView(nodes: .previewNodes, edges: .previewEdges)
        .background(Theme.Color.windowBackground)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ConceptGraphView(nodes: .previewNodes, edges: .previewEdges)
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
