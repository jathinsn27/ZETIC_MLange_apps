import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        switch viewModel.appState {
        case .loading:
            LoadingView()
        case .ready:
            MainTabView()
        case .error(let message):
            ErrorView(message: message) {
                Task { await viewModel.loadModel() }
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        TabView {
            MainView()
                .tabItem {
                    Label("Swap", systemImage: "tshirt.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }

            DiagnosticsView()
                .tabItem {
                    Label("Diagnostics", systemImage: "waveform.badge.magnifyingglass")
                }
        }
        .tint(AppTheme.primary)
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.primary)

            Text("Failed to Load Model")
                .font(.title2.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 48)
        }
    }
}

