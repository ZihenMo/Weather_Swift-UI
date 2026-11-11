import Foundation

protocol ForecastStore {
    func read() async throws -> [ForecastSnapshot]
    func write(_ snapshots: [ForecastSnapshot]) async throws
}

/// 天气缓存独立版本化；损坏时由仓库降级为无缓存，不影响收藏恢复。
actor FileForecastStore: ForecastStore {
    private struct Envelope: Codable {
        let version: Int
        let snapshots: [ForecastSnapshot]
    }
    private let file: URL
    private let files: FileAccess

    init(file: URL, files: FileAccess) {
        self.file = file
        self.files = files
    }

    func read() throws -> [ForecastSnapshot] {
        do {
            let value = try JSONDecoder().decode(Envelope.self, from: files.read(file))
            guard value.version == WeatherContract.cacheVersion else {
                throw StorageError.unsupportedVersion(value.version)
            }
            return value.snapshots
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile { return [] }
    }

    func write(_ snapshots: [ForecastSnapshot]) throws {
        let value = Envelope(version: WeatherContract.cacheVersion, snapshots: snapshots)
        try files.write(JSONEncoder().encode(value), file)
    }
}
