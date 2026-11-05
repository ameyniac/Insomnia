import CoreGraphics
import Foundation

/// Approved Overlap icon. Uses exactly the same idle geometry as the menu bar.
enum AppIconArtwork {
    static let canvas: CGFloat = 1024
    static let tileInset: CGFloat = 100
    static let cornerShare: CGFloat = 56.0 / 256
    static let minimumStrokePixels: CGFloat = 0.5
    static let lashesFromPixels = 32 // Kept for the generator's existing API.
    static let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    static let markShare: CGFloat = 168.0 / 256
    static let mark = CGRect(x: 100 + 44 * 824.0 / 256, y: 100 + 38 * 824.0 / 256, width: 168 * 824.0 / 256, height: 168 * 824.0 / 256)
    static let markWithoutLashes = mark
    static func placement(lashes: Bool) -> CGRect { mark }
    static func inked(in rect: CGRect, lashes: Bool) -> CGRect {
        InsomniacArtwork.outline(running: false, in: rect).boundingBoxOfPath
            .insetBy(dx: -rect.width / 48, dy: -rect.width / 48)
            .union(InsomniacArtwork.brow(in: rect).boundingBoxOfPath)
    }
    static func petal(light: Bool) -> CGPath {
        let p = CGMutablePath()
        if light {
            p.move(to: CGPoint(x: 38, y: 34))
            p.addCurve(to: CGPoint(x: 220, y: 222), control1: CGPoint(x: 135, y: 13), control2: CGPoint(x: 222, y: 80))
            p.addCurve(to: CGPoint(x: 38, y: 34), control1: CGPoint(x: 119, y: 243), control2: CGPoint(x: 32, y: 177))
        } else {
            p.move(to: CGPoint(x: 218, y: 34))
            p.addCurve(to: CGPoint(x: 36, y: 222), control1: CGPoint(x: 121, y: 13), control2: CGPoint(x: 34, y: 80))
            p.addCurve(to: CGPoint(x: 218, y: 34), control1: CGPoint(x: 137, y: 243), control2: CGPoint(x: 224, y: 177))
        }
        p.closeSubpath()
        var t = CGAffineTransform(translationX: tile.minX, y: tile.minY).scaledBy(x: tile.width / 256, y: tile.height / 256)
        return p.copy(using: &t)!
    }
    static func render(pixels: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let scale = CGFloat(pixels) / canvas
        ctx.translateBy(x: 0, y: CGFloat(pixels)); ctx.scaleBy(x: scale, y: -scale)
        draw(in: ctx, scale: scale, lashes: false)
        return ctx.makeImage()
    }
    static func draw(in ctx: CGContext, scale: CGFloat, lashes: Bool) {
        ctx.setFillColor(BrandPalette.RGB(hex: 0x1645F5).cgColor)
        ctx.addPath(CGPath(roundedRect: tile, cornerWidth: tile.width * cornerShare, cornerHeight: tile.height * cornerShare, transform: nil)); ctx.fillPath()
        for (light, color) in [(true, UInt32(0x53A5FF)), (false, UInt32(0x0D28A6))] {
            ctx.setFillColor(BrandPalette.RGB(hex: color).cgColor); ctx.addPath(petal(light: light)); ctx.fillPath()
        }
        ctx.setFillColor(BrandPalette.RGB(hex: 0xFFFFFF).cgColor)
        ctx.addPath(InsomniacArtwork.pupil(running: false, in: mark)); ctx.fillPath()
        ctx.addPath(InsomniacArtwork.brow(in: mark)); ctx.fillPath()
        ctx.setStrokeColor(BrandPalette.RGB(hex: 0xFFFFFF).cgColor)
        ctx.setLineWidth(max(mark.width / 24, minimumStrokePixels / scale)); ctx.setLineCap(.round); ctx.setLineJoin(.round)
        ctx.addPath(InsomniacArtwork.outline(running: false, in: mark)); ctx.strokePath()
    }
    static func svg() -> String {
        let grid = CGRect(x: 0, y: 0, width: 24, height: 24)
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="112" height="112" viewBox="100 100 824 824" role="img" aria-labelledby="eo-title eo-desc">
          <title id="eo-title">Insomniac</title>
          <desc id="eo-desc">A white half-open eye over overlapping cobalt blue shapes.</desc>
          <rect x="100" y="100" width="824" height="824" rx="\(number(tile.width * cornerShare))" fill="#1645F5"/>
          <path d="\(pathData(petal(light: true)))" fill="#53A5FF"/>
          <path d="\(pathData(petal(light: false)))" fill="#0D28A6"/>
          <g transform="translate(\(number(mark.minX)) \(number(mark.minY))) scale(\(number(mark.width / 24)))">
            <path d="\(pathData(InsomniacArtwork.pupil(running: false, in: grid)))" fill="#FFFFFF"/>
            <path d="\(pathData(InsomniacArtwork.outline(running: false, in: grid)))" fill="none" stroke="#FFFFFF" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="\(pathData(InsomniacArtwork.brow(in: grid)))" fill="#FFFFFF"/>
          </g>
        </svg>

        """
    }
    static func pathData(_ path: CGPath) -> String {
        var commands: [String] = []
        var current = CGPoint.zero
        path.applyWithBlock { element in
            let p = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                commands.append("M\(point(p[0]))")
                current = p[0]
            case .addLineToPoint:
                // An arc starts with a line to its first point, which is a
                // zero-length segment when the path is already there.
                if hypot(p[0].x - current.x, p[0].y - current.y) > 0.00005 {
                    commands.append("L\(point(p[0]))")
                }
                current = p[0]
            case .addQuadCurveToPoint:
                commands.append("Q\(point(p[0])) \(point(p[1]))")
                current = p[1]
            case .addCurveToPoint:
                commands.append("C\(point(p[0])) \(point(p[1])) \(point(p[2]))")
                current = p[2]
            case .closeSubpath:
                commands.append("Z")
            @unknown default:
                break
            }
        }
        return commands.joined(separator: " ")
    }

    private static func point(_ p: CGPoint) -> String {
        "\(number(p.x)) \(number(p.y))"
    }

    /// Formats a number to four decimals and drops trailing zeros, so two
    /// runs write identical SVG bytes and a coordinate reads 12.5, not
    /// 12.5000.
    static func number(_ value: CGFloat) -> String {
        var text = String(format: "%.4f", Double(value))
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text == "-0" ? "0" : text
    }

    /// A palette colour as `#RRGGBB`.
    static func hex(_ rgb: BrandPalette.RGB) -> String {
        let channels = [rgb.red, rgb.green, rgb.blue].map { Int(($0 * 255).rounded()) }
        return "#" + channels.map { String(format: "%02X", $0) }.joined()
    }
}
