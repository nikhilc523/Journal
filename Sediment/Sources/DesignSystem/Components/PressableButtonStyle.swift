import SwiftUI

/// Shared press feedback: scale to `DS.Motion.pressScale` with the `.tap` spring.
/// Respects Reduce Motion (no scale when reduced).
public struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? DS.Motion.pressScale : 1)
            .animation(reduceMotion ? nil : DS.Motion.tap, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
