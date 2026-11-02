import SwiftUI

enum CropAspect: String, CaseIterable, Identifiable {
    case free, original, square, fourThree, threeFour, sixteenNine, nineSixteen
    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: "Libre"
        case .original: "Original"
        case .square: "1:1"
        case .fourThree: "4:3"
        case .threeFour: "3:4"
        case .sixteenNine: "16:9"
        case .nineSixteen: "9:16"
        }
    }

    /// Rapport largeur / hauteur, ou nil si libre.
    func ratio(for size: CGSize) -> CGFloat? {
        switch self {
        case .free: nil
        case .original: size.width / max(size.height, 1)
        case .square: 1
        case .fourThree: 4.0 / 3.0
        case .threeFour: 3.0 / 4.0
        case .sixteenNine: 16.0 / 9.0
        case .nineSixteen: 9.0 / 16.0
        }
    }
}

struct CropView: View {
    let onApply: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var working: UIImage
    /// Zone de recadrage normalisée (0…1).
    @State private var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var aspect: CropAspect = .free
    @State private var modified = false

    init(image: UIImage, onApply: @escaping (UIImage) -> Void) {
        _working = State(initialValue: image)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GeometryReader { geo in
                    let fitted = fittedSize(working.size, in: CGSize(width: geo.size.width - 40, height: geo.size.height - 40))
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: working)
                            .resizable()
                            .frame(width: fitted.width, height: fitted.height)
                        CropOverlay(normalizedRect: $cropRect, size: fitted, aspectRatio: aspect.ratio(for: working.size))
                    }
                    .frame(width: fitted.width, height: fitted.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CropAspect.allCases) { option in
                            Button(option.title) { aspect = option }
                                .buttonStyle(.bordered)
                                .tint(aspect == option ? Color.accentColor : Color.gray)
                        }
                    }
                    .padding(.horizontal)
                }

                HStack(spacing: 36) {
                    toolButton("Gauche", systemImage: "rotate.left") {
                        working = ImageProcessor.rotated(working, clockwise: false)
                    }
                    toolButton("Droite", systemImage: "rotate.right") {
                        working = ImageProcessor.rotated(working, clockwise: true)
                    }
                    toolButton("Miroir", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                        working = ImageProcessor.flippedHorizontally(working)
                    }
                }
                .padding(.bottom, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Recadrer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        let isFullRect = cropRect.equalTo(CGRect(x: 0, y: 0, width: 1, height: 1))
                        if modified || !isFullRect {
                            onApply(isFullRect ? working : ImageProcessor.cropped(working, normalizedRect: cropRect))
                        }
                        dismiss()
                    }
                    .bold()
                }
            }
            .onChange(of: aspect) { _, newAspect in
                cropRect = maximalRect(for: newAspect.ratio(for: working.size))
            }
        }
        .preferredColorScheme(.dark)
    }

    private func toolButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            modified = true
            cropRect = maximalRect(for: aspect.ratio(for: working.size))
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.title2)
                Text(title).font(.caption)
            }
        }
        .foregroundStyle(.white)
    }

    private func fittedSize(_ size: CGSize, in bounds: CGSize) -> CGSize {
        let factor = min(max(bounds.width, 1) / max(size.width, 1), max(bounds.height, 1) / max(size.height, 1))
        return CGSize(width: size.width * factor, height: size.height * factor)
    }

    /// Plus grand rectangle centré respectant le rapport demandé.
    private func maximalRect(for ratio: CGFloat?) -> CGRect {
        guard let ratio else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let imageRatio = working.size.width / max(working.size.height, 1)
        let relative = ratio / imageRatio
        let width: CGFloat = relative >= 1 ? 1 : relative
        let height: CGFloat = relative >= 1 ? 1 / relative : 1
        return CGRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
    }
}

private struct CropOverlay: View {
    enum Corner: CaseIterable, Identifiable {
        case topLeft, topRight, bottomLeft, bottomRight
        var id: Self { self }
        var isTop: Bool { self == .topLeft || self == .topRight }
        var isLeft: Bool { self == .topLeft || self == .bottomLeft }

        func point(in rect: CGRect) -> CGPoint {
            CGPoint(x: isLeft ? rect.minX : rect.maxX, y: isTop ? rect.minY : rect.maxY)
        }
    }

    @Binding var normalizedRect: CGRect
    let size: CGSize
    let aspectRatio: CGFloat?
    @State private var startRect: CGRect?

    private let minSide: CGFloat = 40

    private var rect: CGRect {
        CGRect(x: normalizedRect.minX * size.width, y: normalizedRect.minY * size.height,
               width: normalizedRect.width * size.width, height: normalizedRect.height * size.height)
    }

    var body: some View {
        let r = rect
        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                path.addRect(r)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            Path { path in
                for i in 1...2 {
                    let x = r.minX + r.width * CGFloat(i) / 3
                    let y = r.minY + r.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: r.minY))
                    path.addLine(to: CGPoint(x: x, y: r.maxY))
                    path.move(to: CGPoint(x: r.minX, y: y))
                    path.addLine(to: CGPoint(x: r.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            .allowsHitTesting(false)

            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: r.width, height: r.height)
                .position(x: r.midX, y: r.midY)
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .frame(width: r.width, height: r.height)
                .position(x: r.midX, y: r.midY)
                .gesture(moveGesture)

            ForEach(Corner.allCases) { corner in
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .padding(12)
                    .contentShape(Rectangle())
                    .position(corner.point(in: r))
                    .gesture(resizeGesture(corner))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let start = startRect ?? rect
                if startRect == nil { startRect = start }
                var moved = start.offsetBy(dx: value.translation.width, dy: value.translation.height)
                moved.origin.x = min(max(moved.origin.x, 0), size.width - moved.width)
                moved.origin.y = min(max(moved.origin.y, 0), size.height - moved.height)
                setRect(moved)
            }
            .onEnded { _ in startRect = nil }
    }

    private func resizeGesture(_ corner: Corner) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = startRect ?? rect
                if startRect == nil { startRect = start }
                if let resized = resized(start, corner: corner, by: value.translation) {
                    setRect(resized)
                }
            }
            .onEnded { _ in startRect = nil }
    }

    private func resized(_ start: CGRect, corner: Corner, by t: CGSize) -> CGRect? {
        var minX = start.minX, minY = start.minY, maxX = start.maxX, maxY = start.maxY
        switch corner {
        case .topLeft: minX += t.width; minY += t.height
        case .topRight: maxX += t.width; minY += t.height
        case .bottomLeft: minX += t.width; maxY += t.height
        case .bottomRight: maxX += t.width; maxY += t.height
        }
        minX = max(minX, 0)
        minY = max(minY, 0)
        maxX = min(maxX, size.width)
        maxY = min(maxY, size.height)

        var width = maxX - minX
        var height = maxY - minY
        guard width >= minSide, height >= minSide else { return nil }

        if let ratio = aspectRatio {
            height = width / ratio
            if corner.isTop {
                if maxY - height < 0 {
                    height = maxY
                    width = height * ratio
                }
                minY = maxY - height
            } else {
                if minY + height > size.height {
                    height = size.height - minY
                    width = height * ratio
                }
            }
            if corner.isLeft { minX = maxX - width }
            guard width >= minSide / 2, height >= minSide / 2 else { return nil }
        }
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    private func setRect(_ r: CGRect) {
        normalizedRect = CGRect(x: r.minX / size.width, y: r.minY / size.height,
                                width: r.width / size.width, height: r.height / size.height)
    }
}
