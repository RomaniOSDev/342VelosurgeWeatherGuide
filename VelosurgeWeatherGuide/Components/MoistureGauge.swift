import SwiftUI

struct MoistureGauge: View {
    let value: Double
    var zoneLabel: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .trailing, spacing: 0) {
                    tick("100")
                    Spacer()
                    tick("70")
                    Spacer()
                    tick("35")
                    Spacer()
                    tick("0")
                }
                .frame(height: 188)
                SoilWick(value: value, width: 40, height: 188)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("SOIL CORE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundColor(AppTheme.primary)
                Text("\(Int(value))%")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(zone)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tick(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary)
    }

    private var zone: String {
        if let zoneLabel { return zoneLabel }
        if value < 35 { return "Dry" }
        if value > 70 { return "Saturated" }
        return "Optimal"
    }
}

struct SoilWick: View {
    let value: Double
    var width: CGFloat = 10
    var height: CGFloat = 52

    var body: some View {
        GeometryReader { geo in
            let fill = geo.size.height * CGFloat(min(max(value, 0), 100) / 100)
            ZStack(alignment: .bottom) {
                Capsule(style: .continuous)
                    .fill(AppTheme.surface)
                Capsule(style: .continuous)
                    .fill(AppTheme.meter)
                    .frame(height: max(fill, value > 0 ? 8 : 0))
                    .padding(3)
                    .shadow(color: AppTheme.primary.opacity(0.35), radius: 6, y: -2)
            }
        }
        .frame(width: width, height: height)
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppTheme.primary.opacity(0.5), lineWidth: 1.2)
        )
    }
}

struct MeterCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .leading) {
                    AppTheme.plateShape
                        .fill(AppTheme.panel)
                    AppTheme.plateShape
                        .stroke(AppTheme.primary.opacity(0.18), lineWidth: 1)
                    Capsule()
                        .fill(AppTheme.primary)
                        .frame(width: 4)
                        .padding(.vertical, 14)
                        .padding(.leading, 6)
                }
            }
    }
}

struct MeterButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(.headline, design: .rounded))
            }
            .foregroundColor(AppTheme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    UnevenRoundedRectangle(
                        cornerRadii: RectangleCornerRadii(
                            topLeading: 18,
                            bottomLeading: 4,
                            bottomTrailing: 18,
                            topTrailing: 4
                        ),
                        style: .continuous
                    )
                    .fill(AppTheme.surface.opacity(0.55))
                    UnevenRoundedRectangle(
                        cornerRadii: RectangleCornerRadii(
                            topLeading: 18,
                            bottomLeading: 4,
                            bottomTrailing: 18,
                            topTrailing: 4
                        ),
                        style: .continuous
                    )
                    .stroke(AppTheme.primary, lineWidth: 1.4)
                }
            )
        }
        .buttonStyle(GaugePressStyle())
        .frame(minHeight: 44)
    }
}

struct SoilMark: View {
    let icon: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(AppTheme.primary.opacity(0.16))
                .rotationEffect(.degrees(45))
                .frame(width: 30, height: 30)
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.primary)
        }
        .frame(width: 36, height: 36)
    }
}
