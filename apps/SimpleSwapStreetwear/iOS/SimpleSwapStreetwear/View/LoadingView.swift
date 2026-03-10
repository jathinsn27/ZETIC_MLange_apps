import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var pulse = false

    var body: some View {
        ZStack {
            AppTheme.backgroundDark
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppTheme.gradient)
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulse ? 1.1 : 0.95)
                        .opacity(pulse ? 0.6 : 0.3)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)

                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                }
                .onAppear { pulse = true }

                VStack(spacing: 8) {
                    Text("SimpleSwap")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("STREETWEAR")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.primary)
                        .tracking(6)
                }

                VStack(spacing: 12) {
                    ProgressView(value: viewModel.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.primary))
                        .frame(width: 240)

                    Text(viewModel.statusText)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Spacer()

                Text("Powered by Zetic MLange")
                    .font(.caption2)
                    .foregroundStyle(.gray.opacity(0.6))
                    .padding(.bottom, 24)
            }
        }
    }
}

