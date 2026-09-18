import SwiftUI

struct LoadingAmbientField: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.appBackground,
                    Color.appSurface.opacity(0.95),
                    Color.appBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.appPrimary.opacity(0.42),
                    Color.appAccent.opacity(0.18),
                    Color.appBackground.opacity(0.05),
                    .clear
                ],
                center: UnitPoint(x: 0.52, y: 0.32),
                startRadius: 8,
                endRadius: 380
            )
            .blendMode(.plusLighter)

            Ellipse()
                .fill(Color.appPrimary.opacity(0.28))
                .frame(width: 320, height: 220)
                .blur(radius: 78)
                .offset(x: drift ? 42 : -34, y: drift ? -120 : -78)

            Ellipse()
                .fill(Color.appAccent.opacity(0.2))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: drift ? -64 : 48, y: drift ? 210 : 160)

            Circle()
                .fill(Color.appSurface.opacity(0.7))
                .frame(width: 200, height: 200)
                .blur(radius: 56)
                .offset(x: 130, y: -240)

            ForEach(0..<16, id: \.self) { index in
                Capsule()
                    .fill(
                        index.isMultiple(of: 3)
                            ? Color.appPrimary.opacity(0.55)
                            : Color.appAccent.opacity(0.28)
                    )
                    .frame(width: CGFloat(2 + index % 2), height: CGFloat(8 + (index % 4) * 3))
                    .rotationEffect(.degrees(Double(index) * 17))
                    .offset(
                        x: dropletX(index),
                        y: dropletY(index) + (drift ? -14 : 12)
                    )
                    .blur(radius: index % 4 == 0 ? 0.4 : 0)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func dropletX(_ index: Int) -> CGFloat {
        let values: [CGFloat] = [-140, -100, -48, 12, 64, 118, -160, 156, -24, 98, -78, 36, -118, 78, -8, 132]
        return values[index % values.count]
    }

    private func dropletY(_ index: Int) -> CGFloat {
        let values: [CGFloat] = [-230, -170, -100, -30, 40, 108, 176, -260, 210, -130, 70, -50, 140, -190, 20, -80]
        return values[index % values.count]
    }
}

struct LoadingMoistureDial: View {
    @State private var spin = false
    @State private var level: CGFloat = 0.28
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appSurface.opacity(0.9), lineWidth: 18)
                .frame(width: 214, height: 214)

            Circle()
                .trim(from: 0.12, to: 0.12 + 0.76 * level)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.appPrimary.opacity(0.15),
                            Color.appPrimary,
                            Color.appAccent,
                            Color.appPrimary
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .frame(width: 214, height: 214)
                .rotationEffect(.degrees(-210))
                .shadow(color: Color.appPrimary.opacity(0.55), radius: pulse ? 16 : 8)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.appPrimary.opacity(0.7),
                            Color.appAccent.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 1.4, dash: [3, 7])
                )
                .frame(width: 248, height: 248)
                .rotationEffect(.degrees(spin ? 360 : 0))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.appPrimary.opacity(0.35),
                            Color.appSurface.opacity(0.95),
                            Color.appBackground.opacity(0.9)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 96
                    )
                )
                .frame(width: 168, height: 168)
                .overlay(
                    Circle()
                        .stroke(Color.appPrimary.opacity(0.45), lineWidth: 1.2)
                )
                .shadow(color: Color.appPrimary.opacity(pulse ? 0.4 : 0.18), radius: pulse ? 24 : 12)

            VStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appPrimary, Color.appAccent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(pulse ? 1 : 0.72)

                Text("SOIL CORE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(Color.appPrimary)
            }
            .scaleEffect(pulse ? 1.04 : 0.98)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                level = 0.82
                pulse = true
            }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }
}

struct LoadingHeroPlate: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: 8,
                    bottomLeading: 34,
                    bottomTrailing: 8,
                    topTrailing: 34
                ),
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color.appSurface.opacity(0.98),
                        Color.appBackground.opacity(0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: RectangleCornerRadii(
                        topLeading: 8,
                        bottomLeading: 34,
                        bottomTrailing: 8,
                        topTrailing: 34
                    ),
                    style: .continuous
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.appPrimary,
                            Color.appAccent.opacity(0.45),
                            Color.appPrimary.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.4
                )
            )
            .shadow(color: Color.appPrimary.opacity(glow ? 0.5 : 0.22), radius: glow ? 30 : 14, y: 12)

            LoadingMoistureDial()
                .padding(18)
        }
        .frame(width: 300, height: 300)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

struct LoadingProgressBar: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appSurface.opacity(0.85))
                    .overlay(
                        Capsule()
                            .stroke(Color.appPrimary.opacity(0.25), lineWidth: 1)
                    )

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.appPrimary, Color.appAccent, Color.appPrimary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width * 0.38, 36))
                    .offset(x: phase * (width * 0.62))
                    .shadow(color: Color.appPrimary.opacity(0.7), radius: 10, y: 0)
            }
        }
        .frame(height: 7)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

struct LoadingStatusLine: View {
    @State private var step = 0

    private let lines = [
        "Reading soil moisture",
        "Tuning weather guide",
        "Almost ready"
    ]

    var body: some View {
        Text(lines[step % lines.count])
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.appTextPrimary.opacity(0.82))
            .multilineTextAlignment(.center)
            .id(step)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_700_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.32)) {
                        step = (step + 1) % lines.count
                    }
                }
            }
    }
}

struct LoadingView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            LoadingAmbientField()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                LoadingHeroPlate()
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.9)
                    .offset(y: appeared ? 0 : 22)

                VStack(spacing: 14) {
                    LoadingProgressBar()
                        .frame(width: 176)
                        .opacity(appeared ? 1 : 0)

                    LoadingStatusLine()
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.top, 30)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

#Preview {
    LoadingView()
}
