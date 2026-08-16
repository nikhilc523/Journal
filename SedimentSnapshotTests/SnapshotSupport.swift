import SwiftUI
import SnapshotTesting
import Testing
@testable import Sediment

/// Snapshot infrastructure for the design system.
///
/// **Canonical device/OS: iPhone 17 / iOS 26.5.** Reference PNGs are recorded on
/// that runtime. Liquid Glass and font rendering differ across iOS point
/// releases and GPUs, so image-diff tests are **gated to the canonical OS** and
/// self-skip elsewhere — this keeps the protected `main` CI green regardless of
/// which iOS the runner's iPhone 17 lands on (the runner has 26.2/26.4/26.5).
/// The always-on deterministic net is the ViewInspector suite.
enum SnapshotEnv {
    /// True only on the canonical snapshot runtime (iOS 26.5).
    static var isCanonical: Bool {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return v.majorVersion == 26 && v.minorVersion == 5
    }

    /// Fixed width for component snapshots — device-independent, avoids safe-area
    /// / status-bar variance across simulators.
    static let width: CGFloat = 360
}

@MainActor
enum Snapshot {
    /// Assert a component in both light and dark appearances at a fixed width.
    /// No-ops off the canonical runtime. Small `perceptualPrecision` slack
    /// absorbs sub-pixel antialiasing noise between machines.
    static func assertLightDark(
        _ view: some View,
        named name: String,
        dynamicType: DynamicTypeSize = .large,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        guard SnapshotEnv.isCanonical else { return }
        for scheme in [ColorScheme.light, .dark] {
            let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
            let wrapped = view
                .frame(width: SnapshotEnv.width)
                .dynamicTypeSize(dynamicType)
                .background(GradientCanvas())
                .environment(\.colorScheme, scheme)
            assertSnapshot(
                of: wrapped,
                as: .image(
                    precision: 0.98,
                    perceptualPrecision: 0.95,
                    layout: .sizeThatFits,
                    traits: .init(userInterfaceStyle: style)
                ),
                named: "\(name)-\(scheme == .dark ? "dark" : "light")",
                fileID: fileID,
                file: file,
                testName: testName,
                line: line,
                column: column
            )
        }
    }
}
