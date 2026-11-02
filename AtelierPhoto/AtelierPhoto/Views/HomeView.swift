import PhotosUI
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showBlank = false
    @State private var isLoading = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.indigo.opacity(0.35), Color.black],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "camera.aperture")
                    .font(.system(size: 76, weight: .light))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Atelier Photo")
                    .font(.largeTitle.bold())
                Text("Calques, retouches, formes, esquisses et détourage.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    HomeButtonLabel(title: "Ouvrir une photo", systemImage: "photo.on.rectangle", prominent: true)
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: {
                        HomeButtonLabel(title: "Prendre une photo", systemImage: "camera")
                    }
                }
                Button { showBlank = true } label: {
                    HomeButtonLabel(title: "Toile vierge", systemImage: "square.dashed")
                }
            }
            .padding(24)
            .frame(maxWidth: 500)

            if isLoading {
                ProcessingOverlay(message: "Ouverture…")
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            isLoading = true
            Task {
                if let image = await item.loadUIImage() {
                    editor.open(image: image)
                }
                isLoading = false
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in editor.open(image: image) }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showBlank) {
            BlankCanvasSheet()
                .presentationDetents([.medium])
        }
    }
}

private struct HomeButtonLabel: View {
    let title: String
    let systemImage: String
    var prominent = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.ultraThinMaterial),
                        in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
    }
}

private struct BlankCanvasSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var color: Color = .white
    @State private var transparent = false

    private struct Preset: Identifiable {
        let name: String
        let size: CGSize
        var id: String { name }
    }

    private let presets: [Preset] = [
        Preset(name: "Portrait 4:5", size: CGSize(width: 1080, height: 1350)),
        Preset(name: "Carré", size: CGSize(width: 1080, height: 1080)),
        Preset(name: "Story 9:16", size: CGSize(width: 1080, height: 1920)),
        Preset(name: "Paysage 16:9", size: CGSize(width: 1920, height: 1080)),
        Preset(name: "A4", size: CGSize(width: 1240, height: 1754))
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Fond") {
                    Toggle("Transparent", isOn: $transparent)
                    if !transparent {
                        ColorPicker("Couleur", selection: $color)
                    }
                }
                Section("Format") {
                    ForEach(presets) { preset in
                        Button {
                            editor.openBlank(size: preset.size, color: transparent ? .clear : color)
                            dismiss()
                        } label: {
                            HStack {
                                Text(preset.name)
                                Spacer()
                                Text("\(Int(preset.size.width)) × \(Int(preset.size.height))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Toile vierge")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
