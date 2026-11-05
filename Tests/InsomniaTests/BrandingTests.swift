import CoreGraphics
import SwiftUI
import XCTest
@testable import Insomnia

/// Approved idle/running artwork and bounded, event-driven gaze.
final class BrandingTests: XCTestCase {
    let grid = CGRect(x: 0, y: 0, width: 24, height: 24)

    func testIdleOutlineHasNoMissingCornerAndPupilIsPartlyCovered() {
        let outline = InsomniacArtwork.outline(running: false, in: grid)
        XCTAssertTrue(AppIconArtwork.pathData(outline).hasSuffix("Z"))
        XCTAssertTrue(outline.contains(CGPoint(x: 12, y: 19)))
        XCTAssertFalse(outline.contains(CGPoint(x: 12, y: 8)))
        let pupil = InsomniacArtwork.pupil(running: false, in: grid)
        XCTAssertEqual(pupil.boundingBoxOfPath.minY, 10, accuracy: 0.001)
        XCTAssertEqual(pupil.boundingBoxOfPath.midX, 12, accuracy: 0.001)
        XCTAssertTrue(pupil.contains(CGPoint(x: 12, y: 14)))
        XCTAssertFalse(pupil.contains(CGPoint(x: 12, y: 9)))
    }

    func testGazeIsBoundedAndReturnsToCenterOutsideProximity() {
        for running in [false, true] {
            for x in stride(from: -100.0, through: 100, by: 2) {
                for y in stride(from: -100.0, through: 100, by: 2) {
                    let gaze = InsomniacArtwork.gaze(pointer: CGPoint(x: x, y: y), center: .zero, running: running)
                    XCTAssertLessThanOrEqual(hypot(gaze.x, gaze.y), 1.50001)
                    if hypot(x, y) >= 80 { XCTAssertEqual(gaze, .zero) }
                    if !running { XCTAssertEqual(gaze.y, 0) }
                }
            }
        }
        XCTAssertGreaterThan(InsomniacArtwork.gaze(pointer: CGPoint(x: 30, y: 0), center: .zero, running: true).x, 0)
        XCTAssertLessThan(InsomniacArtwork.gaze(pointer: CGPoint(x: 0, y: 30), center: .zero, running: true).y, 0)
    }

    func testRunningPupilRemainsInsideEyeAcrossItsTravel() {
        let outline = InsomniacArtwork.outline(running: true, in: grid)
        for x in [-1.5, 0, 1.5] {
            for y in [-1.5, 0, 1.5] {
                let box = InsomniacArtwork.pupil(running: true, offset: CGPoint(x: x, y: y), in: grid).boundingBoxOfPath
                XCTAssertTrue(outline.contains(CGPoint(x: box.minX, y: box.minY)))
                XCTAssertTrue(outline.contains(CGPoint(x: box.maxX, y: box.maxY)))
            }
        }
    }

    @MainActor func testBothStatesAreVisibleAndDistinctAtMenuBarScale() throws {
        for scheme: ColorScheme in [.light, .dark] {
            let idle = try Raster.render(EyeMarkView(isRunning: false, reduceMotion: true), scheme: scheme, scale: 2)
            let running = try Raster.render(EyeMarkView(isRunning: true, reduceMotion: true), scheme: scheme, scale: 2)
            XCTAssertEqual(idle.width, 36)
            XCTAssertGreaterThan(idle.count { $0.alpha > 0.2 }, 60)
            XCTAssertGreaterThan(running.count { $0.alpha > 0.2 }, 60)
            XCTAssertNotEqual(idle.count { $0.alpha > 0.5 }, running.count { $0.alpha > 0.5 })
        }
    }

    func testAppIconRetainsTransparentMarginsAndWhiteEyeAtAllSizes() throws {
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            let pixels = IconPixels(try XCTUnwrap(AppIconArtwork.render(pixels: size)))
            XCTAssertEqual(pixels.alpha(0, 0), 0)
            XCTAssertGreaterThan(pixels.alpha(size / 2, size / 2), 0.99)
            XCTAssertGreaterThan(pixels.luminance(size / 2, size / 2), size == 16 ? 0.7 : 0.8)
        }
    }
}

