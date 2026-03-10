import Foundation
import UIKit
@preconcurrency import ZeticMLange

final class SegmentationService {
    private var model: ZeticMLangeModel?
    private let inferenceQueue = DispatchQueue(label: "com.simpleswap.inference", qos: .userInitiated)

    var isLoaded: Bool { model != nil }
    var lastError: String?
    var lastLatencyMs: Double = 0
    var lastOutputShape: [Int] = []
    var lastRawOutputPreview: [Float] = []

    func loadModel(onProgress: @escaping (Float) -> Void) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            inferenceQueue.async {
                do {
                    let loaded = try ZeticMLangeModel(
                        tokenKey: "dev_24c61ecfff874298a52c5f3be0a83f71",
                        name: "yeonseok_zeticai_ceo/deeplabv3_resnet101_onnx",
                        onDownload: { progress in
                            DispatchQueue.main.async {
                                onProgress(progress)
                            }
                        }
                    )
                    self.model = loaded
                    self.lastError = nil
                    cont.resume()
                } catch {
                    self.lastError = error.localizedDescription
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// Model is exported with (1, 3, 520, 520) in export.py; we force this size for the model call.
    private static func specForModelInput(_ spec: ModelInputSpec) -> ModelInputSpec {
        var fixed = spec
        fixed.inputWidth = 520
        fixed.inputHeight = 520
        return fixed
    }

    func segment(image: UIImage, spec: ModelInputSpec) async -> SegmentationResult? {
        guard let model = model else {
            lastError = "Model not loaded"
            return nil
        }

        let modelRef = model
        let inputSpec = Self.specForModelInput(spec)
        return await withCheckedContinuation { cont in
            inferenceQueue.async { [weak self] in
                guard let self else { cont.resume(returning: nil); return }
                let startTime = CFAbsoluteTimeGetCurrent()

                do {
                    let inputTensor = try ZeticTensorFactory.createImageTensor(from: image, spec: inputSpec)
                    let outputs = try modelRef.run(inputs: [inputTensor])

                    guard let outputTensor = outputs.first else {
                        DispatchQueue.main.async {
                            self.lastError = "No output tensor"
                            cont.resume(returning: nil)
                        }
                        return
                    }

                    let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                    let shape = outputTensor.shape
                    let floats = ZeticTensorFactory.extractFloatArray(from: outputTensor)
                    let mask = self.buildClothingMask(
                        floats: floats,
                        shape: shape,
                        originalSize: image.size,
                        spec: inputSpec
                    )
                    let result = SegmentationResult(
                        mask: mask,
                        latencyMs: latency,
                        outputShape: shape
                    )

                    DispatchQueue.main.async {
                        self.lastLatencyMs = latency
                        self.lastError = nil
                        self.lastOutputShape = shape
                        self.lastRawOutputPreview = Array(floats.prefix(20))
                        cont.resume(returning: result)
                    }
                } catch {
                    let err = error.localizedDescription
                    let lat = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                    DispatchQueue.main.async {
                        self.lastError = err
                        self.lastLatencyMs = lat
                        cont.resume(returning: nil)
                    }
                }
            }
        }
    }

    private func buildClothingMask(floats: [Float], shape: [Int], originalSize: CGSize, spec: ModelInputSpec) -> UIImage? {
        // DeepLabV3 output is typically [1, 21, H, W] (Pascal VOC 21 classes)
        // or [1, H, W] (argmax already applied)
        // or [1, H, W, 21] (channels last)
        // We need to handle multiple formats

        let width: Int
        let height: Int
        let numClasses: Int
        var classMap: [Int]

        if shape.count == 4 && shape[1] == 21 {
            // [1, 21, H, W] - channels first
            numClasses = shape[1]
            height = shape[2]
            width = shape[3]
            classMap = argmaxChannelsFirst(floats: floats, numClasses: numClasses, height: height, width: width)
        } else if shape.count == 4 && shape[3] == 21 {
            // [1, H, W, 21] - channels last
            numClasses = shape[3]
            height = shape[1]
            width = shape[2]
            classMap = argmaxChannelsLast(floats: floats, numClasses: numClasses, height: height, width: width)
        } else if shape.count == 3 {
            // [1, H, W] - already argmaxed
            height = shape[1]
            width = shape[2]
            numClasses = 21
            classMap = floats.map { Int($0) }
        } else if shape.count == 4 && shape[1] > 21 {
            // Could be [1, C, H, W] with C > 21 (e.g. ADE20K 150 classes)
            numClasses = shape[1]
            height = shape[2]
            width = shape[3]
            classMap = argmaxChannelsFirst(floats: floats, numClasses: numClasses, height: height, width: width)
        } else if shape.count == 2 {
            // [H*W] or similar flat output - try sqrt for dimensions
            let total = shape[0] * shape[1]
            let side = Int(sqrt(Double(total)))
            if side * side == total {
                height = side
                width = side
            } else {
                height = spec.inputHeight
                width = spec.inputWidth
            }
            numClasses = 1
            classMap = floats.map { $0 > 0.5 ? 15 : 0 }
        } else {
            // Fallback: try treating as [1, numClasses, H, W]
            if shape.count == 4 {
                numClasses = shape[1]
                height = shape[2]
                width = shape[3]
                classMap = argmaxChannelsFirst(floats: floats, numClasses: numClasses, height: height, width: width)
            } else {
                return nil
            }
        }

        // Pascal VOC class 15 = "person" (whole body including head).
        let personClass = 15
        let totalPixels = width * height

        // 1. Build raw person mask
        var isPerson = [Bool](repeating: false, count: totalPixels)
        for i in 0..<min(totalPixels, classMap.count) {
            isPerson[i] = classMap[i] == personClass
        }

        // 2. Find global bounding box of the person, then zero-out the top 13% (head + neck).
        //    Using a single bounding box gives a clean horizontal cut that doesn't vary per-column.
        var topRow = height, bottomRow = -1
        for i in 0..<min(totalPixels, classMap.count) {
            if classMap[i] == personClass {
                let y = i / width
                if y < topRow    { topRow    = y }
                if y > bottomRow { bottomRow = y }
            }
        }
        if topRow < bottomRow {
            let span = bottomRow - topRow + 1
            let headRows = Int(Double(span) * 0.13)
            for y in topRow..<min(topRow + headRows, height) {
                for x in 0..<width { isPerson[y * width + x] = false }
            }
        }

        // 3. Soft edge: 3-pixel box blur turns the binary mask into a smooth alpha channel.
        let blurRadius = 3
        var softMask = [UInt8](repeating: 0, count: totalPixels)
        for y in 0..<height {
            for x in 0..<width {
                var sum = 0, count = 0
                for dy in -blurRadius...blurRadius {
                    for dx in -blurRadius...blurRadius {
                        let ny = y + dy, nx = x + dx
                        if ny >= 0 && ny < height && nx >= 0 && nx < width {
                            sum += isPerson[ny * width + nx] ? 255 : 0
                            count += 1
                        }
                    }
                }
                softMask[y * width + x] = UInt8(sum / count)
            }
        }

        // 4. Write RGBA mask
        var maskPixels = [UInt8](repeating: 0, count: totalPixels * 4)
        for i in 0..<totalPixels {
            let v = softMask[i]
            let offset = i * 4
            maskPixels[offset]     = v
            maskPixels[offset + 1] = v
            maskPixels[offset + 2] = v
            maskPixels[offset + 3] = 255
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &maskPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }

        let maskImage = UIImage(cgImage: cgImage)

        // Resize mask to original image size
        UIGraphicsBeginImageContextWithOptions(originalSize, false, 1.0)
        maskImage.draw(in: CGRect(origin: .zero, size: originalSize))
        let resizedMask = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedMask
    }

    private func argmaxChannelsFirst(floats: [Float], numClasses: Int, height: Int, width: Int) -> [Int] {
        let totalPixels = height * width
        var classMap = [Int](repeating: 0, count: totalPixels)
        for i in 0..<totalPixels {
            var maxVal: Float = -Float.greatestFiniteMagnitude
            var maxIdx = 0
            for c in 0..<numClasses {
                let idx = c * totalPixels + i
                if idx < floats.count && floats[idx] > maxVal {
                    maxVal = floats[idx]
                    maxIdx = c
                }
            }
            classMap[i] = maxIdx
        }
        return classMap
    }

    private func argmaxChannelsLast(floats: [Float], numClasses: Int, height: Int, width: Int) -> [Int] {
        let totalPixels = height * width
        var classMap = [Int](repeating: 0, count: totalPixels)
        for i in 0..<totalPixels {
            var maxVal: Float = -Float.greatestFiniteMagnitude
            var maxIdx = 0
            for c in 0..<numClasses {
                let idx = i * numClasses + c
                if idx < floats.count && floats[idx] > maxVal {
                    maxVal = floats[idx]
                    maxIdx = c
                }
            }
            classMap[i] = maxIdx
        }
        return classMap
    }
}

struct SegmentationResult {
    let mask: UIImage?
    let latencyMs: Double
    let outputShape: [Int]
}

