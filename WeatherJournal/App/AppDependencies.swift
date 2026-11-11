import Foundation

/// 可替换的应用装配结果，跨模块能力通过构造参数传递。
@MainActor
struct AppDependencies {
    let places: PlacesRepository
    let weather: WeatherRepository
    let session: SessionRepository
    let attributionURL: URL
    let weatherPolicy: WeatherPolicy
    let placesPolicy: PlacesPolicy
    let now: () -> Date
    let sleep: (UInt64) async throws -> Void

    func weatherModel(for target: WeatherTarget) -> WeatherViewModel {
        WeatherViewModel(
            target: target, weather: weather, locate: places.currentPoint,
            cachedName: places.cachedName, lookup: places.name, policy: weatherPolicy, now: now, sleep: sleep)
    }
}

extension Place {
    var weatherTarget: WeatherTarget { .place(name: name, region: region, point: point) }
}
