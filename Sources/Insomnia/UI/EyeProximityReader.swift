import AppKit
import SwiftUI

/// Mouse-only observers do no work while the pointer is stationary. A short,
/// critically damped settle timer exists only while the pupil is moving.
struct EyeProximityReader: NSViewRepresentable {
    let enabled: Bool
    let running: Bool
    let changed: (CGPoint) -> Void
    func makeNSView(context: Context) -> Reader { Reader() }
    func updateNSView(_ view: Reader, context: Context) {
        view.changed = changed
        view.running = running
        view.enabled = enabled
        if !enabled { view.reset() }
    }
    static func dismantleNSView(_ view: Reader, coordinator: ()) { view.stop() }

    @MainActor final class Reader: NSView {
        var enabled = false
        var running = false
        var changed: ((CGPoint) -> Void)?
        private var global: Any?
        private var local: Any?
        private var timer: Timer?
        private var position = CGPoint.zero
        private var velocity = CGPoint.zero
        private var target = CGPoint.zero
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                MainActor.assumeIsolated { self?.sample() }
            }
            local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                MainActor.assumeIsolated { self?.sample() }
                return event
            }
        }
        func stop() {
            if let global { NSEvent.removeMonitor(global) }
            if let local { NSEvent.removeMonitor(local) }
            global = nil; local = nil; timer?.invalidate(); timer = nil
        }
        func reset() {
            guard position != .zero || target != .zero else { return }
            target = .zero; position = .zero; velocity = .zero
            timer?.invalidate(); timer = nil
            DispatchQueue.main.async { [weak self] in self?.changed?(.zero) }
        }
        private func sample() {
            guard enabled, let window, window.isVisible else { reset(); return }
            let box = window.convertToScreen(convert(bounds, to: nil))
            target = InsomniacArtwork.gaze(pointer: NSEvent.mouseLocation, center: CGPoint(x: box.midX, y: box.midY), running: running)
            guard target != position, timer == nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.step() }
            }
        }
        private func step() {
            guard enabled else { reset(); return }
            let dt: CGFloat = 1.0 / 60, stiffness: CGFloat = 400, damping: CGFloat = 40
            velocity.x += ((target.x - position.x) * stiffness - velocity.x * damping) * dt
            velocity.y += ((target.y - position.y) * stiffness - velocity.y * damping) * dt
            position.x += velocity.x * dt; position.y += velocity.y * dt
            if hypot(target.x - position.x, target.y - position.y) < 0.005 && hypot(velocity.x, velocity.y) < 0.05 {
                position = target; velocity = .zero; timer?.invalidate(); timer = nil
            }
            changed?(position)
        }
    }
}
