import SwiftUI

// Stealth Lime — locked design direction (SPEC §2). All-black, acid-lime accent.
enum Theme {
    static let bg     = Color(hex: 0x08080A)   // near-black canvas
    static let card   = Color(hex: 0x141417)
    static let line   = Color(hex: 0x26262B)
    static let txt    = Color(hex: 0xF5F5F7)
    static let mut    = Color(hex: 0x9A9AA0)
    static let acc    = Color(hex: 0xC8FF3D)   // acid lime
    static let amber  = Color(hex: 0xFFC24B)
    static let red    = Color(hex: 0xFF5A4D)
}

// Rank tier accent colors (CONTEXT.md).
enum Tier: String, CaseIterable {
    case bronze, silver, gold, platinum, diamond, elite, mythic, greek_god

    var label: String {
        switch self {
        case .greek_god: return "Greek God"
        default: return rawValue.capitalized
        }
    }
    var color: Color {
        switch self {
        case .bronze:   return Color(hex: 0xB0764A)
        case .silver:   return Color(hex: 0xC9CDD4)
        case .gold:     return Color(hex: 0xFFC24B)
        case .platinum: return Color(hex: 0x6FE0C8)
        case .diamond:  return Color(hex: 0x7FD0FF)
        case .elite:    return Color(hex: 0xC08BFF)
        case .mythic:   return Color(hex: 0xFF7AB0)
        case .greek_god:return Color(hex: 0xC8FF3D)
        }
    }
}

// Lime the brand word "Stetic" wherever it appears in a sentence.
func brandLimed(_ s: String) -> AttributedString {
    var attr = AttributedString(s)
    var start = attr.startIndex
    while let r = attr[start...].range(of: "Stetic") {
        attr[r].foregroundColor = Theme.acc
        start = r.upperBound
    }
    return attr
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue:  Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
