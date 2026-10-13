import Foundation
import SwiftUI

struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
}

enum AppTheme: String, CaseIterable, Identifiable {
    case parchment = "羊皮纸"
    case seaGlass = "海盐蓝"
    case sage = "鼠尾草"
    case dusk = "暮色"

    var id: String { rawValue }

    var palette: ThemePalette {
        switch self {
        case .parchment:
            ThemePalette(canvas: Color(red: 0.965, green: 0.949, blue: 0.914), panel: Color(red: 0.991, green: 0.982, blue: 0.960), ink: Color(red: 0.20, green: 0.22, blue: 0.21), muted: Color(red: 0.48, green: 0.49, blue: 0.45), accent: Color(red: 0.73, green: 0.36, blue: 0.22), border: Color(red: 0.88, green: 0.86, blue: 0.81), dark: false)
        case .seaGlass:
            ThemePalette(canvas: Color(red: 0.91, green: 0.95, blue: 0.95), panel: Color(red: 0.97, green: 0.99, blue: 0.985), ink: Color(red: 0.15, green: 0.24, blue: 0.26), muted: Color(red: 0.39, green: 0.51, blue: 0.53), accent: Color(red: 0.18, green: 0.48, blue: 0.52), border: Color(red: 0.81, green: 0.87, blue: 0.87), dark: false)
        case .sage:
            ThemePalette(canvas: Color(red: 0.92, green: 0.94, blue: 0.88), panel: Color(red: 0.98, green: 0.985, blue: 0.95), ink: Color(red: 0.22, green: 0.26, blue: 0.20), muted: Color(red: 0.45, green: 0.50, blue: 0.42), accent: Color(red: 0.35, green: 0.48, blue: 0.30), border: Color(red: 0.83, green: 0.87, blue: 0.77), dark: false)
        case .dusk:
            ThemePalette(canvas: Color(red: 0.105, green: 0.12, blue: 0.14), panel: Color(red: 0.15, green: 0.17, blue: 0.19), ink: Color(red: 0.91, green: 0.91, blue: 0.88), muted: Color(red: 0.60, green: 0.63, blue: 0.63), accent: Color(red: 0.92, green: 0.59, blue: 0.40), border: Color(red: 0.25, green: 0.28, blue: 0.29), dark: true)
        }
    }
}

struct ThemePalette {
    let canvas: Color
    let panel: Color
    let ink: Color
    let muted: Color
    let accent: Color
    let border: Color
    let dark: Bool
}
