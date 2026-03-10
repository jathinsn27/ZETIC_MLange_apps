import Foundation
import UIKit
import CoreGraphics

final class ColorSwapEngine {

    /// Recolor the masked clothing region using HSL color space.
    ///
    /// Why HSL and not HSB?
    /// - HSL lightness L is perceptually linear: L=0 → black, L=1 → white, L=0.5 → pure color.
    /// - Keeping L 100% from the original preserves every shadow, highlight, wrinkle and texture
    ///   detail in the fabric, while replacing only the hue and saturation.
    /// - HSB brightness breaks down on dark pixels (B≈0 means black regardless of hue/sat),
    ///   which caused split-color artifacts on dark garments.
    static func applyColor(
        to originalImage: UIImage,
        mask: UIImage,
        color: (r: CGFloat, g: CGFloat, b: CGFloat)
    ) -> UIImage? {
        let size = originalImage.size
        guard let originalCG = originalImage.cgImage,
              let maskCG = mask.cgImage else { return nil }

        let width  = Int(size.width)
        let height = Int(size.height)
        let totalPixels = width * height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)

        guard
            let origCtx = CGContext(data: nil, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: colorSpace, bitmapInfo: bitmapInfo.rawValue),
            let maskCtx = CGContext(data: nil, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: colorSpace, bitmapInfo: bitmapInfo.rawValue),
            let outCtx  = CGContext(data: nil, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        else { return nil }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        origCtx.draw(originalCG, in: rect)
        maskCtx.draw(maskCG,     in: rect)
        outCtx.draw(originalCG,  in: rect)

        guard
            let origData = origCtx.data,
            let maskData = maskCtx.data,
            let outData  = outCtx.data
        else { return nil }

        let origPtr = origData.bindMemory(to: UInt8.self, capacity: totalPixels * 4)
        let maskPtr = maskData.bindMemory(to: UInt8.self, capacity: totalPixels * 4)
        let outPtr  = outData.bindMemory(to: UInt8.self,  capacity: totalPixels * 4)

        // Target in HSL — we only need its hue and saturation.
        let (tgtH, tgtS, _) = rgbToHSL(
            r: Float(color.r), g: Float(color.g), b: Float(color.b))

        for i in 0..<totalPixels {
            let offset    = i * 4
            let maskAlpha = Float(maskPtr[offset]) / 255.0
            guard maskAlpha > 0.01 else { continue }

            let origR = Float(origPtr[offset])     / 255.0
            let origG = Float(origPtr[offset + 1]) / 255.0
            let origB = Float(origPtr[offset + 2]) / 255.0

            // Original in HSL
            let (_, origS, origL) = rgbToHSL(r: origR, g: origG, b: origB)

            // ── The key operation ──────────────────────────────────────────
            // Replace hue → target hue
            // Blend saturation  → mostly target (85%), keep a hint of original (15%)
            //   so that near-neutral fabrics get full target color,
            //   while already-saturated fabrics keep some of their character.
            // Keep lightness 100% from original pixel.
            //   This preserves every shadow, fold and highlight in the fabric.
            // ──────────────────────────────────────────────────────────────
            let newH = tgtH
            let newS = tgtS * 0.85 + origS * 0.15
            let newL = origL

            let (newR, newG, newB) = hslToRGB(h: newH, s: newS, l: newL)

            // Composite: recolored × maskAlpha + original × (1 − maskAlpha)
            let invA = 1.0 - maskAlpha
            outPtr[offset]     = clamp(newR * 255.0 * maskAlpha + Float(origPtr[offset])     * invA)
            outPtr[offset + 1] = clamp(newG * 255.0 * maskAlpha + Float(origPtr[offset + 1]) * invA)
            outPtr[offset + 2] = clamp(newB * 255.0 * maskAlpha + Float(origPtr[offset + 2]) * invA)
            outPtr[offset + 3] = origPtr[offset + 3]
        }

        guard let cgOut = outCtx.makeImage() else { return nil }
        return UIImage(cgImage: cgOut)
    }

    // MARK: - HSL ↔ RGB helpers

    /// RGB (0…1) → HSL (0…1 each)
    private static func rgbToHSL(r: Float, g: Float, b: Float) -> (h: Float, s: Float, l: Float) {
        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let delta = maxC - minC
        let l = (maxC + minC) * 0.5

        guard delta > 0.00001 else { return (0, 0, l) }

        let s = l > 0.5
            ? delta / (2.0 - maxC - minC)
            : delta / (maxC + minC)

        var h: Float
        switch maxC {
        case r:
            h = ((g - b) / delta).truncatingRemainder(dividingBy: 6.0)
            if h < 0 { h += 6.0 }
        case g:
            h = (b - r) / delta + 2.0
        default:
            h = (r - g) / delta + 4.0
        }
        return (h / 6.0, s, l)
    }

    /// HSL (0…1 each) → RGB (0…1)
    private static func hslToRGB(h: Float, s: Float, l: Float) -> (r: Float, g: Float, b: Float) {
        guard s > 0.00001 else { return (l, l, l) }
        let q = l < 0.5 ? l * (1.0 + s) : l + s - l * s
        let p = 2.0 * l - q
        return (
            hue2rgb(p: p, q: q, t: h + 1.0 / 3.0),
            hue2rgb(p: p, q: q, t: h),
            hue2rgb(p: p, q: q, t: h - 1.0 / 3.0)
        )
    }

    private static func hue2rgb(p: Float, q: Float, t: Float) -> Float {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1.0 / 6.0 { return p + (q - p) * 6.0 * t }
        if t < 0.5        { return q }
        if t < 2.0 / 3.0  { return p + (q - p) * (2.0 / 3.0 - t) * 6.0 }
        return p
    }

    @inline(__always)
    private static func clamp(_ v: Float) -> UInt8 {
        UInt8(min(255, max(0, v)))
    }
}
