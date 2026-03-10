import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showSaveConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image display area
                    imageSection

                    // Action buttons
                    if viewModel.originalImage != nil {
                        actionSection
                    }

                    // Color palette
                    if viewModel.maskImage != nil {
                        colorPaletteSection
                    }

                    // Telemetry
                    if viewModel.lastLatencyMs > 0 {
                        telemetrySection
                    }
                }
                .padding()
            }
            .navigationTitle("SimpleSwap")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.imagePickerSourceType = .camera
                            viewModel.showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }

                        Button {
                            viewModel.imagePickerSourceType = .photoLibrary
                            viewModel.showImagePicker = true
                        } label: {
                            Label("Choose Photo", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showImagePicker) {
                ImagePickerView(sourceType: .photoLibrary) { image in
                    viewModel.onImageSelected(image)
                }
            }
            .sheet(isPresented: $viewModel.showCamera) {
                ImagePickerView(sourceType: .camera) { image in
                    viewModel.onImageSelected(image)
                }
            }
            .alert("Saved!", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The swapped image has been saved to your photo library.")
            }
        }
    }

    private var imageSection: some View {
        Group {
            if let image = viewModel.resultImage {
                ImageCard(uiImage: image, label: "Color Swapped")
            } else if let image = viewModel.maskImage {
                ImageCard(uiImage: image, label: "Clothing Mask")
            } else if let image = viewModel.originalImage {
                ImageCard(uiImage: image, label: "Original Photo")
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
                .frame(height: 360)
                .overlay {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                            .font(.system(size: 56))
                            .foregroundStyle(AppTheme.primary.opacity(0.6))

                        Text("Upload a photo to get started")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button {
                                viewModel.imagePickerSourceType = .camera
                                viewModel.showCamera = true
                            } label: {
                                Label("Camera", systemImage: "camera.fill")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.gradient)
                                    .clipShape(Capsule())
                            }

                            Button {
                                viewModel.imagePickerSourceType = .photoLibrary
                                viewModel.showImagePicker = true
                            } label: {
                                Label("Gallery", systemImage: "photo.fill")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            // Magic Mask button
            Button {
                Task { await viewModel.generateMask() }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.processingState == .segmenting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(viewModel.maskImage != nil ? "Re-detect Clothes" : "Magic Mask")
                        .fontWeight(.bold)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    viewModel.isProcessing
                        ? AnyShapeStyle(Color.gray)
                        : AnyShapeStyle(AppTheme.gradient)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(viewModel.isProcessing)

            if viewModel.resultImage != nil {
                HStack(spacing: 12) {
                    Button {
                        viewModel.saveToHistory()
                        viewModel.saveResultToPhotoLibrary()
                        showSaveConfirmation = true
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        viewModel.originalImage = nil
                        viewModel.maskImage = nil
                        viewModel.resultImage = nil
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var colorPaletteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Color")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(AppTheme.swapColors.indices, id: \.self) { index in
                    let item = AppTheme.swapColors[index]
                    Button {
                        Task { await viewModel.changeColor(to: index) }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            viewModel.selectedColorIndex == index ? Color.white : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                                .shadow(
                                    color: viewModel.selectedColorIndex == index ? item.color.opacity(0.6) : .clear,
                                    radius: 8
                                )

                            if viewModel.selectedColorIndex == index {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundColor(index == 6 ? .black : .white) // dark check on white swatch
                            }
                        }
                    }
                    .disabled(viewModel.isProcessing)
                }
            }

            Text(viewModel.selectedColor.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var telemetrySection: some View {
        HStack {
            TelemetryBadge(label: "Latency", value: String(format: "%.0f ms", viewModel.lastLatencyMs))
            Spacer()
            if let error = viewModel.lastErrorText {
                TelemetryBadge(label: "Error", value: error, isError: true)
            } else {
                TelemetryBadge(label: "Status", value: "OK")
            }
        }
        .padding(.horizontal, 4)
    }
}

struct ImageCard: View {
    let uiImage: UIImage
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 400)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TelemetryBadge: View {
    let label: String
    let value: String
    var isError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(isError ? .red : .primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

