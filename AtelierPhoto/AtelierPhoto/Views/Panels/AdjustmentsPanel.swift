import SwiftUI

struct AdjustmentsPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        if let item = editor.selectedImageItem {
            ScrollView {
                VStack(spacing: 4) {
                    LabeledSlider(title: "Luminosité", systemImage: "sun.max", value: binding(\.brightness), range: -0.5...0.5)
                    LabeledSlider(title: "Exposition", systemImage: "plusminus.circle", value: binding(\.exposure), range: -2...2)
                    LabeledSlider(title: "Contraste", systemImage: "circle.lefthalf.filled", value: binding(\.contrast), range: 0.5...1.5)
                    LabeledSlider(title: "Saturation", systemImage: "drop", value: binding(\.saturation), range: 0...2)
                    LabeledSlider(title: "Température", systemImage: "thermometer.medium", value: binding(\.temperature), range: -1...1)
                    LabeledSlider(title: "Netteté", systemImage: "triangle", value: binding(\.sharpness), range: 0...2)
                    LabeledSlider(title: "Vignette", systemImage: "circle.dashed", value: binding(\.vignette), range: 0...2)
                    Button("Réinitialiser les réglages") {
                        editor.editSelectedImage("adjust-reset") { $0.adjustments = Adjustments() }
                    }
                    .disabled(item.adjustments.isNeutral)
                    .padding(.top, 6)
                }
                .padding(.horizontal)
            }
        } else {
            NeedsImageLayerView()
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Adjustments, Double>) -> Binding<Double> {
        Binding(
            get: { editor.selectedImageItem?.adjustments[keyPath: keyPath] ?? Adjustments()[keyPath: keyPath] },
            set: { value in
                editor.editSelectedImage("adjust-\(keyPath.hashValue)") { $0.adjustments[keyPath: keyPath] = value }
            }
        )
    }
}
