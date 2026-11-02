import SwiftUI

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct StarShape: Shape {
    var points: Int
    var innerRatio: CGFloat = 0.45

    func path(in rect: CGRect) -> Path {
        let count = max(points, 3)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for index in 0..<(count * 2) {
            let angle = Double(index) * .pi / Double(count) - .pi / 2
            let radius: CGFloat = index.isMultiple(of: 2) ? 1 : innerRatio
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * rect.width / 2 * radius,
                                y: center.y + CGFloat(sin(angle)) * rect.height / 2 * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct PolygonShape: Shape {
    var sides: Int

    func path(in rect: CGRect) -> Path {
        let count = max(sides, 3)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) * 2 * .pi / Double(count) - .pi / 2
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * rect.width / 2,
                                y: center.y + CGFloat(sin(angle)) * rect.height / 2)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: p(0.5, 1.0))
        path.addCurve(to: p(0.0, 0.35), control1: p(0.15, 0.8), control2: p(0.0, 0.6))
        path.addCurve(to: p(0.5, 0.2), control1: p(0.0, 0.05), control2: p(0.4, 0.0))
        path.addCurve(to: p(1.0, 0.35), control1: p(0.6, 0.0), control2: p(1.0, 0.05))
        path.addCurve(to: p(0.5, 1.0), control1: p(1.0, 0.6), control2: p(0.85, 0.8))
        path.closeSubpath()
        return path
    }
}

struct LineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let headLength = min(rect.width * 0.3, max(rect.height, 20))
        let headHalfHeight = rect.height / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.move(to: CGPoint(x: rect.maxX - headLength, y: rect.midY - headHalfHeight))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - headLength, y: rect.midY + headHalfHeight))
        return path
    }
}

extension ShapeItem {
    func makeShape(scale: CGFloat = 1) -> AnyShape {
        switch kind {
        case .rectangle: AnyShape(Rectangle())
        case .roundedRectangle: AnyShape(RoundedRectangle(cornerRadius: cornerRadius * scale, style: .continuous))
        case .ellipse: AnyShape(Ellipse())
        case .triangle: AnyShape(TriangleShape())
        case .star: AnyShape(StarShape(points: pointCount))
        case .polygon: AnyShape(PolygonShape(sides: pointCount))
        case .heart: AnyShape(HeartShape())
        case .line: AnyShape(LineShape())
        case .arrow: AnyShape(ArrowShape())
        }
    }
}
