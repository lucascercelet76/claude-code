import Photos
import SwiftUI
import UIKit

enum EditorTool: Hashable {
    case move, brush, eraser
}

enum EditorPanel: String, CaseIterable, Identifiable {
    case layers, adjust, filters, sketch, cutout, shapes, text, brush, crop
    var id: String { rawValue }

    var title: String {
        switch self {
        case .layers: "Calques"
        case .adjust: "Réglages"
        case .filters: "Filtres"
        case .sketch: "Esquisse"
        case .cutout: "Détourer"
        case .shapes: "Formes"
        case .text: "Texte"
        case .brush: "Pinceau"
        case .crop: "Recadrer"
        }
    }

    var systemImage: String {
        switch self {
        case .layers: "square.3.layers.3d"
        case .adjust: "slider.horizontal.3"
        case .filters: "camera.filters"
        case .sketch: "pencil.and.scribble"
        case .cutout: "scissors"
        case .shapes: "square.on.circle"
        case .text: "textformat"
        case .brush: "paintbrush.pointed"
        case .crop: "crop.rotate"
        }
    }

    var needsImageLayer: Bool {
        switch self {
        case .adjust, .filters, .sketch, .cutout, .crop: true
        default: false
        }
    }
}

@MainActor
final class EditorViewModel: ObservableObject {
    struct Snapshot {
        let layers: [Layer]
        let canvasSize: CGSize
        let selectedLayerID: UUID?
    }

    enum TransformGesture: Hashable {
        case drag, magnify, rotate
    }

    // MARK: Document
    @Published var layers: [Layer] = []
    @Published var canvasSize = CGSize(width: 1080, height: 1350)
    @Published var selectedLayerID: UUID?
    @Published var hasDocument = false

    // MARK: Outils
    @Published var tool: EditorTool = .move
    @Published var brushColor: Color = .white
    @Published var brushWidth: CGFloat = 16
    @Published private(set) var liveStroke: Stroke?
    @Published private(set) var liveStrokeLayerID: UUID?

    // MARK: État
    @Published var isProcessing = false
    @Published var processingMessage = ""
    @Published var alertMessage: String?
    @Published private(set) var undoStack: [Snapshot] = []
    @Published private(set) var redoStack: [Snapshot] = []

    private let maxHistory = 40
    private var lastCoalescedUndo: (key: String, date: Date)?
    private var renderingLayers: Set<UUID> = []
    private var isStroking = false
    private var strokeCreatedLayer = false

    private var transformBase: Layer?
    private var activeTransforms: Set<TransformGesture> = []
    private var dragDelta: CGSize = .zero
    private var magnifyDelta: CGFloat = 1
    private var rotateDelta: Angle = .zero

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Ouverture / fermeture

    func open(image: UIImage) {
        let normalized = ImageProcessor.resized(image)
        clearHistory()
        canvasSize = normalized.size
        let layer = Layer(name: "Arrière-plan", content: .image(ImageItem(image: normalized)))
        layers = [layer]
        selectedLayerID = layer.id
        tool = .move
        hasDocument = true
    }

    func openBlank(size: CGSize, color: Color) {
        open(image: ImageProcessor.solidImage(color: UIColor(color), size: size))
        if !layers.isEmpty { layers[0].name = "Fond" }
    }

    func closeDocument() {
        layers = []
        selectedLayerID = nil
        hasDocument = false
        clearHistory()
    }

    // MARK: - Historique

    func registerUndo() {
        undoStack.append(Snapshot(layers: layers, canvasSize: canvasSize, selectedLayerID: selectedLayerID))
        if undoStack.count > maxHistory { undoStack.removeFirst() }
        redoStack.removeAll()
        lastCoalescedUndo = nil
    }

    /// Regroupe les modifications rapprochées d'un même réglage (curseur, couleur…) en une seule étape d'annulation.
    func registerUndoCoalescing(_ key: String) {
        let now = Date()
        if let last = lastCoalescedUndo, last.key == key, now.timeIntervalSince(last.date) < 1 {
            lastCoalescedUndo = (key, now)
            return
        }
        registerUndo()
        lastCoalescedUndo = (key, now)
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(Snapshot(layers: layers, canvasSize: canvasSize, selectedLayerID: selectedLayerID))
        restore(snapshot)
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(Snapshot(layers: layers, canvasSize: canvasSize, selectedLayerID: selectedLayerID))
        restore(snapshot)
    }

