import Foundation
import UIKit

/// 课表背景图管理：存取 Documents 下的背景图（供网格 30% 透明度衬底）。
enum ScheduleBackground {
    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("schedule_background.jpg")
    }

    /// 保存图片（压缩到合适尺寸，避免大图内存压力）。
    static func save(_ data: Data) {
        if let image = UIImage(data: data),
           let resized = resizeIfNeeded(image),
           let jpeg = resized.jpegData(compressionQuality: 0.85) {
            try? jpeg.write(to: fileURL, options: .atomic)
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    static func load() -> UIImage? {
        UIImage(contentsOfFile: fileURL.path)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// 长边超过 2000px 的缩到 2000。
    private static func resizeIfNeeded(_ image: UIImage) -> UIImage? {
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > 2000 else { return image }
        let scale = 2000 / maxSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
