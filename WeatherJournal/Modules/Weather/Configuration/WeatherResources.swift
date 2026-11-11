import Foundation

enum WeatherAsset {
    static let sun = "sun", moon = "moon", cloud = "cloud", moonCloud = "moon-cloud", rain = "rain"
    static let harbour = "harbour", thermometer = "thermometer", humidity = "drop", wind = "wind", sunset = "sunset"
}

enum WeatherFormat {
    static let unavailable = "—", degrees = "°", percent = "%", windUnit = " km/h"
    static let dateSeparator = " · ", wordSeparator = " ", extremesSeparator = "　"
    static let degreePrecision = 0
    static let metricPrecision = 0
    static let monthDayTemplate = "MMMd", weekdayTemplate = "EEE", shortDateFormat = "M/dd"
}

enum WeatherIdentifier {
    static let top = "weather-top"
    static func day(_ date: String) -> String { "day-\(date)" }
}
