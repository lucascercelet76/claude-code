import SwiftUI

struct FiltersPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        if let item = editor.selectedImageItem {
            VStack(spacing: 12) {
                FilterStrip(filters: PhotoFilter.photoFilters, source: item.original, current: item.filter)
                if item.filter != .none {
                    LabeledSlider(title: "Intensité", value: intensityBinding(editor), range: 0...1)
                        .padding(.horizontal)
                }
            }
        } else {
            NeedsImageLayerView()
        }
    }
}

/// Transforme une photo en dessin : crayon, crayons de couleur, fusain, contours, BD.
struct SketchPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        if let item = editor.selectedImageItem {
            ScrollView {
                VStack(spacing: 10) {
                    FilterStrip(filters: PhotoFilter.sketchStyles, source: item.original, current: item.filter)
                    if item.filter.isSketch {
                        Group {
                            if item.filter != .comic {
                                LabeledSlider(title: "Épaisseur du trait", value: detailBinding, range: 0...1)
                            }
                            LabeledSlider(title: "Mélange photo", value: intensityBinding(editor), range: 0...1)
                        }
                        .padding(.horizontal)
                    } else {
                        Text("Choisis un style pour transformer ta photo en esquisse. Astuce : détoure d’abord le sujet pour une esquisse sur fond transparent.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
            }
        } else {
            NeedsImageLayerView()
        }
    }

    private var detailBinding: Binding<Double> {
        Binding(get: { editor.selectedImageItem?.sketchDetail ?? 0.5 },
                set: { value in editor.editSelectedImage("sketch-detail") { $0.sketchDetail = value } })
    }
}

@MainActor
private func intensityBinding(_ editor: EditorViewModel) -> Binding<Double> {
    Binding(get: { editor.selectedImageItem?.filterIntensity ?? 1 },
            set: { value in editor.editSelectedImage("intensity") { $0.filterIntensity = value } })
}

/// Bande de vignettes de filtres, calculées sur une version réduite de la photo.
struct FilterStrip: View {
    @EnvironmentObject private var editor: EditorViewModel
    let filters: [PhotoFilter]
    let source: UIImage
    let current: PhotoFilter
    @State private var thumbnails: [PhotoFilter: UIImage] = [:]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters) { filter in
                    Button {
                        editor.applyFilter(filter)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.2))
                                if let thumbnail = thumbnails[filter] {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ProgressView()
                                }
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(current == filter ? Color.accentColor : Color.clear, lineWidth: 3)
                            )
                            Text(filter.title)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(current == filter ? Color.accentColor : Color.primary)
                        }
                        .frame(width: 80)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .task(id: ObjectIdentifier(source)) {
            await loadThumbnails()
        }
    }

    private func loadThumbnails() async {
        let small = ImageProcessor.resized(source, maxDimension: 220)
        let list = filters
        let result = await Task.detached(priority: .utility) { () -> [PhotoFilter: UIImage] in
            var dictionary: [PhotoFilter: UIImage] = [:]
            for filter in list {
                var item = ImageItem(image: small)
                item.filter = filter
                dictionary[filter] = ImageProcessor.render(item)
            }
            return dictionary
        }.value
        thumbnails = result
    }
}
