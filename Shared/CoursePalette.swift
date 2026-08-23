import SwiftUI

/// 课程卡片配色（移植安卓端两套主题，按课程名稳定 hash 分配，同名课同色）。
///
/// - `default`：偏蓝中间亮度纯色底 + 白字
/// - `bright`：粉彩浅底（HSL 高亮度低饱和）+ 同色相深字
enum CourseColorStyle: String, CaseIterable, Identifiable {
    case `default`
    case bright
    var id: String { rawValue }
}

struct CoursePalette {
    let background: Color
    let text: Color

    /// 稳定 hash（djb2）。不能用 Swift 的 hashValue——每次启动随机化会导致颜色跳变。
    static func stableHash(_ name: String) -> UInt64 {
        var h: UInt64 = 5381
        for byte in name.utf8 {
            h = (h << 5) &+ h &+ UInt64(byte)
        }
        return h
    }

    static func color(for courseName: String, style: CourseColorStyle) -> CoursePalette {
        let hash = stableHash(courseName)
        switch style {
        case .default:
            // 安卓 generateCourseColor：r=100+|h|%100, g=120+|h>>8|%80, b=150+|h>>16|%80
            let r: Double = 100 + Double(hash % 100)
            let g: Double = 120 + Double((hash >> 8) % 80)
            let b: Double = 150 + Double((hash >> 16) % 80)
            return CoursePalette(background: Color(red: r / 255, green: g / 255, blue: b / 255),
                                 text: .white)
        case .bright:
            // 安卓 generateBrightColors：12 个参考色相取模 + ±10° 偏移
            let hues: [Double] = [0, 20, 30, 160, 180, 200, 260, 280, 300, 330, 345, 15]
            let hue: Double = hues[Int(hash % 12)] + Double((hash >> 8) % 21) - 10
            let bg = hsl(hue: hue, saturation: 0.62, lightness: 0.92)
            let tx = hsl(hue: hue, saturation: 0.67, lightness: 0.48)
            return CoursePalette(background: bg, text: tx)
        }
    }

    /// HSL → RGB Color。
    private static func hsl(hue: Double, saturation: Double, lightness: Double) -> Color {
        let h = ((hue.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360) / 60
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double)
        switch h {
        case ..<1: (r1, g1, b1) = (c, x, 0)
        case ..<2: (r1, g1, b1) = (x, c, 0)
        case ..<3: (r1, g1, b1) = (0, c, x)
        case ..<4: (r1, g1, b1) = (0, x, c)
        case ..<5: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        let m = lightness - c / 2
        return Color(red: r1 + m, green: g1 + m, blue: b1 + m)
    }
}
