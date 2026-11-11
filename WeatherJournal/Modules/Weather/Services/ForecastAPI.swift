import Foundation

/// 只负责天气接口参数与响应契约，地址和传输能力由外部注入。
struct ForecastAPI {
    let client: OpenMeteoClient
    let endpoint: URL

    func fetch(_ point: Coordinates) async throws -> ForecastResponse {
        try await client.get(
            endpoint,
            query: [
                URLQueryItem(name: WeatherContract.Query.latitude, value: String(point.latitude)),
                URLQueryItem(name: WeatherContract.Query.longitude, value: String(point.longitude)),
                URLQueryItem(name: WeatherContract.Query.timezone, value: WeatherContract.timezone),
                URLQueryItem(name: WeatherContract.Query.forecastDays, value: String(WeatherContract.forecastDays)),
                URLQueryItem(
                    name: WeatherContract.Query.current,
                    value: WeatherContract.currentFields
                ),
                URLQueryItem(name: WeatherContract.Query.daily, value: WeatherContract.dailyFields),
                URLQueryItem(name: WeatherContract.Query.hourly, value: WeatherContract.hourlyFields),
            ])
    }
}

struct ForecastResponse: Decodable {
    struct Current: Decodable {
        let time: String?
        let temperature, feelsLike, humidity, wind: Double?
        let code, isDay: Int?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case feelsLike = "apparent_temperature"
            case humidity = "relative_humidity_2m"
            case wind = "wind_speed_10m"
            case code = "weather_code"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let low, high: [Double?]?
        let code: [Int?]?
        let sunset: [String?]?

        enum CodingKeys: String, CodingKey {
            case time, sunset
            case low = "temperature_2m_min"
            case high = "temperature_2m_max"
            case code = "weather_code"
        }
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature, precipitationProbability: [Double?]?
        let code, isDay: [Int?]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case precipitationProbability = "precipitation_probability"
            case code = "weather_code"
            case isDay = "is_day"
        }
    }

    let current: Current
    let daily: Daily
    let hourly: Hourly
}
