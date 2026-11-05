import SwiftUI

/// The almond lens on its own, for stroking.
struct EyeLens: Shape {
    func path(in rect: CGRect) -> Path {
        Path(EyeMarkGeometry.lens(in: rect))
    }
}

/// The lid that shades the lens, for filling: nothing at 1, the whole lens at 0.
struct EyeLid: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path(EyeMarkGeometry.lid(in: rect, progress: progress))
    }
}

/// The five lashes on one side of the lens, for stroking. They never move.
struct EyeLashes: Shape {
    let side: EyeMarkGeometry.Side

    func path(in rect: CGRect) -> Path {
        Path(EyeMarkGeometry.lashes(in: rect, side: side))
    }
}

/// Fades one set of lashes with the blink: the lower set is gone by half
/// way, the upper set only starts to show from there, so no lash is ever
/// seen while the lid edge passes its side of the lens. Animatable so the
/// timing follows the lid's own progress rather than a plain crossfade.
nonisolated struct EyeLashFade: ViewModifier, Animatable {
    var progress: CGFloat
    let side: EyeMarkGeometry.Side

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var opacity: CGFloat {
        let x = side == .above ? (progress - 0.5) * 2 : 1 - progress * 2
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    func body(content: Content) -> some View {
        content.opacity(opacity)
    }
}

/// The pupil with its highlight bitten out, for filling.
struct EyePupil: Shape {
    func path(in rect: CGRect) -> Path {
        Path(EyeMarkGeometry.pupil(in: rect))
    }
}

/// The pupil as the blink draws it: scaled about its own centre and faded,
/// then clipped to the lens outline, so neither the opening spring's
/// overshoot nor a blink interrupted at its peak can show it outside the
/// lens. The highlight bite is part of the same path, so it is clipped too.
struct EyePupilLayer: View {
    var scale: CGFloat
    var opacity: CGFloat

    /// The pupil's centre as a fraction of the (square) mark.
    static let anchor = UnitPoint(
        x: EyeMarkGeometry.pupilCenter.x / EyeMarkGeometry.designSize,
        y: EyeMarkGeometry.pupilCenter.y / EyeMarkGeometry.designSize
    )

    var body: some View {
        EyePupil()
            .fill(.black)
            .scaleEffect(scale, anchor: Self.anchor)
            .opacity(opacity)
            .clipShape(EyeLens())
    }
}

/// Shared approved eye artwork, with a bounded pupil offset near the cursor.
/// Native foreground styling follows the light or dark menu bar.
struct EyeMarkView: View {
    let progress: CGFloat
    let reduceMotion: Bool
    var size: CGFloat = 18
    var trackingEnabled = false
    @State private var gaze = CGPoint.zero

    init(isRunning: Bool, reduceMotion: Bool, size: CGFloat = 18, trackingEnabled: Bool = false) {
        progress = isRunning ? 1 : 0
        self.reduceMotion = reduceMotion; self.size = size; self.trackingEnabled = trackingEnabled
    }
    init(progress: CGFloat, reduceMotion: Bool = true, size: CGFloat = 18) {
        self.progress = progress; self.reduceMotion = reduceMotion; self.size = size
    }
    static func stroke(size: CGFloat) -> StrokeStyle { StrokeStyle(lineWidth: size / 24, lineCap: .round, lineJoin: .round) }
    var pupilScale: CGFloat { 1 }
    var pupilOpacity: CGFloat { 1 }

    var body: some View {
        Canvas { context, dimensions in
            let rect = CGRect(origin: .zero, size: dimensions)
            let running = progress > 0.5
            let outline = Path(InsomniacArtwork.outline(running: running, in: rect))
            var pupilContext = context
            pupilContext.clip(to: outline)
            pupilContext.fill(Path(InsomniacArtwork.pupil(running: running, offset: reduceMotion || !trackingEnabled ? .zero : gaze, in: rect)), with: .foreground)
            context.stroke(outline, with: .foreground, style: Self.stroke(size: size))
            context.fill(Path(running ? InsomniacArtwork.veins(in: rect) : InsomniacArtwork.brow(in: rect)), with: .foreground)
        }
        .foregroundStyle(.primary)
        .frame(width: size, height: size)
        .onChange(of: trackingEnabled) { if !trackingEnabled { gaze = .zero } }
        .onChange(of: reduceMotion) { if reduceMotion { gaze = .zero } }
        .background {
            if trackingEnabled && !reduceMotion {
                EyeProximityReader(enabled: true, running: progress > 0.5) { target in
                    gaze = target
                }
            }
        }
    }
}
