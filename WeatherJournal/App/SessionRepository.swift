import Foundation

struct SavedSelection: Codable {
    let version: Int
    let target: WeatherTarget
    let devicePoint: Coordinates?
}

protocol SelectionStore {
    func read() async throws -> SavedSelection?
    func write(_ selection: SavedSelection) async throws
}

actor FileSelectionStore: SelectionStore {
    private let file: URL
    private let files: FileAccess
    init(file: URL, files: FileAccess) {
        self.file = file
        self.files = files
    }
    func read() throws -> SavedSelection? {
        do {
            let value = try JSONDecoder().decode(SavedSelection.self, from: files.read(file))
            guard value.version == AppConstants.sessionVersion else {
                throw StorageError.unsupportedVersion(value.version)
            }
            if let point = value.devicePoint, !point.isValid { throw StorageError.invalidRecord }
            if case .place(_, _, let point) = value.target, !point.isValid { throw StorageError.invalidRecord }
            return value
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
    }
    func write(_ selection: SavedSelection) throws { try files.write(JSONEncoder().encode(selection), file) }
}

/// 最后选择独立于收藏存储，写入链保证快速切换时最终状态不被旧快照覆盖。
@MainActor
final class SessionRepository {
    private(set) var target: WeatherTarget = .device
    private(set) var devicePoint: Coordinates?
    private let store: SelectionStore
    private let diagnostics: DiagnosticSink
    private var lastWrite: Task<Void, Never>?
    init(store: SelectionStore, diagnostics: DiagnosticSink) {
        self.store = store
        self.diagnostics = diagnostics
    }

    func restore() async {
        do {
            if let saved = try await store.read() {
                target = saved.target
                devicePoint = saved.devicePoint
            }
        } catch { diagnostics.record(.sessionRead, error) }
    }
    func select(_ target: WeatherTarget) {
        self.target = target
        persist()
    }
    func remember(_ point: Coordinates?) {
        devicePoint = point
        persist()
    }
    private func persist() {
        let value = SavedSelection(version: AppConstants.sessionVersion, target: target, devicePoint: devicePoint)
        let previous = lastWrite
        lastWrite = Task { [store, diagnostics] in
            await previous?.value
            do { try await store.write(value) } catch { diagnostics.record(.sessionWrite, error) }
        }
    }
}
