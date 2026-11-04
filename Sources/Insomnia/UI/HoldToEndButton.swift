import SwiftUI

/// The AppKit status-item monitor handles pointer clicks using screen
/// coordinates. This button also retains keyboard/accessibility activation.
struct HoldToEndButton: View {
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.14), lineWidth: 1.6)
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .frame(width: 18, height: 18)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to end the session")
        .accessibilityLabel("End session")
    }
}
