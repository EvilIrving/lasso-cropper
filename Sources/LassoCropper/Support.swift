import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

enum LassoError: LocalizedError {
    case noImage
    case noSelection
    case noDestination
    case invalidSelection
    case unreadable
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noImage: return "请先打开图片"
        case .noSelection: return "还没有圈完任何图形"
        case .noDestination: return "请先选择导出文件夹"
        case .invalidSelection: return "套索区域太小"
        case .unreadable: return "无法打开这张图片"
        case .exportFailed(let name): return "无法写入 \(name)"
        }
    }
}

struct SlotSpec {
    var folder: String
    var name: String

    var id: String { folder.isEmpty ? name : "\(folder)/\(name)" }
    var fileName: String { "\(name).png" }

    var shortLabel: String {
        if let dash = name.firstIndex(of: "-") {
            return String(name[name.index(after: dash)...])
        }
        return name
    }
}

struct LassoCut: Codable {
    var points: [CGPoint]

    var bounds: CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    var centroid: CGPoint {
        guard !points.isEmpty else { return .zero }
        let total = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: total.x / CGFloat(points.count), y: total.y / CGFloat(points.count))
    }

    var pathLength: CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }

    var isUsable: Bool {
        points.count >= 3 && pathLength >= 18 && bounds.width >= 6 && bounds.height >= 6
    }

    func contains(_ point: CGPoint) -> Bool {
        let path = CGMutablePath()
        guard let first = points.first else { return false }
        path.move(to: first)
        for item in points.dropFirst() { path.addLine(to: item) }
        path.closeSubpath()
        return path.contains(point)
    }
}

struct Slot {
    var spec: SlotSpec
    var cut: LassoCut?
    var preview: NSImage?
}

enum JobFactory {
    static func defaultDestination(for source: URL) -> URL {
        let name = source.deletingPathExtension().lastPathComponent + "-导出"
        return source.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
    }
}

enum ImageLoading {
    static func load(url: URL) throws -> CGImage {
        let data = try Data(contentsOf: url)
        if let image = NSImage(data: data) {
            var rect = CGRect(origin: .zero, size: image.size)
            if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
               cgImage.width > 1, cgImage.height > 1 {
                return cgImage
            }
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: true] as CFDictionary),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LassoError.unreadable
        }
        return image
    }
}

enum LassoExport {
    static func render(source: CGImage, cut: LassoCut, canvasSize: Int, marginPercent: Double) throws -> CGImage {
        let imageBounds = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        let box = cut.bounds.integral.intersection(imageBounds)
        guard box.width >= 2, box.height >= 2 else { throw LassoError.invalidSelection }

        let margin = CGFloat(canvasSize) * CGFloat(max(0, min(30, marginPercent))) / 100
        let available = max(8, CGFloat(canvasSize) - margin * 2)
        let scale = min(available / box.width, available / box.height)
        let targetSize = CGSize(width: box.width * scale, height: box.height * scale)
        let target = CGRect(
            x: (CGFloat(canvasSize) - targetSize.width) / 2,
            y: (CGFloat(canvasSize) - targetSize.height) / 2,
            width: targetSize.width,
            height: targetSize.height
        )

        guard let context = CGContext(
            data: nil,
            width: canvasSize,
            height: canvasSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw LassoError.exportFailed("canvas") }

        let clip = CGMutablePath()
        for (index, point) in cut.points.enumerated() {
            let mapped = CGPoint(
                x: target.minX + (point.x - box.minX) * scale,
                y: target.maxY - (point.y - box.minY) * scale
            )
            if index == 0 { clip.move(to: mapped) } else { clip.addLine(to: mapped) }
        }
        clip.closeSubpath()
        context.addPath(clip)
        context.clip()
        context.interpolationQuality = .high
        context.draw(
            source,
            in: CGRect(
                x: target.minX - box.minX * scale,
                y: target.maxY - (CGFloat(source.height) - box.minY) * scale,
                width: CGFloat(source.width) * scale,
                height: CGFloat(source.height) * scale
            )
        )
        guard let image = context.makeImage() else { throw LassoError.exportFailed("image") }
        return image
    }

    static func write(_ image: CGImage, to url: URL) throws {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { throw LassoError.exportFailed(url.lastPathComponent) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw LassoError.exportFailed(url.lastPathComponent)
        }
    }

    static func previewImage(source: CGImage, cut: LassoCut, canvasSize: Int, marginPercent: Double) -> NSImage? {
        guard let image = try? render(source: source, cut: cut, canvasSize: canvasSize, marginPercent: marginPercent) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: canvasSize, height: canvasSize))
    }
}

struct LassoSession: Codable {
    var source: String
    var destination: String?
    var canvasSize: Int
    var marginPercent: Double
    var selectedIndex: Int
    var cuts: [PersistedCut]

    struct PersistedCut: Codable {
        var id: String
        var points: [CGPoint]
    }
}

enum SessionStore {
    static func load(source: URL) -> LassoSession? {
        let url = fileURL(for: source)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LassoSession.self, from: data)
    }

    static func save(_ session: LassoSession, source: URL) {
        let url = fileURL(for: source)
        let folder = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func fileURL(for source: URL) -> URL {
        let digest = SHA256.hash(data: Data(source.standardizedFileURL.path.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return supportDirectory.appendingPathComponent("\(name).json")
    }

    private static var supportDirectory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return root.appendingPathComponent("LassoCropper/sessions", isDirectory: true)
    }
}

enum Defaults {
    static let canvasKey = "canvasSize"
    static let marginKey = "marginPercent"
    static let destinationKey = "lastDestination"

    static var canvasSize: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: canvasKey)
            return [256, 512, 1024].contains(value) ? value : 512
        }
        set { UserDefaults.standard.set(newValue, forKey: canvasKey) }
    }

    static var marginPercent: Double {
        get {
            if UserDefaults.standard.object(forKey: marginKey) == nil { return 8 }
            return min(20, max(0, UserDefaults.standard.double(forKey: marginKey)))
        }
        set { UserDefaults.standard.set(newValue, forKey: marginKey) }
    }

    static var lastDestination: URL? {
        get { UserDefaults.standard.string(forKey: destinationKey).map(URL.init(fileURLWithPath:)) }
        set { UserDefaults.standard.set(newValue?.path, forKey: destinationKey) }
    }
}
