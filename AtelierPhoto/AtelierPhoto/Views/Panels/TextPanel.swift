import SwiftUI

struct TextPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Button {
                    editor.addText()
                } label: {
                    Label("Ajouter un texte", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if editor.selectedLayer?.textItem != nil {
                    TextField("Texte", text: binding(\.text, default: ""), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                    Picker("Police", selection: binding(\.fontStyle, default: .system)) {
                        ForEach(TextFontStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        ColorPicker("Couleur", selection: binding(\.color, default: .white))
                        Spacer(minLength: 20)
                        Toggle("Gras", isOn: binding(\.isBold, default: true))
                        Toggle("Ombre", isOn: binding(\.hasShadow, default: true))
                    }
                    LabeledSlider(title: "Taille", value: binding(\.fontSize, default: 64),
                                  range: 8...max(editor.canvasSize.width, editor.canvasSize.height) * 0.4)
                } else {
                    Text("Sélectionne un calque texte pour le modifier.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<TextItem, T>, default fallback: T) -> Binding<T> {
        Binding(
            get: { editor.selectedLayer?.textItem?[keyPath: keyPath] ?? fallback },
            set: { value in editor.editSelectedText("text-\(keyPath.hashValue)") { $0[keyPath: keyPath] = value } }
        )
    }
}
