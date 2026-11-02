import SwiftUI

/// Suppression de l'arrière-plan.
struct CutoutPanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    let onRefine: () -> Void
    @State private var backgroundColor: Color = .white

    init(onRefine: @escaping () -> Void) {
        self.onRefine = onRefine
    }

    var body: some View {
        if editor.selectedImageItem != nil {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("L’iPhone détecte automatiquement le sujet (personne, animal, objet) et rend le fond transparent. Tout se fait sur l’appareil.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await editor.removeBackground(asNewLayer: false) }
                    } label: {
                        Label("Supprimer l’arrière-plan", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await editor.removeBackground(asNewLayer: true) }
                    } label: {
                        Label("Copier le sujet sur un nouveau calque", systemImage: "square.on.square.dashed")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    HStack {
                        Button {
                            editor.tool = .eraser
                            onRefine()
                        } label: {
                            Label("Affiner à la gomme", systemImage: "eraser")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        ColorPicker("", selection: $backgroundColor)
                            .labelsHidden()
                        Button("Fond uni") {
                            editor.addSolidBackground(backgroundColor)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
            }
        } else {
            NeedsImageLayerView()
        }
    }
}
