import Foundation
import UIKit

struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let colorName: String
    let latencyMs: Double
    let originalImagePath: String
    let resultImagePath: String

    init(colorName: String, latencyMs: Double, originalImagePath: String, resultImagePath: String) {
        self.id = UUID()
        self.date = Date()
        self.colorName = colorName
        self.latencyMs = latencyMs
        self.originalImagePath = originalImagePath
        self.resultImagePath = resultImagePath
    }

    static func loadAll() -> [SessionRecord] {
        guard let data = UserDefaults.standard.data(forKey: "SessionHistory"),
              let records = try? JSONDecoder().decode([SessionRecord].self, from: data) else {
            return []
        }
        return records
    }

    static func saveAll(_ records: [SessionRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "SessionHistory")
        }
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: "SessionHistory")
        let dir = imagesDirectory
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    static var imagesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("SimpleSwapHistory", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func saveImage(_ image: UIImage, name: String) -> String {
        let url = imagesDirectory.appendingPathComponent(name)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url)
        }
        return name
    }

    static func loadImage(name: String) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

