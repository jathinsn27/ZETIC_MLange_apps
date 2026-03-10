import Foundation
import UIKit
import SwiftUI
import Combine

enum AppState {
    case loading
    case ready
    case error(String)
}

enum ProcessingState {
    case idle
    case segmenting
    case applyingColor
}

@MainActor
final class AppViewModel: ObservableObject {
    // App state
    @Published var appState: AppState = .loading
    @Published var downloadProgress: Float = 0
    @Published var statusText: String = "Initializing..."

    // Photo state
    @Published var originalImage: UIImage?
    @Published var maskImage: UIImage?
    @Published var resultImage: UIImage?
    @Published var showImagePicker = false
    @Published var showCamera = false
    @Published var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary

    // Processing state
    @Published var processingState: ProcessingState = .idle
    @Published var selectedColorIndex: Int = 0
    @Published var lastLatencyMs: Double = 0

    // Settings
    @Published var isDarkMode: Bool = true
    @Published var modelInputSpec: ModelInputSpec = ModelInputSpec.load()
    @Published var fpsPreset: String = "Standard"
    @Published var batterySaver: Bool = false

    // History
    @Published var history: [SessionRecord] = SessionRecord.loadAll()

    // Diagnostics
    @Published var lastOutputShape: [Int] = []
    @Published var lastRawOutputPreview: [Float] = []
    @Published var lastErrorText: String?

    // Services
    private let segmentationService = SegmentationService()

    var selectedColor: (name: String, color: Color, rgb: (CGFloat, CGFloat, CGFloat)) {
        AppTheme.swapColors[selectedColorIndex]
    }

    var isProcessing: Bool {
        processingState != .idle
    }

    init() {
        isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
        Task { await loadModel() }
    }

    func loadModel() async {
        appState = .loading
        statusText = "Downloading model..."
        downloadProgress = 0

        do {
            try await segmentationService.loadModel { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                    if progress < 1.0 {
                        self?.statusText = "Downloading model... \(Int(progress * 100))%"
                    } else {
                        self?.statusText = "Loading model..."
                    }
                }
            }
            appState = .ready
            statusText = "Ready"
        } catch {
            appState = .error(error.localizedDescription)
            statusText = "Failed: \(error.localizedDescription)"
            lastErrorText = error.localizedDescription
        }
    }

    func onImageSelected(_ image: UIImage) {
        originalImage = ZeticTensorFactory.normalizeOrientation(image)
        maskImage = nil
        resultImage = nil
        processingState = .idle
    }

    func generateMask() async {
        guard let image = originalImage else { return }
        processingState = .segmenting

        let result = await segmentationService.segment(image: image, spec: modelInputSpec)

        if let result = result {
            maskImage = result.mask
            lastLatencyMs = result.latencyMs
            lastOutputShape = result.outputShape
            lastRawOutputPreview = segmentationService.lastRawOutputPreview
            lastErrorText = nil

            // Auto-apply selected color
            await applyColor()
        } else {
            lastErrorText = segmentationService.lastError
            lastLatencyMs = segmentationService.lastLatencyMs
            processingState = .idle
        }
    }

    func applyColor() async {
        guard let image = originalImage, let mask = maskImage else { return }
        processingState = .applyingColor

        let colorRGB = selectedColor.rgb
        let startTime = CFAbsoluteTimeGetCurrent()

        let result = await Task.detached(priority: .userInitiated) {
            ColorSwapEngine.applyColor(
                to: image,
                mask: mask,
                color: (r: colorRGB.0, g: colorRGB.1, b: colorRGB.2)
            )
        }.value

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        if let result = result {
            resultImage = result
            lastLatencyMs += latency
        }
        processingState = .idle
    }

    func changeColor(to index: Int) async {
        selectedColorIndex = index
        if maskImage != nil {
            await applyColor()
        }
    }

    func saveToHistory() {
        guard let original = originalImage, let result = resultImage else { return }
        let id = UUID().uuidString
        let origPath = SessionRecord.saveImage(original, name: "\(id)_orig.jpg")
        let resultPath = SessionRecord.saveImage(result, name: "\(id)_result.jpg")

        let record = SessionRecord(
            colorName: selectedColor.name,
            latencyMs: lastLatencyMs,
            originalImagePath: origPath,
            resultImagePath: resultPath
        )
        history.insert(record, at: 0)
        SessionRecord.saveAll(history)
    }

    func deleteHistoryItem(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        SessionRecord.saveAll(history)
    }

    func clearHistory() {
        history.removeAll()
        SessionRecord.clearAll()
    }

    func saveSpec() {
        modelInputSpec.save()
    }

    func resetSpec() {
        modelInputSpec = .default
        modelInputSpec.save()
    }

    func toggleDarkMode() {
        isDarkMode.toggle()
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
    }

    func saveResultToPhotoLibrary() {
        guard let result = resultImage else { return }
        UIImageWriteToSavedPhotosAlbum(result, nil, nil, nil)
    }
}

