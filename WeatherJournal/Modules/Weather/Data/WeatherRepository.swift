import Foundation

enum ForecastDataError: Error { case invalidDates, noUsableData }

/// 将接口数据映射为可用预报，并维护按坐标索引、带期限的快照缓存。
actor WeatherRepository {
    private let fetch: (Coordinates) async throws -> ForecastResponse
    private let cache: ForecastStore
    private let policy: WeatherPolicy
    private let now: () -> Date
    private let diagnostics: DiagnosticSink
    private var snapshots: [Coordinates: ForecastSnapshot] = [:]
    private var restored = false
    private var restoring: Task<[ForecastSnapshot], Error>?
    private var lastCacheWrite: Task<Void, Never>?

    init(
        fetch: @escaping (Coordinates) async throws -> ForecastResponse, cache: ForecastStore,
        policy: WeatherPolicy, now: @escaping () -> Date, diagnostics: DiagnosticSink
    ) {
        self.fetch = fetch
        self.cache = cache
        self.policy = policy
        self.now = now
        self.diagnostics = diagnostics
    }

    func cached(at point: Coordinates) async -> ForecastSnapshot? {
        await restoreCache()
        guard let value = snapshots[point], value.isUsable(at: now(), policy: policy) else { return nil }
        return value
    }

    func load(at point: Coordinates) async throws -> ForecastSnapshot {
        await restoreCache()
        try Task.checkCancellation()
        let response = try await fetch(point)
        try Task.checkCancellation()
        let forecast: Forecast
        do { forecast = try Self.map(response) } catch {
            diagnostics.record(.forecastDecode, error)
            throw error
        }
        let snapshot = ForecastSnapshot(point: point, forecast: forecast, fetchedAt: now())
        snapshots[point] = snapshot
        let retained = retain(Array(snapshots.values))
        snapshots = Dictionary(uniqueKeysWithValues: retained.map { ($0.point, $0) })
        let previous = lastCacheWrite
        let write = Task { [cache, diagnostics] in
            await previous?.value
            do { try await cache.write(retained) } catch { diagnostics.record(.forecastCacheWrite, error) }
        }
        lastCacheWrite = write
        await write.value
        return snapshot
    }

    private func restoreCache() async {
        guard !restored else { return }
        let task: Task<[ForecastSnapshot], Error>
        if let restoring {
            task = restoring
        } else {
            task = Task { [cache] in try await cache.read() }
            restoring = task
        }
        do {
            let values = try await task.value
            guard !restored else { return }
            for value in retain(values) where snapshots[value.point] == nil { snapshots[value.point] = value }
        } catch {
            guard !restored else { return }
            diagnostics.record(.forecastCacheRead, error)
        }
        restored = true
        restoring = nil
    }

    private func retain(_ values: [ForecastSnapshot]) -> [ForecastSnapshot] {
        var seen = Set<Coordinates>()
        return Array(
            values.filter { $0.point.isValid && $0.isUsable(at: now(), policy: policy) }
                .sorted { $0.fetchedAt > $1.fetchedAt }
                .filter { seen.insert($0.point).inserted }
                .prefix(max(0, policy.cacheCapacity)))
    }

    static func map(_ response: ForecastResponse) throws -> Forecast {
        let daily = response.daily
        guard !daily.time.isEmpty, Set(daily.time).count == daily.time.count,
            daily.time.allSatisfy({ ForecastDate.parse($0) != nil }), daily.time == daily.time.sorted()
        else { throw ForecastDataError.invalidDates }
        func value<T>(_ array: [T?]?, at index: Int) -> T? {
            guard let array, array.indices.contains(index) else { return nil }
            return array[index]
        }
        let days = daily.time.enumerated().map { index, date in
            DailyForecast(
                date: date, low: value(daily.low, at: index), high: value(daily.high, at: index),
                code: value(daily.code, at: index), sunset: LocalForecastTime(value(daily.sunset, at: index)))
        }
        let hourly = response.hourly
        var seenHours = Set<String>()
        let hours = hourly.time.enumerated().compactMap { index, raw -> HourlyForecast? in
            guard let time = LocalForecastTime(raw), seenHours.insert(raw).inserted else { return nil }
            return HourlyForecast(
                time: time, temperature: value(hourly.temperature, at: index),
                precipitationProbability: value(hourly.precipitationProbability, at: index),
                code: value(hourly.code, at: index),
                daylight: Daylight(apiValue: value(hourly.isDay, at: index)))
        }
        let current = response.current
        guard
            current.temperature != nil || current.code != nil
                || days.contains(where: { $0.low != nil || $0.high != nil || $0.code != nil })
                || hours.contains(where: { $0.temperature != nil || $0.code != nil })
        else { throw ForecastDataError.noUsableData }
        return Forecast(
            time: LocalForecastTime(current.time), temperature: current.temperature,
            feelsLike: current.feelsLike, humidity: current.humidity, wind: current.wind,
            code: current.code, daylight: Daylight(apiValue: current.isDay), days: days, hours: hours)
    }
}
