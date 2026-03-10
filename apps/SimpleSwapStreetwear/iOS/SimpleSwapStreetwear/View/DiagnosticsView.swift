import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var copiedRaw = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Inferred Modality") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundStyle(AppTheme.accent)
                            Text("Vision (Segmentation)")
                                .font(.subheadline.bold())
                        }
                        Text("DeepLabV3 ResNet is a semantic segmentation model. It classifies each pixel into one of 21 Pascal VOC classes. Person class (15) is used as the clothing mask.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Model Input Spec") {
                    Stepper("Width: \(viewModel.modelInputSpec.inputWidth)",
                            value: $viewModel.modelInputSpec.inputWidth,
                            in: 64...1056, step: 4)
                    .onChange(of: viewModel.modelInputSpec.inputWidth) { _, _ in viewModel.saveSpec() }

                    Stepper("Height: \(viewModel.modelInputSpec.inputHeight)",
                            value: $viewModel.modelInputSpec.inputHeight,
                            in: 64...1056, step: 4)
                    .onChange(of: viewModel.modelInputSpec.inputHeight) { _, _ in viewModel.saveSpec() }

                    Picker("Color Space", selection: $viewModel.modelInputSpec.colorSpace) {
                        ForEach(ModelInputSpec.ColorSpaceOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .onChange(of: viewModel.modelInputSpec.colorSpace) { _, _ in viewModel.saveSpec() }

                    Picker("Normalization", selection: $viewModel.modelInputSpec.normalization) {
                        ForEach(ModelInputSpec.NormalizationOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .onChange(of: viewModel.modelInputSpec.normalization) { _, _ in viewModel.saveSpec() }

                    Picker("Rotation", selection: $viewModel.modelInputSpec.rotationDegrees) {
                        Text("0").tag(0)
                        Text("90").tag(90)
                        Text("180").tag(180)
                        Text("270").tag(270)
                    }
                    .onChange(of: viewModel.modelInputSpec.rotationDegrees) { _, _ in viewModel.saveSpec() }

                    Button("Reset to Defaults") {
                        viewModel.resetSpec()
                    }
                    .foregroundStyle(.red)
                }

                Section("Last Inference") {
                    HStack {
                        Text("Latency")
                        Spacer()
                        Text(String(format: "%.1f ms", viewModel.lastLatencyMs))
                            .font(.body.monospaced())
                            .foregroundStyle(AppTheme.accent)
                    }

                    HStack {
                        Text("Output Shape")
                        Spacer()
                        Text(viewModel.lastOutputShape.isEmpty ? "N/A" : "\(viewModel.lastOutputShape)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    if let error = viewModel.lastErrorText {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("No errors")
                                .font(.caption)
                        }
                    }
                }

                Section("Raw Output Preview") {
                    if viewModel.lastRawOutputPreview.isEmpty {
                        Text("Run inference to see output values")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("First \(viewModel.lastRawOutputPreview.count) values:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(viewModel.lastRawOutputPreview.map { String(format: "%.4f", $0) }.joined(separator: ", "))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }

                        Button {
                            let text = viewModel.lastRawOutputPreview.map { String(format: "%.6f", $0) }.joined(separator: ", ")
                            UIPasteboard.general.string = text
                            copiedRaw = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedRaw = false }
                        } label: {
                            Label(copiedRaw ? "Copied!" : "Copy Raw Values", systemImage: copiedRaw ? "checkmark" : "doc.on.doc")
                        }
                    }
                }
            }
            .navigationTitle("Diagnostics")
        }
    }
}

