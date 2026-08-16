import SwiftUI

/// A circular checkbox (per `primary.jpg`'s leading todo circle). Unchecked =
/// hairline ring; checked = clay fill with a light checkmark and a success
/// haptic. Animates the fill with the tap spring (Reduce-Motion safe).
public struct Checkbox: View {
    @Binding private var isOn: Bool
    private let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isOn: Binding<Bool>, label: String = "Done") {
        self._isOn = isOn
        self.label = label
    }

    public var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(isOn ? Color.clear : DS.Colors.greige, lineWidth: 1.5)
                    .background(Circle().fill(isOn ? DS.Colors.clay : Color.clear))
                    .frame(width: 24, height: 24)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.Colors.inkOnAccent)
                    .opacity(isOn ? 1 : 0)
                    .scaleEffect(isOn ? 1 : 0.4)
            }
            .animation(reduceMotion ? nil : DS.Motion.tap, value: isOn)
            .contentShape(Circle())
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.success, trigger: isOn) { old, new in !old && new }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(isOn ? "Checked" : "Unchecked")
        .accessibilityIdentifier("checkbox")
    }
}

#Preview {
    struct Demo: View {
        @State var a = false
        @State var b = true
        var body: some View {
            GradientCanvas {
                HStack(spacing: 24) {
                    Checkbox(isOn: $a)
                    Checkbox(isOn: $b)
                }
            }
        }
    }
    return Demo()
}
