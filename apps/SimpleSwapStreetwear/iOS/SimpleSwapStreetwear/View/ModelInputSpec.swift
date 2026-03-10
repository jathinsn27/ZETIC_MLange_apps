import Foundation

struct ModelInputSpec: Codable {
    var inputWidth: Int
    var inputHeight: Int
    var colorSpace: ColorSpaceOption
    var normalization: NormalizationOption
    var rotationDegrees: Int

    enum ColorSpaceOption: String, Codable, CaseIterable {
        case rgb = "RGB"
        case bgr = "BGR"
    }

    enum NormalizationOption: String, Codable, CaseIterable {
        case zeroToOne = "0..1"
        case negOneToOne = "-1..1"
        case imageNet = "ImageNet"
        case zeroTo255 = "0..255"
    }

    /// Default matches export.py: (1, 3, 520, 520) → 520×520, 3 channels = 811_200 elements (Zetic MLange converter input).
    static let `default` = ModelInputSpec(
        inputWidth: 520,
        inputHeight: 520,
        colorSpace: .rgb,
        normalization: .imageNet,
        rotationDegrees: 0
    )

    /// Model traced with 520×520 in export.py; old saved specs are migrated to this.
    static func load() -> ModelInputSpec {
        guard let data = UserDefaults.standard.data(forKey: "ModelInputSpec"),
              let spec = try? JSONDecoder().decode(ModelInputSpec.self, from: data) else {
            return .default
        }
        if spec.inputWidth != 520 || spec.inputHeight != 520 {
            return .default
        }
        return spec
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "ModelInputSpec")
        }
    }
}

