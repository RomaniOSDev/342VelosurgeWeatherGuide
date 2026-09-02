import SwiftUI

enum AppTheme {
    static let background = Color("AppBackground")
    static let surface = Color("AppSurface")
    static let primary = Color("AppPrimary")
    static let accent = Color("AppAccent")

    static var meter: LinearGradient {
        LinearGradient(colors: [accent, primary], startPoint: .bottom, endPoint: .top)
    }

    static var panel: LinearGradient {
        LinearGradient(
            colors: [surface.opacity(0.95), background.opacity(0.88)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var plateShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: 4,
                bottomLeading: 22,
                bottomTrailing: 4,
                topTrailing: 22
            ),
            style: .continuous
        )
    }
}

struct GaugePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 1 : 0)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

struct SoilChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundColor(AppTheme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .stroke(AppTheme.primary.opacity(configuration.isPressed ? 1 : 0.55), lineWidth: 1)
            )
    }
}
