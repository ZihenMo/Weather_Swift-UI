import SwiftUI

enum WeatherStyle {
    static let navigationHeight: CGFloat = 54
    static let compactNavigationWidth: CGFloat = 330
    static let navigationTitlePriority: Double = -1
    static let sectionTop: CGFloat = 15
    static let sectionBottom: CGFloat = 7
    static let summaryVerticalPadding: CGFloat = 16
    static let extremeSpacing: CGFloat = 16
    static let accessibleHourWidth: CGFloat = 100
    static let temperatureSize: CGFloat = 65
    static let heroHeight: CGFloat = 205
    static let previewHeroHeight: CGFloat = 180
    static let heroVerticalPadding: CGFloat = 18
    static let heroNameTracking: CGFloat = 0.45
    static let temperatureTrackingRatio: CGFloat = -0.07
    static let heroFootSpacing: CGFloat = 10
    static let conditionBottom: CGFloat = 7
    static let locationIcon: CGFloat = 13
    static let conditionIcon: CGFloat = 23
    static let dayIcon: CGFloat = 27
    static let hourIcon: CGFloat = 28
    static let detailIcon: CGFloat = 36
    static let metricIcon: CGFloat = 16
    static let dayRowHeight: CGFloat = 45
    static let dayRowPadding: CGFloat = 2
    static let chevronWidth: CGFloat = 10
    static let minimumLabelScale: CGFloat = 0.8
    static let dateColumnRatio: CGFloat = 1.08
    static let conditionColumnRatio: CGFloat = 0.85
    static let temperatureColumnRatio: CGFloat = 1.1
    static let forecastColumnGap: CGFloat = 4
    static let forecastGapCount: CGFloat = 3
    static let rangeWidth: CGFloat = 37
    static let rangeHeight: CGFloat = 4
    static let minimumRangeWidth: CGFloat = 2
    static let metricRadius: CGFloat = 15
    static let summaryRadius: CGFloat = 21
    static let hourCardRadius: CGFloat = 20
    static let hourCardHorizontalPadding: CGFloat = 10
    static let hourCardTopPadding: CGFloat = 14
    static let hourCardBottomPadding: CGFloat = 16
    static let periodRadius: CGFloat = 12
    static let periodButtonRadius: CGFloat = 9
    static let periodButtonHeight: CGFloat = 37
    static let periodBottom: CGFloat = 19
    static let hourIconTop: CGFloat = 9
    static let hourIconBottom: CGFloat = 5
    static let trendHeight: CGFloat = 44
    static let trendTop: CGFloat = 3
    static let trendBottom: CGFloat = 10
    static let trendTopInset: CGFloat = 8
    static let trendBottomInset: CGFloat = 8
    static let precipitationIcon: CGFloat = 14
    static let pointRadius: CGFloat = 2.5
    static let lineWidth: CGFloat = 2
    static let cellCenter: CGFloat = 0.5
    static let shadowRadius: CGFloat = 5
    static let shadowOffset: CGFloat = 2

    enum FontSize {
        static let place: CGFloat = 30
        static let body: CGFloat = 15
        static let caption: CGFloat = 12
        static let date: CGFloat = 10
        static let temperatureRange: CGFloat = 13
        static let metric: CGFloat = 23
        static let summary: CGFloat = 20
        static let extremeLabel: CGFloat = 11
        static let extreme: CGFloat = 24
        static let back: CGFloat = 16
        static let navigation: CGFloat = 18
        static let period: CGFloat = 13
        static let hourTemperature: CGFloat = 19
        static let precipitation: CGFloat = 13
    }

    enum Color {
        static let heroStart = SwiftUI.Color(red: 0.114, green: 0.259, blue: 0.365).opacity(0.82)
        static let heroMiddle = SwiftUI.Color(red: 0.118, green: 0.271, blue: 0.373).opacity(0.33)
        static let forecastLine = SwiftUI.Color(red: 0.851, green: 0.890, blue: 0.922)
        static let track = SwiftUI.Color(red: 0.902, green: 0.929, blue: 0.941)
        static let rangeCool = SwiftUI.Color(red: 0.451, green: 0.686, blue: 0.749)
        static let rangeWarm = SwiftUI.Color(red: 0.941, green: 0.741, blue: 0.412)
        static let summaryStart = SwiftUI.Color(red: 0.192, green: 0.357, blue: 0.471)
        static let summaryEnd = SwiftUI.Color(red: 0.400, green: 0.537, blue: 0.604)
        static let extremeLabel = SwiftUI.Color(red: 0.918, green: 0.949, blue: 0.973)
        static let hourCardBottom = SwiftUI.Color(red: 0.965, green: 0.984, blue: 1)
        static let hourBorder = SwiftUI.Color(red: 0.855, green: 0.894, blue: 0.922)
        static let hourShadow = SwiftUI.Color(red: 0.286, green: 0.420, blue: 0.506).opacity(0.06)
        static let periodBackground = SwiftUI.Color(red: 0.910, green: 0.937, blue: 0.957)
        static let periodText = SwiftUI.Color(red: 0.290, green: 0.396, blue: 0.471)
        static let selectedPeriod = SwiftUI.Color(red: 0.110, green: 0.310, blue: 0.447)
        static let periodShadow = SwiftUI.Color(red: 0.133, green: 0.239, blue: 0.337).opacity(0.15)
        static let hourTime = SwiftUI.Color(red: 0.286, green: 0.376, blue: 0.455)
        static let trend = SwiftUI.Color(red: 0.357, green: 0.565, blue: 0.667)
        static let trendFill = SwiftUI.Color(red: 0.573, green: 0.722, blue: 0.808)
        static let precipitationLine = SwiftUI.Color(red: 0.863, green: 0.902, blue: 0.933)
    }

    static let heroGradient = Gradient(stops: [
        .init(color: Color.heroStart, location: 0), .init(color: Color.heroMiddle, location: 0.48),
        .init(color: .clear, location: 0.80),
    ])
    static let hourGradient = Gradient(stops: [
        .init(color: .white, location: 0.45), .init(color: Color.hourCardBottom, location: 1),
    ])
    static let trendGradient = Gradient(colors: [Color.trendFill.opacity(0.48), Color.trendFill.opacity(0.03)])
}

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
