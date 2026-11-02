import Photos
import SwiftUI

enum ExportFormat: String, CaseIterable, Identifiable {
    case png, jpeg
    var id: String { rawValue }
    var title: String { self == .png ? "PNG (transparence)" : "JPEG" }
    var fileExtension: String { self == .png ? "png" : "jpg" }
}

struct ExportView: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var format: ExportFormat = .png
    @State private var fileURL: URL?
    @State private var status: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .background(CheckerboardView())
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("\(Int(editor.canvasSize.width)) × \(Int(editor.canvasSize.height)) px")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Format", selection: $format) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    Task { await saveToPhotos() }
                } label: {
                    Label("Enregistrer dans Photos", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(image == nil)

                if let fileURL {
                    ShareLink(item: fileURL) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                if let status {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Exporter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .task {
                image = editor.renderFinalImage()
                writeFile()
            }
            .onChange(of: format) { _, _ in
                status = nil
                writeFile()
            }
        }
    }

    private func encodedData() -> Data? {
        guard let image else { return nil }
        switch format {
        case .png:
            return image.pngData()
        case .jpeg:
            return ImageProcessor.flattened(image, background: .white).jpegData(compressionQuality: 0.92)
        }
    }

    private func writeFile() {
        guard let data = encodedData() else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AtelierPhoto-\(stamp).\(format.fileExtension)")
        do {
            try data.write(to: url, options: .atomic)
            fileURL = url
        } catch {
            status = "Impossible de préparer le fichier : \(error.localizedDescription)"
        }
    }

    private func saveToPhotos() async {
        guard let data = encodedData() else { return }
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard authorization == .authorized || authorization == .limited else {
            status = "Accès à Photos refusé. Autorise-le dans Réglages › Atelier Photo."
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
            status = "Image enregistrée dans Photos ✓"
        } catch {
            status = "Échec de l’enregistrement : \(error.localizedDescription)"
        }
    }
}
