import Foundation
import XCTest
@testable import Insomnia

final class SafetyCheckCommandTests: XCTestCase {
    private func check(_ readings: [(BatteryStatus, Bool)], thermal: ProcessInfo.ThermalState = .nominal,
                       settings: Config = Config()) -> ResumeFrozenCommand.Output {
        var index = 0
        var lifetime: UInt32 = 0
        let output = SafetyCheckCommand.run([SafetyCheckCommand.flag], config: { settings }, battery: {
            let value = readings[min(index, readings.count - 1)]
            index += 1
            return (value.0, value.1)
        }, thermal: { thermal }, retryWait: {}, endAfter: { lifetime = $0 })!
        XCTAssertEqual(lifetime, 10)
        return output
    }

    func testBatteryFloorAndCharging() {
        XCTAssertEqual(check([(.percent(9), false)]).lines, ["stop-battery"])
        XCTAssertEqual(check([(.percent(10), false)]).status, 0)
        XCTAssertEqual(check([(.percent(2), true)]).status, 0)
        XCTAssertEqual(check([(.none, false)]).status, 0)
    }

    func testCriticalHeatEndsOnACAndBattery() {
        XCTAssertEqual(check([(.percent(90), true)], thermal: .critical).lines, ["stop-thermal"])
        XCTAssertEqual(check([(.percent(90), false)], thermal: .critical).status, 10)
        XCTAssertEqual(check([(.percent(90), false)], thermal: .serious).status, 0)
    }

    func testUnreadableBatteryRetriesThenEndsOrRecovers() {
        XCTAssertEqual(check([(.unreadable(misses: 1), false)]).lines, ["stop-battery-unreadable"])
        XCTAssertEqual(check([(.unreadable(misses: 1), false), (.percent(80), false)]).status, 0)
        XCTAssertEqual(check([(.unreadable(misses: 1), false), (.percent(2), false)]).lines, ["stop-battery"])
        XCTAssertEqual(check([(.unreadable(misses: 1), false), (.unreadable(misses: 1), true)]).status, 0)
    }

    func testExplicitDisabledRulesAreHonoured() {
        var config = Config()
        config.endFloor = 0
        config.thermalRules = false
        XCTAssertEqual(check([(.unreadable(misses: 1), false)], thermal: .critical, settings: config).status, 0)
    }

    func testConfigurationFailureAndUnknownArguments() {
        let result = SafetyCheckCommand.run([SafetyCheckCommand.flag], config: {
            throw CocoaError(.fileReadCorruptFile)
        }, endAfter: { _ in })
        XCTAssertEqual(result?.lines, ["stop-configuration-unreadable"])
        XCTAssertNil(SafetyCheckCommand.run([], endAfter: { _ in XCTFail("armed for GUI launch") }))
        XCTAssertEqual(SafetyCheckCommand.run([SafetyCheckCommand.flag, "extra"], endAfter: { _ in XCTFail("invalid args") })?.status, 64)
    }
}

final class EndClickTrackingTests: XCTestCase {
    func testUsesVisibleWidthAndRejectsCentreAndOutsidePoints() {
        let bounds = CGRect(x: 0, y: 0, width: 118, height: 24)
        XCTAssertFalse(EndClickTracking.contains(CGPoint(x: 59, y: 12), in: bounds))
        XCTAssertTrue(EndClickTracking.contains(CGPoint(x: 100, y: 12), in: bounds))
        XCTAssertFalse(EndClickTracking.contains(CGPoint(x: 100, y: 25), in: bounds))
        XCTAssertFalse(EndClickTracking.contains(CGPoint(x: 120, y: 12), in: bounds))
        XCTAssertFalse(EndClickTracking.contains(CGPoint(x: 10, y: 12), in: CGRect(x: 0, y: 0, width: 24, height: 24)))
    }

    func testOnlyMouseUpFiresAndOnlyOnce() {
        var click = EndClickTracking()
        click.begin(at: CGPoint(x: 100, y: 12))
        XCTAssertTrue(click.isTracking)
        XCTAssertTrue(click.finish(at: CGPoint(x: 102, y: 12), inside: true))
        XCTAssertFalse(click.finish(at: CGPoint(x: 102, y: 12), inside: true))
    }

    func testDraggingAwayAndBackCannotFire() {
        var click = EndClickTracking()
        click.begin(at: CGPoint(x: 100, y: 12))
        click.drag(to: CGPoint(x: 120, y: 12))
        XCTAssertFalse(click.finish(at: CGPoint(x: 100, y: 12), inside: true))
        click.begin(at: CGPoint(x: 100, y: 12))
        XCTAssertFalse(click.finish(at: CGPoint(x: 100, y: 12), inside: false))
    }
}
