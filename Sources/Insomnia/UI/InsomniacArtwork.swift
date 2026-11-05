import CoreGraphics

/// Approved Paper artwork on a shared 24-unit, y-down grid.
enum InsomniacArtwork {
    static let stroke: CGFloat = 1
    static func map(_ path: CGPath, to rect: CGRect) -> CGPath {
        var t = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width / 24, y: rect.height / 24)
        return path.copy(using: &t)!
    }
    static func outline(running: Bool, in rect: CGRect) -> CGPath {
        aperture(openness: running ? 1 : 0, closure: 0, in: rect)
    }

    /// Eye Study 02: interpolate only the upper lid. The lower two curves
    /// remain identical from idle through blinking to fully awake.
    static func aperture(openness: CGFloat, closure: CGFloat, in rect: CGRect) -> CGPath {
        let open = min(max(openness, 0), 1)
        let shut = min(max(closure, 0), 1)
        func point(_ idle: CGPoint, _ awake: CGPoint, _ closed: CGPoint) -> CGPoint {
            let x = idle.x + (awake.x - idle.x) * open
            let y = idle.y + (awake.y - idle.y) * open
            return CGPoint(x: x + (closed.x - x) * shut, y: y + (closed.y - y) * shut)
        }
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 3, y: 12))
        p.addCurve(to: point(CGPoint(x: 12, y: 10.5), CGPoint(x: 12, y: 3), CGPoint(x: 12, y: 21)),
                   control1: point(CGPoint(x: 6, y: 10.5), CGPoint(x: 3, y: 7), CGPoint(x: 3, y: 17)),
                   control2: point(CGPoint(x: 9, y: 10.5), CGPoint(x: 7, y: 3), CGPoint(x: 7, y: 21)))
        p.addCurve(to: CGPoint(x: 21, y: 12),
                   control1: point(CGPoint(x: 15, y: 10.5), CGPoint(x: 17, y: 3), CGPoint(x: 17, y: 21)),
                   control2: point(CGPoint(x: 18, y: 10.5), CGPoint(x: 21, y: 7), CGPoint(x: 21, y: 17)))
        p.addCurve(to: CGPoint(x: 12, y: 21), control1: CGPoint(x: 21, y: 17), control2: CGPoint(x: 17, y: 21))
        p.addCurve(to: CGPoint(x: 3, y: 12), control1: CGPoint(x: 7, y: 21), control2: CGPoint(x: 3, y: 17))
        p.closeSubpath()
        return map(p, to: rect)
    }
    static func polygon(_ points: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        guard let first = points.first else { return p }
        p.move(to: first); for point in points.dropFirst() { p.addLine(to: point) }
        p.closeSubpath(); return p
    }
    static func pupil(running: Bool, offset: CGPoint = .zero, in rect: CGRect) -> CGPath {
        let p = CGMutablePath()
        p.addEllipse(in: CGRect(x: 9.375 + offset.x, y: 9.375 + offset.y, width: 5.25, height: 5.25))
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

