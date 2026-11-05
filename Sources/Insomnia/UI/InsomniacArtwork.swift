import CoreGraphics

/// Approved Paper artwork on a shared 24-unit, y-down grid.
enum InsomniacArtwork {
    static let stroke: CGFloat = 1
    static func map(_ path: CGPath, to rect: CGRect) -> CGPath {
        var t = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width / 24, y: rect.height / 24)
        return path.copy(using: &t)!
    }
    static func outline(running: Bool, in rect: CGRect) -> CGPath {
        let p = CGMutablePath()
        if running {
            p.move(to: CGPoint(x: 12, y: 3))
            p.addCurve(to: CGPoint(x: 21, y: 12), control1: CGPoint(x: 17, y: 3), control2: CGPoint(x: 21, y: 7))
            p.addCurve(to: CGPoint(x: 12, y: 21), control1: CGPoint(x: 21, y: 17), control2: CGPoint(x: 17, y: 21))
            p.addCurve(to: CGPoint(x: 3, y: 12), control1: CGPoint(x: 7, y: 21), control2: CGPoint(x: 3, y: 17))
            p.addCurve(to: CGPoint(x: 12, y: 3), control1: CGPoint(x: 3, y: 7), control2: CGPoint(x: 7, y: 3))
        } else {
            p.move(to: CGPoint(x: 3, y: 10))
            p.addCurve(to: CGPoint(x: 21, y: 10), control1: CGPoint(x: 8, y: 9.5), control2: CGPoint(x: 16, y: 9.5))
            p.addCurve(to: CGPoint(x: 12, y: 20), control1: CGPoint(x: 21, y: 16), control2: CGPoint(x: 17, y: 20))
            p.addCurve(to: CGPoint(x: 3, y: 10), control1: CGPoint(x: 7, y: 20), control2: CGPoint(x: 3, y: 16))
        }
        p.closeSubpath()
        return map(p, to: rect)
    }
    static func polygon(_ points: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        guard let first = points.first else { return p }
        p.move(to: first); for point in points.dropFirst() { p.addLine(to: point) }
        p.closeSubpath(); return p
    }
    static func brow(in rect: CGRect) -> CGPath {
        map(polygon([CGPoint(x: 2, y: 6.625), CGPoint(x: 12, y: 5), CGPoint(x: 22, y: 6.625), CGPoint(x: 22, y: 8.625), CGPoint(x: 12, y: 7.25), CGPoint(x: 2, y: 8.625)]), to: rect)
    }
    static func pupil(running: Bool, offset: CGPoint = .zero, in rect: CGRect) -> CGPath {
        let p = CGMutablePath()
        if running {
            p.addEllipse(in: CGRect(x: 9.375 + offset.x, y: 9.375 + offset.y, width: 5.25, height: 5.25))
        } else {
            let rx: CGFloat = 4.05, ry: CGFloat = 3.802
            let dy = sqrt(1 - pow(3.745 / rx, 2))
            let cy = 10 + ry * dy
            let start = atan2(-dy, -3.745 / rx), end = atan2(-dy, 3.745 / rx)
            let t = CGAffineTransform(translationX: 12 + offset.x, y: cy).scaledBy(x: rx, y: ry)
            p.addArc(center: .zero, radius: 1, startAngle: start, endAngle: end - 2 * .pi, clockwise: true, transform: t)
            p.closeSubpath()
        }
        return map(p, to: rect)
    }
    static let branches: [[CGPoint]] = [
        [CGPoint(x: 3.858, y: 8.427), CGPoint(x: 6.076, y: 8.963), CGPoint(x: 6.75, y: 10.25), CGPoint(x: 6.75, y: 10.25), CGPoint(x: 6.424, y: 8.537), CGPoint(x: 4.142, y: 7.573)],
        [CGPoint(x: 6.444, y: 8.944), CGPoint(x: 7.25, y: 7.75), CGPoint(x: 7.25, y: 7.75), CGPoint(x: 6.056, y: 8.556)],
        [CGPoint(x: 8.067, y: 3.874), CGPoint(x: 8.783, y: 5.669), CGPoint(x: 10.25, y: 6), CGPoint(x: 10.25, y: 6), CGPoint(x: 9.217, y: 5.331), CGPoint(x: 8.933, y: 3.626)],
        [CGPoint(x: 15.098, y: 3.549), CGPoint(x: 14.75, y: 5.25), CGPoint(x: 14.75, y: 5.25), CGPoint(x: 15.902, y: 3.951)],
        [CGPoint(x: 19.626, y: 7.067), CGPoint(x: 17.828, y: 7.785), CGPoint(x: 17.25, y: 9.5), CGPoint(x: 17.25, y: 9.5), CGPoint(x: 18.172, y: 8.215), CGPoint(x: 19.874, y: 7.933)],
        [CGPoint(x: 18.194, y: 7.806), CGPoint(x: 17, y: 7), CGPoint(x: 17, y: 7), CGPoint(x: 17.806, y: 8.194)],
        [CGPoint(x: 20.624, y: 14.317), CGPoint(x: 18.701, y: 13.979), CGPoint(x: 17.75, y: 15.25), CGPoint(x: 17.75, y: 15.25), CGPoint(x: 18.799, y: 14.521), CGPoint(x: 20.376, y: 15.183)],
        [CGPoint(x: 16.447, y: 19.944), CGPoint(x: 15.991, y: 17.868), CGPoint(x: 14.5, y: 17.25), CGPoint(x: 14.5, y: 17.25), CGPoint(x: 15.509, y: 18.132), CGPoint(x: 15.553, y: 20.056)],
        [CGPoint(x: 7.874, y: 20), CGPoint(x: 8.5, y: 18.25), CGPoint(x: 8.5, y: 18.25), CGPoint(x: 7.126, y: 19.5)],
        [CGPoint(x: 3.609, y: 14.937), CGPoint(x: 5.438, y: 14.268), CGPoint(x: 6.75, y: 15.25), CGPoint(x: 6.75, y: 15.25), CGPoint(x: 5.562, y: 13.732), CGPoint(x: 3.391, y: 14.063)],
        [CGPoint(x: 5.736, y: 14.141), CGPoint(x: 6.25, y: 12.75), CGPoint(x: 6.25, y: 12.75), CGPoint(x: 5.264, y: 13.859)]
    ]
    static func veins(in rect: CGRect) -> CGPath {
        let p = CGMutablePath()
        for branch in branches { p.addPath(polygon(branch)) }
        return map(p, to: rect)
    }
    static func gaze(pointer: CGPoint, center: CGPoint, running: Bool) -> CGPoint {
        let dx = pointer.x - center.x, dy = pointer.y - center.y
        let distance = hypot(dx, dy)
        guard distance < 80, distance > 0 else { return .zero }
        // Fade the response to zero at the boundary; no abrupt enter/exit.
        let strength = min(distance / 18, 1) * min((80 - distance) / 20, 1)
        return CGPoint(x: dx / distance * 1.5 * strength, y: running ? -dy / distance * 1.5 * strength : 0)
    }
}

