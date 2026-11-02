import SwiftUI

/// Zone d'édition : affiche la toile à la taille de l'écran et gère les gestes.
struct CanvasArea: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        GeometryReader { geo in
            let available = CGSize(width: max(geo.size.width - 24, 1), height: max(geo.size.height - 24, 1))
            let scale = min(available.width / max(editor.canvasSize.width, 1),
                            available.height / max(editor.canvasSize.height, 1))

            Color.clear
                .frame(width: editor.canvasSize.width * scale, height: editor.canvasSize.height * scale)
                .overlay {
                    CanvasContent(layers: editor.layers,
                                  canvasSize: editor.canvasSize,
                                  scale: scale,
                                  liveStroke: editor.liveStroke,
                                  liveStrokeLayerID: editor.liveStrokeLayerID)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(drawGesture(scale: scale), including: editor.tool == .move ? .none : .all)
                .gesture(transformGesture(scale: scale), including: editor.tool == .move ? .all : .none)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .background(Color(white: 0.13))
        .overlay(alignment: .top) { hint }
    }

    private var hintText: String? {
        switch editor.tool {
        case .move:
            guard let layer = editor.selectedLayer else { return nil }
            return "« \(layer.name) » : glisse pour déplacer, pince pour redimensionner et tourner"
        case .brush:
            return "Pinceau : dessine directement sur la toile"
        case .eraser:
            return "Gomme : efface le calque photo ou dessin sélectionné"
        }
    }

    @ViewBuilder
    private var hint: some View {
        if let text = hintText {
            Text(text)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 6)
                .allowsHitTesting(false)
        }
    }

    private func drawGesture(scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                editor.strokeChanged(at: point, displayScale: scale)
            }
            .onEnded { _ in editor.endStroke() }
    }

    private func transformGesture(scale: CGFloat) -> some Gesture {
        let drag = DragGesture()
            .onChanged { value in
                editor.updateTransform(.drag, translation: CGSize(width: value.translation.width / scale,
                                                                  height: value.translation.height / scale))
            }
            .onEnded { _ in editor.endTransform(.drag) }
        let pinch = MagnifyGesture()
            .onChanged { value in editor.updateTransform(.magnify, magnification: value.magnification) }
            .onEnded { _ in editor.endTransform(.magnify) }
        let rotate = RotateGesture()
            .onChanged { value in editor.updateTransform(.rotate, rotation: value.rotation) }
            .onEnded { _ in editor.endTransform(.rotate) }
        return drag.simultaneously(with: pinch).simultaneously(with: rotate)
    }
}

/// Rendu de tous les calques. Utilisé pour l'affichage (scale < 1) et l'export (scale = 1).
struct CanvasContent: View {
    let layers: [Layer]
    let canvasSize: CGSize
    let scale: CGFloat
    var liveStroke: Stroke? = nil
    var liveStrokeLayerID: UUID? = nil
    var showsTransparencyGrid = true

    var body: some View {
        ZStack {
            if showsTransparencyGrid {
                CheckerboardView()
            }
            ZStack {
                ForEach(layers) { layer in
                    if layer.isVisible {
                        LayerView(layer: layer,
                                  canvasSize: canvasSize,
                                  scale: scale,
                                  liveStroke: layer.id == liveStrokeLayerID ? liveStroke : nil)
                            .opacity(layer.opacity)
                            .blendMode(layer.blendMode.swiftUI)
                    }
                }
            }
            .compositingGroup()
        }
        .frame(width: canvasSize.width * scale, height: canvasSize.height * scale)
        .clipped()
    }
}

struct LayerView: View {
    let layer: Layer
    let canvasSize: CGSize
    let scale: CGFloat
    var liveStroke: Stroke?

    var body: some View {
        content
            .scaleEffect(layer.scale)
            .rotationEffect(layer.rotation)
            .offset(x: layer.offset.width * scale, y: layer.offset.height * scale)
    }

    private var frameSize: CGSize {
        CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
    }

    private var liveStrokes: [Stroke] {
        liveStroke.map { [$0] } ?? []
    }

    @ViewBuilder
    private var content: some View {
        switch layer.content {
        case .image(let item):
            let erase = item.eraseStrokes + liveStrokes
            Image(uiImage: item.rendered)
                .resizable()
                .scaledToFit()
                .frame(width: frameSize.width, height: frameSize.height)
                .overlay {
                    if !erase.isEmpty {
                        DrawingLayerView(strokes: erase, canvasSize: canvasSize, scale: scale)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

        case .drawing(let drawing):
            DrawingLayerView(strokes: drawing.strokes + liveStrokes, canvasSize: canvasSize, scale: scale)

        case .text(let item):
            Text(item.text.isEmpty ? " " : item.text)
                .font(.system(size: max(item.fontSize * scale, 1),
                              weight: item.isBold ? .bold : .regular,
                              design: item.fontStyle.design))
                .foregroundStyle(item.color)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(item.hasShadow ? 0.45 : 0),
                        radius: item.fontSize * scale * 0.06,
                        x: 0, y: item.fontSize * scale * 0.03)
                .fixedSize()

        case .shape(let item):
            ShapeLayerView(item: item, scale: scale)
        }
    }
}

struct ShapeLayerView: View {
    let item: ShapeItem
    let scale: CGFloat

    var body: some View {
        let shape = item.makeShape(scale: scale)
        let lineWidth = max(item.strokeWidth * scale, 0.5)
        ZStack {
            if item.kind.isLineLike {
                shape.stroke(item.fillColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            } else {
                if item.isFilled {
                    shape.fill(item.fillColor)
                }
                if item.hasStroke {
                    shape.stroke(item.strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                }
            }
        }
        .frame(width: item.size.width * scale, height: item.size.height * scale)
    }
}

/// Dessine des traits (coordonnées en pixels de la toile).
struct DrawingLayerView: View {
    let strokes: [Stroke]
    let canvasSize: CGSize
    let scale: CGFloat

    var body: some View {
        Canvas { context, _ in
            context.scaleBy(x: scale, y: scale)
            for stroke in strokes {
                guard let first = stroke.points.first else { continue }
                context.blendMode = stroke.isEraser ? .clear : .normal
                if stroke.points.count == 1 {
                    let dot = CGRect(x: first.x - stroke.width / 2, y: first.y - stroke.width / 2,
                                     width: stroke.width, height: stroke.width)
                    context.fill(Path(ellipseIn: dot), with: .color(stroke.color))
                } else {
                    var path = Path()
                    path.addLines(stroke.points)
                    context.stroke(path, with: .color(stroke.color),
                                   style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(width: canvasSize.width * scale, height: canvasSize.height * scale)
    }
}

/// Damier qui indique les zones transparentes.
struct CheckerboardView: View {
    var body: some View {
        Canvas { context, size in
            let tile = max(max(size.width, size.height) / 40, 4)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var path = Path()
            let columns = Int((size.width / tile).rounded(.up))
            let rows = Int((size.height / tile).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    path.addRect(CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile))
                }
            }
            context.fill(path, with: .color(Color(white: 0.85)))
        }
    }
}