    private func restore(_ snapshot: Snapshot) {
        layers = snapshot.layers
        canvasSize = snapshot.canvasSize
        if let id = snapshot.selectedLayerID, layers.contains(where: { $0.id == id }) {
            selectedLayerID = id
        } else {
            selectedLayerID = layers.last?.id
        }
        lastCoalescedUndo = nil
        resetTransformState()
        for layer in layers {
            if let item = layer.imageItem, item.renderedKey != item.settingsKey {
                scheduleRender(layerID: layer.id)
            }
        }
    }

    private func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        lastCoalescedUndo = nil
    }

    // MARK: - Sélection

    var selectedIndex: Int? {
        guard let id = selectedLayerID else { return nil }
        return layers.firstIndex { $0.id == id }
    }

    var selectedLayer: Layer? { selectedIndex.map { layers[$0] } }
    var selectedImageItem: ImageItem? { selectedLayer?.imageItem }

    func select(_ id: UUID) {
        selectedLayerID = id
        resetTransformState()
    }

    /// Sélectionne le calque photo le plus haut si la sélection actuelle n'en est pas un.
    func selectImageLayerIfNeeded() {
        guard selectedImageItem == nil,
              let layer = layers.last(where: { $0.imageItem != nil }) else { return }
        select(layer.id)
    }

    private func index(of id: UUID) -> Int? {
        layers.firstIndex { $0.id == id }
    }

    // MARK: - Modifications du calque sélectionné

    func editSelected(_ key: String, _ change: (inout Layer) -> Void) {
        guard let i = selectedIndex else { return }
        registerUndoCoalescing("\(layers[i].id.uuidString)-\(key)")
        change(&layers[i])
    }

    func editSelectedShape(_ key: String, _ change: (inout ShapeItem) -> Void) {
        editSelected(key) { layer in
            guard case .shape(var item) = layer.content else { return }
            change(&item)
            layer.content = .shape(item)
        }
    }

    func editSelectedText(_ key: String, _ change: (inout TextItem) -> Void) {
        editSelected(key) { layer in
            guard case .text(var item) = layer.content else { return }
            change(&item)
            layer.content = .text(item)
        }
    }

    func editSelectedImage(_ key: String, _ change: (inout ImageItem) -> Void) {
        guard let i = selectedIndex, case .image(var item) = layers[i].content else { return }
        registerUndoCoalescing("\(layers[i].id.uuidString)-\(key)")
        change(&item)
        layers[i].content = .image(item)
        scheduleRender(layerID: layers[i].id)
    }

    func applyFilter(_ filter: PhotoFilter) {
        editSelectedImage("filter") { $0.filter = filter }
    }

    func resetTransformOfSelected() {
        guard let i = selectedIndex else { return }
        registerUndo()
        layers[i].offset = .zero
        layers[i].scale = 1
        layers[i].rotation = .zero
    }

    // MARK: - Gestion des calques

    private func insertLayer(_ layer: Layer) {
        registerUndo()
        if let i = selectedIndex {
            layers.insert(layer, at: i + 1)
        } else {
            layers.append(layer)
        }
        selectedLayerID = layer.id
    }

    private func nextName(_ base: String) -> String {
        let count = layers.filter { $0.name.hasPrefix(base) }.count
        return "\(base) \(count + 1)"
    }

    func addImageLayer(_ image: UIImage) {
        let normalized = ImageProcessor.resized(image)
        var layer = Layer(name: nextName("Photo"), content: .image(ImageItem(image: normalized)))
        layer.scale = 0.7
        insertLayer(layer)
    }

    @discardableResult
    func addDrawingLayer() -> UUID {
        let layer = Layer(name: nextName("Dessin"), content: .drawing(DrawingItem()))
        insertLayer(layer)
        return layer.id
    }

    func addText() {
        let fontSize = max(canvasSize.width, canvasSize.height) * 0.07
        let item = TextItem(text: "Ton texte", fontSize: fontSize, color: .white)
        insertLayer(Layer(name: nextName("Texte"), content: .text(item)))
    }

    func addShape(_ kind: ShapeKind) {
        let base = min(canvasSize.width, canvasSize.height) * 0.4
        let size = kind.isLineLike
            ? CGSize(width: base * 1.3, height: base * 0.25)
            : CGSize(width: base, height: base)
        let strokeWidth = kind.isLineLike ? max(6, base * 0.05) : max(4, base * 0.03)
        let item = ShapeItem(kind: kind, size: size, fillColor: brushColor == .white ? .blue : brushColor,
                             strokeWidth: strokeWidth, cornerRadius: base * 0.15)
        insertLayer(Layer(name: nextName(kind.title), content: .shape(item)))
    }

    /// Ajoute un fond uni sous tous les calques (pratique après un détourage).
    func addSolidBackground(_ color: Color) {
        registerUndo()
        let image = ImageProcessor.solidImage(color: UIColor(color), size: canvasSize)
        let layer = Layer(name: nextName("Fond uni"), content: .image(ImageItem(image: image)))
        layers.insert(layer, at: 0)
    }

    func duplicateSelected() {
        guard let i = selectedIndex else { return }
        registerUndo()
        var copy = layers[i]
        copy.id = UUID()
        copy.name += " copie"
        copy.offset.width += canvasSize.width * 0.03
        copy.offset.height += canvasSize.width * 0.03
        layers.insert(copy, at: i + 1)
        selectedLayerID = copy.id
    }

    func deleteSelected() {
        guard let i = selectedIndex else { return }
        guard layers.count > 1 else {
            alertMessage = "Le projet doit garder au moins un calque."
            return
        }
        registerUndo()
        layers.remove(at: i)
        selectedLayerID = layers[max(i - 1, 0)].id
    }

    func moveSelected(up: Bool) {
        guard let i = selectedIndex else { return }
        let target = up ? i + 1 : i - 1
        guard layers.indices.contains(target) else { return }
        registerUndo()
        layers.swapAt(i, target)
    }

    func toggleVisibility(_ id: UUID) {
        guard let i = index(of: id) else { return }
        registerUndo()
        layers[i].isVisible.toggle()
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = index(of: id), !name.isEmpty else { return }
        registerUndo()
        layers[i].name = name
    }

    // MARK: - Rendu des photos (réglages / filtres)

    /// Lance le rendu d'un calque photo. Un seul rendu à la fois par calque :
    /// si les réglages ont changé entre-temps, un nouveau rendu est lancé à la fin.
    private func scheduleRender(layerID: UUID) {
        guard let i = index(of: layerID), case .image(var item) = layers[i].content else { return }

        if !item.needsProcessing {
            item.rendered = item.original
            item.renderedKey = item.settingsKey
            layers[i].content = .image(item)
            return
        }
        guard item.renderedKey != item.settingsKey, !renderingLayers.contains(layerID) else { return }

        renderingLayers.insert(layerID)
        let snapshot = item
        Task { [weak self] in
            let rendered = await Task.detached(priority: .userInitiated) {
                ImageProcessor.render(snapshot)
            }.value
            guard let self else { return }
            self.renderingLayers.remove(layerID)
            self.applyRendered(rendered, to: layerID, key: snapshot.settingsKey)
            self.scheduleRender(layerID: layerID)
        }
    }

    private func applyRendered(_ image: UIImage, to layerID: UUID, key: RenderKey) {
        guard let i = index(of: layerID), case .image(var item) = layers[i].content,
              key.original == ObjectIdentifier(item.original) else { return }
        item.rendered = image
        item.renderedKey = key
        layers[i].content = .image(item)
    }

    /// Remplace l'image source du calque sélectionné (recadrage, rotation).
    func replaceSelectedOriginal(with image: UIImage) {
        guard let i = selectedIndex, case .image(var item) = layers[i].content else { return }
        registerUndo()
        item.original = image
        item.rendered = image
        item.renderedKey = nil
        item.eraseStrokes = []
        layers[i].content = .image(item)
        if i == 0 {
            // Le calque du fond définit la taille de la toile.
            canvasSize = image.size
            layers[i].offset = .zero
            layers[i].scale = 1
            layers[i].rotation = .zero
        }
        scheduleRender(layerID: layers[i].id)
    }

    // MARK: - Détourage

    func removeBackground(asNewLayer: Bool) async {
        guard let i = selectedIndex, case .image(let item) = layers[i].content else {
            alertMessage = "Sélectionne d’abord un calque photo."
            return
        }
        let layerID = layers[i].id
        processingMessage = "Détourage en cours…"
        isProcessing = true
        defer { isProcessing = false }

        do {
            let cutout = try await BackgroundRemover.removeBackground(from: item.original)
            guard let idx = index(of: layerID), case .image(var current) = layers[idx].content else { return }
            registerUndo()
            current.original = cutout
            current.rendered = cutout
            current.renderedKey = nil

            if asNewLayer {
                var newLayer = layers[idx]
                newLayer.id = UUID()
                newLayer.name = "Sujet détouré"
                newLayer.content = .image(current)
                layers.insert(newLayer, at: idx + 1)
                selectedLayerID = newLayer.id
                scheduleRender(layerID: newLayer.id)
            } else {
                layers[idx].content = .image(current)
                scheduleRender(layerID: layerID)
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    // MARK: - Pinceau et gomme

    /// `canvasPoint` est en pixels de la toile ; `displayScale` = taille affichée / taille réelle.
    func strokeChanged(at canvasPoint: CGPoint, displayScale: CGFloat) {
        if isStroking {
            continueStroke(to: canvasPoint)
        } else {
            isStroking = true
            beginStroke(at: canvasPoint, displayScale: displayScale)
        }
    }

    private func beginStroke(at canvasPoint: CGPoint, displayScale: CGFloat) {
        strokeCreatedLayer = false
        var target = selectedLayer
        let erasing = tool == .eraser

        if erasing {
            guard let layer = target, layer.drawingItem != nil || layer.imageItem != nil else {
                alertMessage = "La gomme fonctionne sur un calque photo ou dessin. Sélectionne-en un dans « Calques »."
                return
            }
        } else if target?.drawingItem == nil {
            let id = addDrawingLayer()
            target = layers.first { $0.id == id }
            strokeCreatedLayer = true
        }
        guard let layer = target else { return }

        let point = layer.layerPoint(fromCanvas: canvasPoint, canvasSize: canvasSize)
        let isImage = layer.imageItem != nil
        let width = brushWidth / max(displayScale, 0.01) / max(layer.scale, 0.01)
        liveStroke = Stroke(points: [point],
                            color: isImage ? .black : brushColor,
                            width: width,
                            isEraser: erasing && !isImage)
        liveStrokeLayerID = layer.id
    }

    private func continueStroke(to canvasPoint: CGPoint) {
        guard var stroke = liveStroke, let id = liveStrokeLayerID,
              let layer = layers.first(where: { $0.id == id }) else { return }
        let point = layer.layerPoint(fromCanvas: canvasPoint, canvasSize: canvasSize)
        if let last = stroke.points.last, hypot(point.x - last.x, point.y - last.y) < 1 { return }
        stroke.points.append(point)
        liveStroke = stroke
    }

    func endStroke() {
        defer {
            isStroking = false
            liveStroke = nil
            liveStrokeLayerID = nil
        }
        guard let stroke = liveStroke, let id = liveStrokeLayerID, let i = index(of: id) else { return }
        if !strokeCreatedLayer { registerUndo() }

        switch layers[i].content {
        case .drawing(var drawing):
            drawing.strokes.append(stroke)
            layers[i].content = .drawing(drawing)
        case .image(var item):
            item.eraseStrokes.append(stroke)
            layers[i].content = .image(item)
        default:
            break
        }
    }

    // MARK: - Déplacer / redimensionner / tourner

    func updateTransform(_ gesture: TransformGesture, translation: CGSize = .zero,
                         magnification: CGFloat = 1, rotation: Angle = .zero) {
        guard let i = selectedIndex else { return }
        if transformBase?.id != layers[i].id {
            registerUndo()
            transformBase = layers[i]
            activeTransforms.removeAll()
            dragDelta = .zero
            magnifyDelta = 1
            rotateDelta = .zero
        }
        activeTransforms.insert(gesture)
        switch gesture {
        case .drag: dragDelta = translation
        case .magnify: magnifyDelta = magnification
        case .rotate: rotateDelta = rotation
        }
        guard let base = transformBase else { return }
        layers[i].offset = CGSize(width: base.offset.width + dragDelta.width,
                                  height: base.offset.height + dragDelta.height)
        layers[i].scale = min(max(base.scale * magnifyDelta, 0.05), 20)
        layers[i].rotation = .radians(base.rotation.radians + rotateDelta.radians)
    }

    func endTransform(_ gesture: TransformGesture) {
        activeTransforms.remove(gesture)
        if activeTransforms.isEmpty { resetTransformState() }
    }

    private func resetTransformState() {
        transformBase = nil
        activeTransforms.removeAll()
        dragDelta = .zero
        magnifyDelta = 1
        rotateDelta = .zero
    }

    // MARK: - Export

    func renderFinalImage() -> UIImage? {
        let content = CanvasContent(layers: layers, canvasSize: canvasSize, scale: 1,
                                    showsTransparencyGrid: false)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.uiImage
    }
}
