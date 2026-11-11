import Foundation

@testable import WeatherJournal

actor MemoryForecastStore: ForecastStore {
    private var values: [ForecastSnapshot]
    init(_ values: [ForecastSnapshot] = []) { self.values = values }
    func read() -> [ForecastSnapshot] { values }
    func write(_ snapshots: [ForecastSnapshot]) { values = snapshots }
}

actor MemoryPlaceStore: PlaceStore {
    private var values: [Place]
    var readFails = false
    var writeFails = false
    private(set) var writeCount = 0
    private(set) var backupCount = 0
    init(_ values: [Place] = []) { self.values = values }
    func setFailures(read: Bool = false, write: Bool = false) {
        readFails = read
        writeFails = write
    }
    func read() throws -> [Place] {
        if readFails { throw CocoaError(.fileReadCorruptFile) }
        return values
    }
    func write(_ places: [Place]) throws {
        writeCount += 1
        if writeFails { throw CocoaError(.fileWriteOutOfSpace) }
        values = places
    }
    func backupAndReplace(_ places: [Place]) throws {
        backupCount += 1
        try write(places)
    }
}

@MainActor
enum TestDependencies {
    static let now = Date(timeIntervalSince1970: 1_794_355_200)
    static let policy = WeatherPolicy.standard
    static let files = FileAccess(
        read: { try Data(contentsOf: $0) },
        write: { data, url in
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        },
        copy: { try FileManager.default.copyItem(at: $0, to: $1) })

    static func placeStore(_ directory: URL) -> SavedPlacesStore {
        SavedPlacesStore(
            file: directory.appendingPathComponent(PlacesContract.fileName), files: files,
            backupID: { UUID().uuidString })
    }

    static func weather(_ fetch: @escaping (Coordinates) async throws -> ForecastResponse) -> WeatherRepository {
        WeatherRepository(
            fetch: fetch, cache: MemoryForecastStore(), policy: policy, now: { now }, diagnostics: .silent)
    }

    static func places(
        store: PlaceStore, acquire: @escaping () async throws -> Coordinates = { throw LocationProblem.unavailable },
        resolve: @escaping (Coordinates, String) async -> String? = { _, _ in nil },
        find: @escaping (String, String) async throws -> [Place] = { _, _ in [] }
    ) -> PlacesRepository {
        PlacesRepository(
            store: store, acquire: acquire, resolve: resolve, find: find,
            policy: .standard, now: { now }, diagnostics: .silent)
    }

    static func model(
        target: WeatherTarget, weather: WeatherRepository, locate: @escaping (Bool) async throws -> Coordinates,
        cachedName: @escaping @MainActor (Coordinates, String) -> String?,
        lookup: @escaping (Coordinates, String) async -> String?
    ) -> WeatherViewModel {
        WeatherViewModel(
            target: target, weather: weather, locate: locate, cachedName: cachedName, lookup: lookup,
            policy: policy, now: { now }, sleep: { _ in throw CancellationError() })
    }

    static func response(temperature: Int = 20) throws -> ForecastResponse {
        let json = """
            {"current":{"time":"2026-11-11T12:00","temperature_2m":\(temperature)},
             "daily":{"time":["2026-11-11"]},
             "hourly":{"time":["2026-11-11T12:00"],"temperature_2m":[20]}}
            """
        return try JSONDecoder().decode(ForecastResponse.self, from: Data(json.utf8))
    }
}
