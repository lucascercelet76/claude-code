import SwiftUI

struct ShapesPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShapeKind.allCases) { kind in
                        Button {
                            editor.addShape(kind)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: kind.systemImage)
                                    .font(.title2)
                                    .frame(width: 44, height: 30)
                                Text(kind.title)
                                    .font(.caption2)
                            }
                            .frame(width: 62)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
            }

            if let shape = editor.selectedLayer?.shapeItem {
                ShapeEditor(shape: shape)
            } else {
                Text("Touche une forme pour l’ajouter, puis personnalise-la ici. Déplace-la, agrandis-la ou fais-la pivoter directement sur la toile.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}

private struct ShapeEditor: View {
    @EnvironmentObject private var editor: EditorViewModel
    let shape: ShapeItem

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                HStack {
                    ColorPicker(shape.kind.isLineLike ? "Couleur" : "Remplissage", selection: binding(\.fillColor))
                    if !shape.kind.isLineLike {
                        Toggle("", isOn: binding(\.isFilled))
                            .labelsHidden()
                    }
                }
                if !shape.kind.isLineLike {
                    HStack {
                        ColorPicker("Contour", selection: binding(\.strokeColor))
                        Toggle("", isOn: binding(\.hasStroke))
                            .labelsHidden()
                    }
                }
                if shape.kind.isLineLike || shape.hasStroke {
                    LabeledSlider(title: "Épaisseur", value: binding(\.strokeWidth), range: 1...maxSide * 0.1)
                }
                LabeledSlider(title: "Largeur", value: widthBinding, range: 10...maxSide * 1.5)
                LabeledSlider(title: shape.kind.isLineLike ? "Pointe" : "Hauteur", value: heightBinding, range: 10...maxSide * 1.5)
                if shape.kind == .roundedRectangle {
                    LabeledSlider(title: "Arrondi", value: binding(\.cornerRadius), range: 0...maxSide * 0.5)
                }
                if shape.kind.hasPointCount {
                    Stepper("\(shape.kind == .star ? "Branches" : "Côtés") : \(shape.pointCount)",
                            value: binding(\.pointCount), in: 3...12)
                }
            }
            .padding(.horizontal)
        }
    }

    private var maxSide: CGFloat {
        max(editor.canvasSize.width, editor.canvasSize.height)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ShapeItem, T>) -> Binding<T> {
        Binding(
            get: { editor.selectedLayer?.shapeItem?[keyPath: keyPath] ?? shape[keyPath: keyPath] },
            set: { value in editor.editSelectedShape("shape-\(keyPath.hashValue)") { $0[keyPath: keyPath] = value } }
        )
    }

    private var widthBinding: Binding<CGFloat> {
        Binding(get: { editor.selectedLayer?.shapeItem?.size.width ?? shape.size.width },
                set: { value in editor.editSelectedShape("shape-width") { $0.size.width = value } })
    }

    private var heightBinding: Binding<CGFloat> {
        Binding(get: { editor.selectedLayer?.shapeItem?.size.height ?? shape.size.height },
                set: { value in editor.editSelectedShape("shape-height") { $0.size.height = value } })
    }
}
