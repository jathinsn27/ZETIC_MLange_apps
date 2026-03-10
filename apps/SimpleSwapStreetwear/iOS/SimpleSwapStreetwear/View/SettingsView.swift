import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: Binding(
                        get: { viewModel.isDarkMode },
                        set: { _ in viewModel.toggleDarkMode() }
                    ))

                    HStack {
                        Text("Accent Color")
                        Spacer()
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 24, height: 24)
                    }
                }

                Section("Performance") {
                    Picker("Quality Preset", selection: $viewModel.fpsPreset) {
                        Text("Low (faster)").tag("Low")
                        Text("Standard").tag("Standard")
                        Text("High (slower)").tag("High")
                    }

                    Toggle("Battery Saver", isOn: $viewModel.batterySaver)
                }

                Section("Model Input") {
                    HStack {
                        Text("Input Size")
                        Spacer()
                        Text("\(viewModel.modelInputSpec.inputWidth) x \(viewModel.modelInputSpec.inputHeight)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Color Space")
                        Spacer()
                        Text(viewModel.modelInputSpec.colorSpace.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Normalization")
                        Spacer()
                        Text(viewModel.modelInputSpec.normalization.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink("Edit in Diagnostics") {
                        DiagnosticsView()
                    }
                }

                Section("Privacy") {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(AppTheme.accent)
                        Text("All data is stored locally on your device. No images or personal data are sent to external servers. The AI model runs entirely on-device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Clear All History", role: .destructive) {
                        viewModel.clearHistory()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Model")
                        Spacer()
                        Text("DeepLabV3 ResNet")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Engine")
                        Spacer()
                        Text("Zetic MLange")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

