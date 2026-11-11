#if DEBUG
    import SwiftUI

    /// 天气预览使用固定日期和内存快照，与设备时间、网络及用户缓存隔离。
    @MainActor
    enum WeatherPreviewData {
        enum Scenario: Equatable { case ready, offline, failure }

        static let point = Coordinates(latitude: 22.33, longitude: 114.19)
        static let name = "九龍城"
        static let region = "香港"
        static let now = Date(timeIntervalSince1970: 1_794_355_200)
        static let attributionURL = URL(fileURLWithPath: "/preview/weather")
        static let dates = [
            "2026-11-11", "2026-11-12", "2026-11-13", "2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17",
        ]
        static let hourTimes = ["06:00", "07:00", "08:00", "09:00", "10:00", "11:00"]
        static let language = JournalLocalization.fallbackLanguage

        static var response: ForecastResponse {
            ForecastResponse(
                current: .init(
                    time: dates[0] + "T08:00", temperature: 24, feelsLike: 26, humidity: 75, wind: 12, code: 2, isDay: 1
                ),
                daily: .init(
                    time: dates, low: [20, 21, 22, 21, 20, 19, 20], high: [26, 27, 28, 26, 25, 24, 25],
                    code: [2, 3, 61, 97, 2, 0, 1], sunset: dates.map { Optional($0 + "T17:40") }),
                hourly: .init(
                    time: hourTimes.map { dates[0] + "T" + $0 }, temperature: [22, 23, nil, 25, 24, 23],
                    precipitationProbability: [10, 20, nil, 60, 40, 20], code: [1, 2, nil, 61, 3, 2],
                    isDay: [1, 1, nil, 1, 1, 1]))
        }

        static var forecast: Forecast {
            do { return try WeatherRepository.map(response) } catch { preconditionFailure("天气预览样本不满足预报数据契约") }
        }

        static var day: DailyForecast { forecast.days[0] }
        static var hours: [HourlyForecast] { forecast.hours(on: dates[0], in: .morning) }
        static var target: WeatherTarget { .place(name: name, region: region, point: point) }

        static func repository(_ scenario: Scenario = .ready) -> WeatherRepository {
            let snapshots =
                scenario == .failure ? [] : [ForecastSnapshot(point: point, forecast: forecast, fetchedAt: now)]
            return WeatherRepository(
                fetch: { [response] _ in
                    guard scenario == .ready else { throw URLError(.notConnectedToInternet) }
                    return response
                },
                cache: PreviewForecastStore(snapshots: snapshots), policy: .standard, now: { [now] in now },
                diagnostics: .silent
            )
        }

        static func model(_ scenario: Scenario) -> WeatherViewModel {
            WeatherViewModel(
                target: target, weather: repository(scenario), locate: { [point] _ in point },
                cachedName: { [name] _, _ in name }, lookup: { [name] _, _ in name }, policy: .standard,
                now: { [now] in now },
                sleep: { _ in throw CancellationError() })
        }
    }

    private actor PreviewForecastStore: ForecastStore {
        private var snapshots: [ForecastSnapshot]

        init(snapshots: [ForecastSnapshot]) { self.snapshots = snapshots }
        func read() -> [ForecastSnapshot] { snapshots }
        func write(_ snapshots: [ForecastSnapshot]) { self.snapshots = snapshots }
    }

    /// 预览容器拥有模型，避免画布重绘时重新创建页面状态。
    @MainActor
    struct WeatherPreviewScene: View {
        @StateObject private var model: WeatherViewModel

        init(_ scenario: WeatherPreviewData.Scenario) {
            _model = StateObject(wrappedValue: WeatherPreviewData.model(scenario))
        }

        var body: some View {
            NavigationView {
                WeatherView(
                    model: model, attributionURL: WeatherPreviewData.attributionURL, openPlaces: {},
                    openDay: { _, _, _ in })
            }
            .navigationViewStyle(.stack)
            .journalPreview()
        }
    }
#endif
