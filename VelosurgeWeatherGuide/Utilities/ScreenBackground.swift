import SwiftUI

extension View {
    func screenBackdrop(_ imageName: String) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    AppTheme.background
                    VStack(spacing: 0) {
                        ForEach(0..<18, id: \.self) { index in
                            Rectangle()
                                .fill(index % 2 == 0 ? AppTheme.surface.opacity(0.28) : Color.clear)
                                .frame(height: 26)
                        }
                        Spacer(minLength: 0)
                    }
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .opacity(0.11)
                    LinearGradient(
                        colors: [
                            AppTheme.background,
                            AppTheme.background.opacity(0.15),
                            AppTheme.background.opacity(0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipped()
                .ignoresSafeArea()
            }
    }
}
