import SwiftUI

struct NoInternetView: View {
    var onRetry: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.appBackground, Color.appSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 0)

                Image(systemName: "wifi.slash")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(.appPrimary)

                Text("No Internet Connection")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Please check your connection and try again.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Button(action: onRetry) {
                        Text("Retry")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.appPrimary)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 26)
            }
            .padding(.top, 24)
        }
    }
}

#Preview {
    NoInternetView(onRetry: {})
}
