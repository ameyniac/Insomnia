import AppKit
import SwiftUI
import XCTest
@testable import Insomnia

@MainActor
final class SettingsLayoutTests: XCTestCase {
    func testSettingsPagesFitTheirWindow() throws {
        let h = Harness()
        defer { h.home.destroy() }
        let manager = h.makeManager()
        for scheme: ColorScheme in [.light, .dark] {
        for page in SettingsView.Page.allCases {
            let view = SettingsView(manager: manager,
                secrets: KeychainHotspotSecretStore(keychain: BlockingKeychain()) { "" },
                locationPermission: LocationPermission(authorizationStatus: .notDetermined),
                loginItem: LoginItem(service: FakeLoginItemService(status: .notRegistered), install: "preview"),
                releases: ReleaseChecker(),
                build: AppBuild(info: ["InsomniaForkName": "Insomniac", "InsomniaForkVersion": "0.3.0"]), page: page)
                .environment(\.colorScheme, scheme)
            let host = NSHostingView(rootView: view)
            host.frame = CGRect(x: 0, y: 0, width: 620, height: 660)
            let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.fittingSize.width, 620, accuracy: 1)
            XCTAssertEqual(host.fittingSize.height, 660, accuracy: 1)
            if let folder = ProcessInfo.processInfo.environment["INSOMNIAC_UI_SNAPSHOTS"] {
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                try png.write(to: URL(fileURLWithPath: folder).appendingPathComponent(page.rawValue + (scheme == .light ? "-light" : "-dark") + ".png"))
            }
            window.contentView = nil
        }
        }
    }

    func testDiagnosticsDoesNotHideRecoveryWarnings() {
        let items = StatusMenu.items(sessionActive: false, sleepHeld: false, machine: "Lid open", actions: nil,
            throttledBrowsers: [], error: nil, recoveryLines: ["Cleanup pending · see status details"],
            recoveryWarning: "Recovery helper unavailable", includeDiagnostics: true)
        XCTAssertTrue(items.contains { $0.kind == .warning && $0.title == "Recovery helper unavailable" })
        XCTAssertTrue(items.contains { $0.kind == .warning && $0.title.hasPrefix("Cleanup pending") })
        let diagnostics = items.first { if case .diagnostics = $0.kind { return true }; return false }
        guard case let .diagnostics(details) = diagnostics?.kind else { return XCTFail("Missing Diagnostics submenu") }
        XCTAssertTrue(details.contains { $0.title == "Lid open" })
        XCTAssertTrue(details.contains { $0.kind == .copyDiagnostics })
        XCTAssertFalse(items.contains { $0.title == "Lid open" })
    }
}
