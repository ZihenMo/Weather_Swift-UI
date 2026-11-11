import Foundation

// timezone=auto 返回地点当地时间；保留其日期与时钟，避免被设备时区二次转换。
struct LocalForecastTime: Codable, Equatable {
    let date: String
    let clock: String
    let hour: Int

    init?(_ raw: String?) {
        guard let raw else { return nil }
        let parts = raw.split(separator: WeatherContract.timestampSeparator)
        guard parts.count == 2, ForecastDate.parse(String(parts[0])) != nil else { return nil }
        let clock = parts[1].prefix(WeatherContract.clockLength)
        let fields = clock.split(separator: WeatherContract.clockSeparator)
        guard clock.count == WeatherContract.clockLength, fields.count == 2,
            let hour = Int(fields[0]), (0..<WeatherContract.hoursPerDay).contains(hour),
            let minute = Int(fields[1]), (0..<WeatherContract.minutesPerHour).contains(minute)
        else { return nil }
        self.date = String(parts[0])
        self.clock = String(clock)
        self.hour = hour
    }
}

enum ForecastDate {
    static func parse(_ raw: String) -> Date? {
        guard raw.count == WeatherContract.dateLength else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: WeatherContract.posixLocale)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = WeatherContract.dateFormat
        formatter.isLenient = false
        guard let date = formatter.date(from: raw), formatter.string(from: date) == raw else { return nil }
        return date
    }
}

enum Daylight: Int, Codable {
    case night = 0
    case day = 1
    case unknown = -1

    init(apiValue: Int?) { self = apiValue.flatMap(Self.init(rawValue:)) ?? .unknown }
}

struct DailyForecast: Codable, Identifiable {
    var id: String { date }
    let date: String
    let low, high: Double?
    let code: Int?
    let sunset: LocalForecastTime?
}

struct HourlyForecast: Codable {
    let time: LocalForecastTime
    let temperature, precipitationProbability: Double?
    let code: Int?
    let daylight: Daylight
}

enum DayPeriod: Int, CaseIterable, Hashable {
    case night, morning, afternoon, evening

    init(hour: Int) {
        self = DayPeriod(rawValue: hour / WeatherContract.hoursPerPeriod) ?? .night
    }
}

struct Forecast: Codable {
    let time: LocalForecastTime?
    let temperature, feelsLike, humidity, wind: Double?
    let code: Int?
    let daylight: Daylight
    let days: [DailyForecast]
    let hours: [HourlyForecast]

    func hours(on date: String, in period: DayPeriod) -> [HourlyForecast] {
        hours.filter { $0.time.date == date && DayPeriod(hour: $0.time.hour) == period }
    }

    func initialPeriod(for date: String) -> DayPeriod {
        guard let time, time.date == date else { return .night }
        return DayPeriod(hour: time.hour)
    }
}

struct ForecastSnapshot: Codable {
    let point: Coordinates
    let forecast: Forecast
    let fetchedAt: Date

    func isUsable(at now: Date, policy: WeatherPolicy) -> Bool {
        let age = now.timeIntervalSince(fetchedAt)
        return age >= 0 && age < policy.displayInterval
    }

    func isFresh(at now: Date, policy: WeatherPolicy) -> Bool {
        isUsable(at: now, policy: policy) && now.timeIntervalSince(fetchedAt) < policy.freshInterval
    }
}
