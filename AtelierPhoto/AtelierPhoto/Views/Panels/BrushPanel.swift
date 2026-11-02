import SwiftUI

struct BrushPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    private let swatches: [Color] = [.white, .black, .red, .orange, .yellow, .green, .mint, .blue, .purple, .pink, .brown]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Outil", selection: $editor.tool) {
                    Text("Pinceau").tag(EditorTool.brush)
                    Text("Gomme").tag(EditorTool.eraser)
                    Text("Déplacer").tag(EditorTool.move)
                }
                .pickerStyle(.segmented)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ColorPicker("", selection: $editor.brushColor)
                            .labelsHidden()
                        ForEach(swatches, id: \.self) { color in
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                                .onTapGesture {
                                    editor.brushColor = color
                                    if editor.tool == .move { editor.tool = .brush }
                                }
                        }
                    }
                    .padding(.vertical, 2)
                }

                HStack {
                    LabeledSlider(title: "Taille", value: $editor.brushWidth, range: 2...80)
                    Circle()
                        .fill(editor.tool == .eraser ? Color.secondary : editor.brushColor)
                        .frame(width: min(editor.brushWidth, 40), height: min(editor.brushWidth, 40))
                        .frame(width: 44)
                }

                Text("Le pinceau dessine sur le calque dessin sélectionné (ou en crée un). La gomme efface le calque photo ou dessin sélectionné.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }
}
