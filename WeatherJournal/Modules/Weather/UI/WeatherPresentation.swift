import Foundation
import SwiftUI

enum WeatherPresentation {
    static func degrees(_ value: Double?) -> String {
        guard let value else { return WeatherFormat.unavailable }
        return value.formatted(.number.precision(.fractionLength(WeatherFormat.degreePrecision)))
            + WeatherFormat.degrees
    }

    static func metric(_ value: Double?, unit: String) -> String {
        guard let value else { return WeatherFormat.unavailable }
        return value.formatted(.number.precision(.fractionLength(WeatherFormat.metricPrecision))) + unit
    }

    static func date(_ raw: String, locale: Locale) -> String {
        guard let day = ForecastDate.parse(raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate(WeatherContract.dateTemplate)
        return formatter.string(from: day)
    }

    static func timestamp(_ time: LocalForecastTime, locale: Locale) -> String {
        date(time.date, locale: locale) + WeatherFormat.dateSeparator + time.clock
    }

    static func cachedAt(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func condition(_ code: Int?, daylight: Daylight) -> (art: String, label: LocalizedText) {
        switch WeatherCondition(code: code) {
        case .clear:
            switch daylight {
            case .day: return (WeatherAsset.sun, WeatherText.clear)
            case .night: return (WeatherAsset.moon, WeatherText.clear)
            case .unknown: return (WeatherAsset.cloud, WeatherText.clear)
            }
        case .cloudy: return (daylight == .night ? WeatherAsset.moonCloud : WeatherAsset.cloud, WeatherText.cloudy)
        case .fog: return (WeatherAsset.cloud, WeatherText.fog)
        case .snow: return (WeatherAsset.cloud, WeatherText.snow)
        case .thunderstorm: return (WeatherAsset.rain, WeatherText.thunderstorm)
        case .rain: return (WeatherAsset.rain, WeatherText.rain)
        case .unknown: return (WeatherAsset.cloud, WeatherText.unknown)
        }
    }
}

/// 装饰图片不单独朗读，天气语义由相邻文字或所属组件提供。
struct WeatherArt: View {
    let name: String
    let size: CGFloat
    var body: some View {
        Image(decorative: name).resizable().scaledToFit().frame(width: size, height: size)
    }
}
