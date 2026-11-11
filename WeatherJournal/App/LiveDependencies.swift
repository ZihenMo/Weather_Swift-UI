import CoreLocation
import Foundation
import OSLog

/// 生产系统依赖的唯一创建入口，模块内部不自行选择全局实例。
@MainActor
extension AppDependencies {
    static func live(configuration: AppConfiguration) throws -> AppDependencies {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = configuration.requestTimeout
        sessionConfiguration.timeoutIntervalForResource = configuration.requestTimeout
        let session = URLSession(configuration: sessionConfiguration)
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? AppConstants.logSubsystem,
            category: AppConstants.diagnosticsCategory)
        let diagnostics = DiagnosticSink { event, error in
            // 仅记录事件与错误分类，不输出描述、URL、响应正文或坐标。
            var cause = error
            if let network = error as? NetworkFailure {
                switch network {
                case .http(let status, _):
                    logger.error("\(event.rawValue, privacy: .public) http=\(status, privacy: .public)")
                    return
                case .transport(let underlying), .decoding(let underlying): cause = underlying
                default: break
                }
            }
            let nsError = cause as NSError
            logger.error(
                "\(event.rawValue, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
            )
        }
        let transport = HTTPTransport { request in try await session.data(for: request) }
        let client = OpenMeteoClient(transport: transport, diagnostics: diagnostics)
        let fileManager = FileManager.default
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StorageError.missingDirectory
        }
        let files = FileAccess(
            read: { try Data(contentsOf: $0) },
            write: { data, url in
                try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            },
            copy: { try fileManager.copyItem(at: $0, to: $1) })
        let now = { Date() }
        let sleep: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
        let placesPolicy = PlacesPolicy.standard
        let weatherPolicy = WeatherPolicy.standard
        let location = LocationService(
            makeManager: { CLLocationManager() },
            geocode: { try await CLGeocoder().reverseGeocodeLocation($0, preferredLocale: $1) },
            policy: placesPolicy, now: now, sleep: sleep, diagnostics: diagnostics)
        let places = PlacesRepository(
            store: SavedPlacesStore(
                file: support.appendingPathComponent(PlacesContract.fileName), files: files,
                backupID: { UUID().uuidString }),
            acquire: location.locate, resolve: location.district,
            find: PlaceSearchAPI(client: client, endpoint: configuration.searchURL).find,
            policy: placesPolicy, now: now, diagnostics: diagnostics)
        let weather = WeatherRepository(
            fetch: ForecastAPI(client: client, endpoint: configuration.forecastURL).fetch,
            cache: FileForecastStore(file: support.appendingPathComponent(WeatherContract.cacheFileName), files: files),
            policy: weatherPolicy, now: now, diagnostics: diagnostics)
        return AppDependencies(
            places: places, weather: weather,
            session: SessionRepository(
                store: FileSelectionStore(
                    file: support.appendingPathComponent(AppConstants.sessionFileName), files: files),
                diagnostics: diagnostics),
            attributionURL: configuration.attributionURL, weatherPolicy: weatherPolicy, placesPolicy: placesPolicy,
            now: now, sleep: sleep)
    }
}
