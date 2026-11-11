import SwiftUI

enum WeatherStyle {
    static let accessibleHourWidth: CGFloat = 100
    static let temperatureSize: CGFloat = 64
    static let heroHeight: CGFloat = 205
    static let conditionIcon: CGFloat = 26
    static let dayIcon: CGFloat = 28
    static let detailIcon: CGFloat = 36
    static let metricIcon: CGFloat = 18
    static let dayRowPadding: CGFloat = 9
    static let gradientStart = 0.97
    static let gradientEnd = 0.45
    static let rangeWidth: CGFloat = 40
    static let rangeHeight: CGFloat = 5
    static let minimumRangeWidth: CGFloat = 2
    static let trendHeight: CGFloat = 42
    static let trendInset: CGFloat = 5
    static let pointRadius: CGFloat = 2.5
    static let lineWidth: CGFloat = 2
    static let cellCenter: CGFloat = 0.5
}

enum WeatherAsset {
    static let sun = "sun", moon = "moon", cloud = "cloud", moonCloud = "moon-cloud", rain = "rain"
    static let harbour = "harbour", thermometer = "thermometer", humidity = "drop", wind = "wind", sunset = "sunset"
}

enum WeatherFormat {
    static let unavailable = "—", degrees = "°", percent = "%", windUnit = " km/h"
    static let extremes = "↑ %@   ↓ %@"
    static let dateSeparator = " · "
    static let degreePrecision = 0
    static let metricPrecision = 0...1
}

enum WeatherIdentifier {
    static let top = "weather-top"
    static func day(_ date: String) -> String { "day-\(date)" }
}
