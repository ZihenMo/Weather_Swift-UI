import Foundation

protocol PlaceStore {
    func read() async throws -> [Place]
    func write(_ places: [Place]) async throws
    func backupAndReplace(_ places: [Place]) async throws
}

/// 使用独立存储记录兼容旧数组格式，重建时先备份再原子替换。
actor SavedPlacesStore: PlaceStore {
    private struct Record: Codable {
        let id: Int
        let name: String
        let region: String
        let point: Coordinates

        init(_ place: Place) {
            id = place.id
            name = place.name
            region = place.region
            point = place.point
        }
        func place() throws -> Place {
            guard point.isValid, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StorageError.invalidRecord
            }
            return Place(id: id, name: name, region: region, point: point)
        }
    }
    private struct Envelope: Codable {
        let version: Int
        let places: [Record]
    }
    private let file: URL
    private let files: FileAccess
    private let backupID: () -> String

    init(file: URL, files: FileAccess, backupID: @escaping () -> String) {
        self.file = file
        self.files = files
        self.backupID = backupID
    }

    func read() throws -> [Place] {
        do {
            let data = try files.read(file)
            let decoder = JSONDecoder()
            if let legacy = try? decoder.decode([Record].self, from: data) {
                return try legacy.map { try $0.place() }
            }
            let envelope = try decoder.decode(Envelope.self, from: data)
            guard envelope.version == PlacesContract.schemaVersion else {
                throw StorageError.unsupportedVersion(envelope.version)
            }
            return try envelope.places.map { try $0.place() }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile { return [] }
    }

    func write(_ places: [Place]) throws {
        let value = Envelope(version: PlacesContract.schemaVersion, places: places.map(Record.init))
        try files.write(JSONEncoder().encode(value), file)
    }

    func backupAndReplace(_ places: [Place]) throws {
        let backup = file.appendingPathExtension(PlacesContract.backupExtension).appendingPathExtension(backupID())
        do { try files.copy(file, backup) } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // 原文件已不存在时无需备份；其他复制错误必须阻止替换。
        }
        try write(places)
    }
}
