import PhotosUI
import SwiftUI

struct LayersPanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                }
                .accessibilityLabel("Ajouter une photo")
                Button { editor.addDrawingLayer() } label: { Image(systemName: "scribble") }
                    .accessibilityLabel("Ajouter un calque de dessin")
                Button { editor.duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }
                    .accessibilityLabel("Dupliquer")
                Button { editor.moveSelected(up: true) } label: { Image(systemName: "arrow.up") }
                    .accessibilityLabel("Monter le calque")
                Button { editor.moveSelected(up: false) } label: { Image(systemName: "arrow.down") }
                    .accessibilityLabel("Descendre le calque")
                Button { editor.resetTransformOfSelected() } label: { Image(systemName: "arrow.counterclockwise") }
                    .accessibilityLabel("Réinitialiser position et taille")
                Spacer()
                Button(role: .destructive) { editor.deleteSelected() } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Supprimer le calque")
            }
            .font(.title3)
            .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(editor.layers.reversed())) { layer in
                        LayerRow(layer: layer, isSelected: layer.id == editor.selectedLayerID)
                    }
                }
                .padding(.horizontal)
            }

            if editor.selectedLayer != nil {
                HStack(spacing: 12) {
                    Text("Opacité").font(.subheadline)
                    Slider(value: opacityBinding, in: 0...1)
                    Picker("Fusion", selection: blendBinding) {
                        ForEach(LayerBlendMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 150)
                }
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let image = await item.loadUIImage() {
                    editor.addImageLayer(image)
                }
                photoItem = nil
            }
        }
    }

    private var opacityBinding: Binding<Double> {
        Binding(get: { editor.selectedLayer?.opacity ?? 1 },
                set: { value in editor.editSelected("opacity") { $0.opacity = value } })
    }

    private var blendBinding: Binding<LayerBlendMode> {
        Binding(get: { editor.selectedLayer?.blendMode ?? .normal },
                set: { value in editor.editSelected("blend") { $0.blendMode = value } })
    }
}

private struct LayerRow: View {
    @EnvironmentObject private var editor: EditorViewModel
    let layer: Layer
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 38, height: 38)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(title)
                .lineLimit(1)
                .font(.subheadline)
            Spacer()
            Button {
                editor.toggleVisibility(layer.id)
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(layer.isVisible ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layer.isVisible ? "Masquer" : "Afficher")
        }
        .padding(6)
        .background(isSelected ? Color.accentColor.opacity(0.22) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { editor.select(layer.id) }
    }

    private var title: String {
        if let text = layer.textItem?.text, !text.isEmpty { return "T  \(text)" }
        return layer.name
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let item = layer.imageItem {
            Image(uiImage: item.rendered)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: layer.systemImage)
                .foregroundStyle(layer.shapeItem?.fillColor ?? Color.primary)
        }
    }
}

extension PhotosPickerItem {
    func loadUIImage() async -> UIImage? {
        guard let data = try? await loadTransferable(type: Data.self) else { return nil }
        return UIImage(data: data)
    }
}
