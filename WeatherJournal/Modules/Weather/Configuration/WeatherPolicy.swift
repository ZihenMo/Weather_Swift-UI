import Foundation

struct WeatherPolicy {
    let freshInterval: TimeInterval
    let displayInterval: TimeInterval
    let cacheCapacity: Int

    static let standard = WeatherPolicy(freshInterval: 15 * 60, displayInterval: 24 * 60 * 60, cacheCapacity: 20)
}

enum WeatherContract {
    static let forecastDays = 7
    static let hoursPerPeriod = 6
    static let hoursPerDay = 24
    static let minutesPerHour = 60
    static let dateLength = 10
    static let clockLength = 5
    static let dateFormat = "yyyy-MM-dd"
    static let dateTemplate = "MMMEd"
    static let timestampSeparator: Character = "T"
    static let clockSeparator: Character = ":"
    static let posixLocale = "en_US_POSIX"
    static let cacheFileName = "forecast_snapshots_v1.json"
    static let cacheVersion = 1
    static let currentFields =
        "temperature_2m,weather_code,is_day,apparent_temperature,relative_humidity_2m,wind_speed_10m"
    static let dailyFields = "weather_code,temperature_2m_min,temperature_2m_max,sunset"
    static let hourlyFields = "temperature_2m,weather_code,precipitation_probability,is_day"
    static let timezone = "auto"
    enum Query {
        static let latitude = "latitude", longitude = "longitude", timezone = "timezone"
        static let forecastDays = "forecast_days", current = "current", daily = "daily", hourly = "hourly"
    }
}

enum WeatherTiming { static let nanosecondsPerSecond: Double = 1_000_000_000 }

// WMO 数字属于外部协议常量，展示层只处理对应的天气语义。
enum WMOCode: Int {
    case clear = 0
    case mainlyClear = 1
    case partlyCloudy = 2
    case overcast = 3
    case fog = 45
    case rimeFog = 48
    case lightDrizzle = 51
    case moderateDrizzle = 53
    case denseDrizzle = 55
    case lightFreezingDrizzle = 56
    case denseFreezingDrizzle = 57
    case slightRain = 61
    case moderateRain = 63
    case heavyRain = 65
    case lightFreezingRain = 66
    case heavyFreezingRain = 67
    case slightSnow = 71
    case moderateSnow = 73
    case heavySnow = 75
    case snowGrains = 77
    case slightShowers = 80
    case moderateShowers = 81
    case violentShowers = 82
    case slightSnowShowers = 85
    case heavySnowShowers = 86
    case thunderstorm = 95
    case thunderstormSlightHail = 96
    case heavyThunderstorm = 97
    case thunderstormHeavyHail = 99
}
