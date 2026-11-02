import SwiftUI
import UIKit

// MARK: - Réglages photo

struct Adjustments: Equatable {
    var brightness: Double = 0      // -0.5 … 0.5
    var contrast: Double = 1        // 0.5 … 1.5
    var saturation: Double = 1      // 0 … 2
    var exposure: Double = 0        // -2 … 2
    var temperature: Double = 0     // -1 (froid) … 1 (chaud)
    var sharpness: Double = 0       // 0 … 2
    var vignette: Double = 0        // 0 … 2

    var isNeutral: Bool { self == Adjustments() }
}

// MARK: - Filtres et esquisses

enum PhotoFilter: String, CaseIterable, Identifiable {
    case none
    case noir, mono, sepia, vintage, chrome, fade, instant, posterize, blur
    case pencil, coloredPencil, charcoal, outline, comic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Original"
        case .noir: "Noir"
        case .mono: "Mono"
        case .sepia: "Sépia"
        case .vintage: "Vintage"
        case .chrome: "Chrome"
        case .fade: "Délavé"
        case .instant: "Instant"
        case .posterize: "Pop"
        case .blur: "Flou"
        case .pencil: "Crayon"
        case .coloredPencil: "Crayons de couleur"
        case .charcoal: "Fusain"
        case .outline: "Contours"
        case .comic: "BD"
        }
    }

    var isSketch: Bool {
        switch self {
        case .pencil, .coloredPencil, .charcoal, .outline, .comic: true
        default: false
        }
    }

    /// Filtres classiques (onglet « Filtres »).
    static var photoFilters: [PhotoFilter] { allCases.filter { !$0.isSketch } }
    /// Styles d'esquisse (onglet « Esquisse »).
    static var sketchStyles: [PhotoFilter] { [.none] + allCases.filter(\.isSketch) }
}

// MARK: - Contenu des calques

struct Stroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var width: CGFloat
    /// Vrai pour la gomme sur un calque de dessin.
    var isEraser: Bool
}

/// Identifie les paramètres utilisés pour produire une image rendue.
struct RenderKey: Equatable {
    let original: ObjectIdentifier
    let adjustments: Adjustments
    let filter: PhotoFilter
    let intensity: Double
    let sketchDetail: Double
}

struct ImageItem {
    /// Image source, sans réglages ni filtre (modifiée par le recadrage et le détourage).
    var original: UIImage
    /// Image affichée, avec réglages et filtre appliqués.
    var rendered: UIImage
    var adjustments = Adjustments()
    var filter: PhotoFilter = .none
    var filterIntensity: Double = 1
    /// 0 = traits fins, 1 = traits épais (styles d'esquisse).
    var sketchDetail: Double = 0.5
    /// Coups de gomme appliqués sur la photo.
    var eraseStrokes: [Stroke] = []
    var renderedKey: RenderKey?

    init(image: UIImage) {
        original = image
        rendered = image
        renderedKey = settingsKey
    }

    var settingsKey: RenderKey {
        RenderKey(original: ObjectIdentifier(original), adjustments: adjustments,
                  filter: filter, intensity: filterIntensity, sketchDetail: sketchDetail)
    }

    var needsProcessing: Bool { !adjustments.isNeutral || filter != .none }
}

struct DrawingItem {
    var strokes: [Stroke] = []
}

enum TextFontStyle: String, CaseIterable, Identifiable {
    case system, rounded, serif, mono
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Classique"
        case .rounded: "Arrondie"
        case .serif: "Serif"
        case .mono: "Machine"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .mono: .monospaced
        }
    }
}

struct TextItem {
    var text: String
    var fontSize: CGFloat = 64
    var color: Color = .white
    var fontStyle: TextFontStyle = .system
    var isBold = true
    var hasShadow = true
}

enum ShapeKind: String, CaseIterable, Identifiable {
    case rectangle, roundedRectangle, ellipse, triangle, star, polygon, heart, line, arrow
    var id: String { rawValue }

