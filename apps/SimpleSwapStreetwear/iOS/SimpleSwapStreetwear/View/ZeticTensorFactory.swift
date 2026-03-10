import Foundation
import UIKit
import ZeticMLange

enum ZeticTensorFactoryError: Error {
    case imageConversionFailed
    case contextCreationFailed
    case dataExtractionFailed
}

final class ZeticTensorFactory {

    /// Redraw a UIImage so its pixel data matches the visual orientation (strips EXIF rotation).
    static func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return normalized
    }

    static func createImageTensor(from image: UIImage, spec: ModelInputSpec) throws -> Tensor {
        let upright = normalizeOrientation(image)
        let width = spec.inputWidth
        let height = spec.inputHeight
        let targetSize = CGSize(width: width, height: height)

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        upright.draw(in: CGRect(origin: .zero, size: targetSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = resized?.cgImage else {
            throw ZeticTensorFactoryError.imageConversionFailed
        }

        let totalPixels = width * height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw ZeticTensorFactoryError.contextCreationFailed
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = context.data else {
            throw ZeticTensorFactoryError.dataExtractionFailed
        }

        let ptr = pixelData.bindMemory(to: UInt8.self, capacity: totalPixels * 4)
        var floatArray = [Float](repeating: 0.0, count: 3 * totalPixels)

        let isRGB = spec.colorSpace == .rgb

        for i in 0..<totalPixels {
            let offset = i * 4
            let rRaw = Float(ptr[offset])
            let gRaw = Float(ptr[offset + 1])
            let bRaw = Float(ptr[offset + 2])

            let r: Float
            let g: Float
            let b: Float

            switch spec.normalization {
            case .zeroToOne:
                r = rRaw / 255.0
                g = gRaw / 255.0
                b = bRaw / 255.0
            case .negOneToOne:
                r = (rRaw / 127.5) - 1.0
                g = (gRaw / 127.5) - 1.0
                b = (bRaw / 127.5) - 1.0
            case .imageNet:
                r = (rRaw / 255.0 - 0.485) / 0.229
                g = (gRaw / 255.0 - 0.456) / 0.224
                b = (bRaw / 255.0 - 0.406) / 0.225
            case .zeroTo255:
                r = rRaw
                g = gRaw
                b = bRaw
            }

            if isRGB {
                floatArray[i] = r
                floatArray[totalPixels + i] = g
                floatArray[2 * totalPixels + i] = b
            } else {
                floatArray[i] = b
                floatArray[totalPixels + i] = g
                floatArray[2 * totalPixels + i] = r
            }
        }

        let data = floatArray.withUnsafeBufferPointer { Data(buffer: $0) }
        return Tensor(
            data: data,
            dataType: BuiltinDataType.float32,
            shape: [1, 3, height, width]
        )
    }

    static func extractFloatArray(from tensor: Tensor) -> [Float] {
        return tensor.data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: Float.self) else { return [] }
            let count = ptr.count / MemoryLayout<Float>.size
            return Array(UnsafeBufferPointer(start: base, count: count))
        }
    }

    static func extractInt64Array(from tensor: Tensor) -> [Int64] {
        return tensor.data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: Int64.self) else { return [] }
            let count = ptr.count / MemoryLayout<Int64>.size
            return Array(UnsafeBufferPointer(start: base, count: count))
        }
    }
}

