import Foundation

/// Once cancelled, a drag cannot re-enter and accidentally end the session.
struct EndClickTracking {
    private var origin: CGPoint?
    private var cancelled = false
    var isTracking: Bool { origin != nil }

    static func contains(_ point: CGPoint, in bounds: CGRect) -> Bool {
        guard bounds.width >= 30, bounds.height > 0, point.x.isFinite, point.y.isFinite else { return false }
        return point.x >= bounds.maxX - 30 && point.x <= bounds.maxX &&
            point.y >= bounds.minY && point.y <= bounds.maxY
    }

    mutating func begin(at point: CGPoint) { origin = point; cancelled = false }
    mutating func drag(to point: CGPoint) {
        guard let origin else { return }
        if hypot(point.x - origin.x, point.y - origin.y) > 12 { cancelled = true }
    }
    mutating func finish(at point: CGPoint, inside: Bool) -> Bool {
        guard origin != nil else { return false }
        drag(to: point)
        let fire = inside && !cancelled
        origin = nil
        cancelled = false
        return fire
    }
}