struct Raster {
    struct RGB: CustomStringConvertible {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        var luminance: CGFloat { 0.2126 * red + 0.7152 * green + 0.0722 * blue }
        var saturation: CGFloat {
            let hi = max(red, green, blue)
            let lo = min(red, green, blue)
            return hi == 0 ? 0 : (hi - lo) / hi
        }
        var description: String { "rgb(\(red), \(green), \(blue))" }
    }

    let width: Int
    let height: Int
    private let data: [UInt8]

    var total: Int { width * height }

    init(size: Int, draw: (CGContext) -> Void) {
        self.init(width: size, height: size) { ctx in
            // Design coordinates are y-down; CoreGraphics bitmaps are y-up.
            ctx.translateBy(x: 0, y: CGFloat(size))
            ctx.scaleBy(x: 1, y: -1)
            draw(ctx)
        }
    }

    private init(width: Int, height: Int, draw: (CGContext) -> Void) {
        self.width = width
        self.height = height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            draw(ctx)
        }
        data = bytes
    }

    /// Renders a SwiftUI view under `scheme` at `scale` into a bitmap whose
    /// (0,0) is the view's top-left.
    @MainActor
    static func render<V: View>(_ view: V, scheme: ColorScheme, scale: CGFloat) throws -> Raster {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, scheme))
        renderer.scale = scale
        let image = try XCTUnwrap(renderer.cgImage, "ImageRenderer produced no image")
        return Raster(width: image.width, height: image.height) { ctx in
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
    }

    private func offset(_ x: Int, _ y: Int) -> Int {
        precondition(x >= 0 && x < width && y >= 0 && y < height, "pixel (\(x), \(y)) outside \(width)x\(height)")
        return (y * width + x) * 4
    }

    func alpha(_ x: Int, _ y: Int) -> CGFloat {
        CGFloat(data[offset(x, y) + 3]) / 255
    }

    func alpha(_ p: (Int, Int)) -> CGFloat { alpha(p.0, p.1) }

    /// Straight (un-premultiplied) colour at a pixel.
    func rgb(_ p: (Int, Int)) -> RGB {
        let o = offset(p.0, p.1)
        let a = max(CGFloat(data[o + 3]), 1)
        return RGB(red: CGFloat(data[o]) / a, green: CGFloat(data[o + 1]) / a, blue: CGFloat(data[o + 2]) / a)
    }

    func count(where pass: ((alpha: CGFloat, rgb: RGB)) -> Bool) -> Int {
        var n = 0
        for y in 0..<height {
            for x in 0..<width where pass((alpha(x, y), rgb((x, y)))) { n += 1 }
        }
        return n
    }
}

/// Straight RGBA at integer pixels of a rendered CGImage, (0,0) top-left.
struct IconPixels {
    let width: Int
    let height: Int
    private let data: [UInt8]

    init(_ image: CGImage) {
        width = image.width
        height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        data = bytes
    }

    private func offset(_ x: Int, _ y: Int) -> Int {
        precondition(x >= 0 && x < width && y >= 0 && y < height, "pixel (\(x), \(y)) outside \(width)x\(height)")
        return (y * width + x) * 4
    }

    func alpha(_ x: Int, _ y: Int) -> CGFloat {
        CGFloat(data[offset(x, y) + 3]) / 255
    }

    func luminance(_ x: Int, _ y: Int) -> CGFloat {
        let o = offset(x, y)
        let a = max(CGFloat(data[o + 3]), 1)
        let r = CGFloat(data[o]) / a, g = CGFloat(data[o + 1]) / a, b = CGFloat(data[o + 2]) / a
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Pixels where any channel of the two images differs by more than `tolerance` (0 to 255).
    func differences(from other: IconPixels, tolerance: Int) -> Int {
        precondition(width == other.width && height == other.height)
        var n = 0
        for i in stride(from: 0, to: data.count, by: 4) {
            for c in 0..<4 where abs(Int(data[i + c]) - Int(other.data[i + c])) > tolerance {
                n += 1
                break
            }
        }
        return n
    }
}
