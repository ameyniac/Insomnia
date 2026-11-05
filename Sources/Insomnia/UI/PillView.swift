import SwiftUI

/// A fixed-width duration field with a persistent unit and immediate focus.
/// Typing changes neither its width nor its animation state.
struct PillView: View {
    let field: DurationInput.Field
    let text: String?
    let focused: Bool
    let valid: Bool
    let glowVisible: Bool
    let focusBounce: Int
    let rejectBounce: Int
    let reduceMotion: Bool
    let onTap: () -> Void

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 7, style: .continuous) }

    var body: some View {
        HStack(spacing: 4) {
            Text(text ?? "0")
                .monospacedDigit()
                .frame(width: 18, alignment: .trailing)
                .foregroundStyle(text == nil ? .secondary : .primary)
            Text(field == .days ? "d" : field == .hours ? "h" : "m")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .medium))
        .frame(width: 44, height: 21)
        .background(.regularMaterial, in: shape)
        .overlay { shape.strokeBorder(focused ? Color.accentColor : Color.primary.opacity(0.18), lineWidth: focused ? 1.5 : 0.5) }
        .overlay { if !valid { shape.strokeBorder(.red, lineWidth: 1) } }
        .contentShape(Rectangle())
        .help(field.help)
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(field.placeholder)
        .accessibilityValue(text ?? "0")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .transaction { $0.animation = nil }
    }
}