    var title: String {
        switch self {
        case .rectangle: "Rectangle"
        case .roundedRectangle: "Arrondi"
        case .ellipse: "Ellipse"
        case .triangle: "Triangle"
        case .star: "Étoile"
        case .polygon: "Polygone"
        case .heart: "Cœur"
        case .line: "Ligne"
        case .arrow: "Flèche"
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle: "rectangle"
        case .roundedRectangle: "app"
        case .ellipse: "circle"
        case .triangle: "triangle"
        case .star: "star"
        case .polygon: "hexagon"
        case .heart: "heart"
        case .line: "line.diagonal"
        case .arrow: "arrow.right"
        }
    }

    /// Les lignes et flèches n'ont qu'un trait, pas de remplissage.
    var isLineLike: Bool { self == .line || self == .arrow }
    var hasPointCount: Bool { self == .star || self == .polygon }
}

struct ShapeItem {
    var kind: ShapeKind
    var size: CGSize
    var fillColor: Color
    var strokeColor: Color = .white
    var strokeWidth: CGFloat = 8
    var isFilled = true
    var hasStroke = false
    var cornerRadius: CGFloat = 40
    var pointCount: Int = 5
}

enum LayerContent {
    case image(ImageItem)
    case drawing(DrawingItem)
    case text(TextItem)
    case shape(ShapeItem)
}

// MARK: - Mode de fusion

enum LayerBlendMode: String, CaseIterable, Identifiable {
    case normal, multiply, screen, overlay, softLight, hardLight, darken, lighten
    case colorDodge, colorBurn, difference, luminosity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .multiply: "Produit"
        case .screen: "Superposition claire"
        case .overlay: "Incrustation"
        case .softLight: "Lumière douce"
        case .hardLight: "Lumière crue"
        case .darken: "Obscurcir"
        case .lighten: "Éclaircir"
        case .colorDodge: "Densité couleur −"
        case .colorBurn: "Densité couleur +"
        case .difference: "Différence"
        case .luminosity: "Luminosité"
        }
    }

    var swiftUI: BlendMode {
        switch self {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .softLight: .softLight
        case .hardLight: .hardLight
        case .darken: .darken
        case .lighten: .lighten
        case .colorDodge: .colorDodge
        case .colorBurn: .colorBurn
        case .difference: .difference
        case .luminosity: .luminosity
        }
    }
}

// MARK: - Calque

struct Layer: Identifiable {
    var id = UUID()
    var name: String
    var content: LayerContent
    var opacity: Double = 1
    var isVisible = true
    var blendMode: LayerBlendMode = .normal
    /// Décalage du centre du calque par rapport au centre de la toile (en pixels de la toile).
    var offset: CGSize = .zero
    var scale: CGFloat = 1
    var rotation: Angle = .zero

    var systemImage: String {
        switch content {
        case .image: "photo"
        case .drawing: "scribble"
        case .text: "textformat"
        case .shape(let shape): shape.kind.systemImage
        }
    }

    var imageItem: ImageItem? {
        if case .image(let item) = content { return item }
        return nil
    }

    var drawingItem: DrawingItem? {
        if case .drawing(let item) = content { return item }
        return nil
    }

    var textItem: TextItem? {
        if case .text(let item) = content { return item }
        return nil
    }

    var shapeItem: ShapeItem? {
        if case .shape(let item) = content { return item }
        return nil
    }

    /// Convertit un point de la toile dans le repère non transformé du calque
    /// (utile pour peindre sur un calque déplacé, agrandi ou tourné).
    func layerPoint(fromCanvas point: CGPoint, canvasSize: CGSize) -> CGPoint {
        let center = CGPoint(x: canvasSize.width / 2 + offset.width,
                             y: canvasSize.height / 2 + offset.height)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let angle = CGFloat(-rotation.radians)
        let rx = dx * cos(angle) - dy * sin(angle)
        let ry = dx * sin(angle) + dy * cos(angle)
        let s = max(scale, 0.01)
        return CGPoint(x: rx / s + canvasSize.width / 2, y: ry / s + canvasSize.height / 2)
    }
}
