import SwiftUI

/// 浅色界面的语义颜色；业务插画和图表配色留在使用处。
enum AppColor {
    static let textPrimary = Color(red: 23 / 255, green: 43 / 255, blue: 61 / 255)
    static let textSecondary = Color(red: 83 / 255, green: 106 / 255, blue: 121 / 255)
    static let textOnAccent = Color.white
    static let accent = Color(red: 36 / 255, green: 101 / 255, blue: 142 / 255)
    static let background = Color(red: 238 / 255, green: 243 / 255, blue: 248 / 255)
    static let surface = Color.white
    static let surfaceRaised = Color(red: 245 / 255, green: 248 / 255, blue: 251 / 255)
    static let fill = Color(red: 229 / 255, green: 235 / 255, blue: 240 / 255)
    static let border = Color(red: 217 / 255, green: 227 / 255, blue: 235 / 255)
    static let warningBackground = Color(red: 255 / 255, green: 245 / 255, blue: 223 / 255)
    static let scrim = Color(red: 22 / 255, green: 43 / 255, blue: 58 / 255).opacity(1 / 3)
}
