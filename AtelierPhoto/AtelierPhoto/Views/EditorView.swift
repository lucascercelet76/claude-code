import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var panel: EditorPanel? = .layers
    @State private var showCrop = false
    @State private var showExport = false
    @State private var confirmClose = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CanvasArea()
                if let panel {
                    PanelContainer(panel: panel, openPanel: { self.panel = $0 })
                        .frame(height: 240)
                        .background(.bar)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Divider()
                EditorToolbar(selection: panel, onTap: handleTap)
            }
            .animation(.easeInOut(duration: 0.2), value: panel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .overlay { if editor.isProcessing { ProcessingOverlay(message: editor.processingMessage) } }
            .alert("Oups", isPresented: alertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(editor.alertMessage ?? "")
            }
            .confirmationDialog("Fermer le projet ?", isPresented: $confirmClose, titleVisibility: .visible) {
                Button("Fermer sans enregistrer", role: .destructive) { editor.closeDocument() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les modifications non exportées seront perdues.")
            }
            .fullScreenCover(isPresented: $showCrop) {
                if let item = editor.selectedImageItem {
                    CropView(image: item.original) { cropped in
                        editor.replaceSelectedOriginal(with: cropped)
                    }
                }
            }
            .sheet(isPresented: $showExport) {
                ExportView()
            }
            .onChange(of: panel) { _, newPanel in
                if newPanel == .brush {
                    if editor.tool == .move { editor.tool = .brush }
                } else {
                    editor.tool = .move
                }
                if newPanel?.needsImageLayer == true {
                    editor.selectImageLayerIfNeeded()
                }
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { editor.alertMessage != nil },
                set: { if !$0 { editor.alertMessage = nil } })
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                confirmClose = true
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Fermer le projet")
        }
        ToolbarItem(placement: .principal) {
            HStack(spacing: 24) {
                Button { editor.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(!editor.canUndo)
                    .accessibilityLabel("Annuler")
                Button { editor.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                    .disabled(!editor.canRedo)
                    .accessibilityLabel("Rétablir")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Exporter") { showExport = true }
                .bold()
        }
    }

    private func handleTap(_ tapped: EditorPanel) {
        if tapped == .crop {
            editor.selectImageLayerIfNeeded()
            if editor.selectedImageItem != nil {
                showCrop = true
            } else {
                editor.alertMessage = "Ajoute ou sélectionne un calque photo pour le recadrer."
            }
            return
        }
        panel = (panel == tapped) ? nil : tapped
    }
}

struct EditorToolbar: View {
    let selection: EditorPanel?
    let onTap: (EditorPanel) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(EditorPanel.allCases) { item in
                    Button {
                        onTap(item)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.systemImage)
                                .font(.title3)
                            Text(item.title)
                                .font(.caption2)
                        }
                        .frame(width: 66, height: 50)
                        .foregroundStyle(selection == item ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 6)
        .background(.bar)
    }
}

struct PanelContainer: View {
    let panel: EditorPanel
    let openPanel: (EditorPanel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(panel.title)
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 10)
            Group {
                switch panel {
                case .layers: LayersPanel()
                case .adjust: AdjustmentsPanel()
                case .filters: FiltersPanel()
                case .sketch: SketchPanel()
                case .cutout: CutoutPanel(onRefine: { openPanel(.brush) })
                case .shapes: ShapesPanel()
                case .text: TextPanel()
                case .brush: BrushPanel()
                case .crop: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct ProcessingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text(message).font(.headline)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

struct NeedsImageLayerView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Sélectionne un calque photo dans « Calques ».")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }
}

/// Curseur avec libellé, utilisé dans tous les panneaux.
struct LabeledSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    let title: String
    var systemImage: String? = nil
    @Binding var value: Value
    let range: ClosedRange<Value>

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.subheadline)
            .frame(width: 130, alignment: .leading)
            Slider(value: $value, in: range)
        }
    }
}
