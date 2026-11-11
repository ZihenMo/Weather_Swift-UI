import Combine
import Foundation

/// 管理收藏恢复与串行保存，同时复用会话内定位和地名请求。
@MainActor
final class PlacesRepository: ObservableObject {
    enum SaveResult: Equatable { case saved, sessionOnly, alreadySaved }
    enum Recovery: Equatable { case notLoaded, loading, ready, failed }
    enum Persistence: Equatable { case saved, saving, unsaved }
    private struct NameKey: Hashable {
        let point: Coordinates
        let language: String
    }
    private enum Change {
        case add(Place)
        case remove(Int)
    }
    private struct Mutation {
        let revision: Int
        let change: Change
    }
    private struct NameEntry {
        let value: String?
        let created: Date
    }

    @Published private(set) var saved: [Place] = []
    @Published private(set) var recovery: Recovery = .notLoaded
    @Published private(set) var persistence: Persistence = .saved
    private(set) var lastError: Error?
    private let store: PlaceStore
    private let acquire: () async throws -> Coordinates
    private let resolve: (Coordinates, String) async -> String?
    let find: (String, String) async throws -> [Place]
    let authorization: () -> LocationAuthorization
    private let policy: PlacesPolicy
    private let now: () -> Date
    private let diagnostics: DiagnosticSink
    private var device: Coordinates?
    private var acquiring: Task<Coordinates, Error>?
    private var names: [NameKey: NameEntry] = [:]
    private var resolving: [NameKey: Task<String?, Never>] = [:]
    private var restoring: Task<Void, Error>?
    private var lastWrite: Task<Bool, Never>?
    private var mutations: [Mutation] = []
    private var revision = 0

    init(
        store: PlaceStore, acquire: @escaping () async throws -> Coordinates,
        resolve: @escaping (Coordinates, String) async -> String?,
        find: @escaping (String, String) async throws -> [Place],
        policy: PlacesPolicy, now: @escaping () -> Date, diagnostics: DiagnosticSink,
        authorization: @escaping () -> LocationAuthorization = { .authorized }
    ) {
        self.store = store
        self.acquire = acquire
        self.resolve = resolve
        self.find = find
        self.policy = policy
        self.now = now
        self.diagnostics = diagnostics
        self.authorization = authorization
    }

    func restore() async throws {
        if let restoring { return try await restoring.value }
        guard recovery != .ready, recovery != .loading else { return }
        recovery = .loading
        let task = Task { [self] in
            defer { restoring = nil }
            do {
                var seen = Set<Int>()
                let loaded = try await store.read().filter { seen.insert($0.id).inserted }
                // 等待读取期间新增的会话操作也必须参与合并。
                saved = apply(mutations, to: loaded)
                recovery = .ready
                lastError = nil
                if !mutations.isEmpty { _ = await persist() } else { persistence = .saved }
            } catch {
                recovery = .failed
                lastError = error
                diagnostics.record(.placesRead, error)
                throw error
            }
        }
        restoring = task
        try await task.value
    }

    func add(_ place: Place) async -> SaveResult {
        if recovery == .notLoaded {
            do { try await restore() } catch {
                // 恢复失败后仍允许会话内增删，persist 会阻止覆盖原文件。
            }
        }
        guard !saved.contains(where: { $0.id == place.id }) else { return .alreadySaved }
        saved.append(place)
        record(.add(place))
        return await persist() ? .saved : .sessionOnly
    }

    func remove(_ id: Int) async -> Bool {
        saved.removeAll { $0.id == id }
        record(.remove(id))
        return await persist()
    }

    func retryPersistence() async {
        if recovery == .ready {
            _ = await persist()
        } else {
            do { try await restore() } catch {
                // 恢复状态和原始错误已保留，提示继续由仓库驱动。
            }
        }
    }

    /// 仅在页面完成二次确认后调用；备份失败不得替换原收藏。
    func rebuild() async {
        guard recovery == .failed else { return }
        recovery = .loading
        let snapshot = saved
        let ticket = revision
        _ = await lastWrite?.value
        do {
            try await store.backupAndReplace(snapshot)
            mutations.removeAll { $0.revision <= ticket }
            recovery = .ready
            lastError = nil
            persistence = mutations.isEmpty ? .saved : .unsaved
            if !mutations.isEmpty { _ = await persist() }
        } catch {
            recovery = .failed
            persistence = .unsaved
            lastError = error
            diagnostics.record(.placesRebuild, error)
        }
    }

    private func record(_ change: Change) {
        revision += 1
        mutations.append(Mutation(revision: revision, change: change))
        persistence = .unsaved
    }

    private func apply(_ pending: [Mutation], to initial: [Place]) -> [Place] {
        var result = initial
        for mutation in pending {
            switch mutation.change {
            case .add(let place):
                if !result.contains(where: { $0.id == place.id }) { result.append(place) }
            case .remove(let id): result.removeAll { $0.id == id }
            }
        }
        return result
    }

    private func persist() async -> Bool {
        guard recovery == .ready else {
            persistence = .unsaved
            return false
        }
        let snapshot = saved
        let ticket = revision
        // 按快照生成顺序串行写入；成功仅清除该版本及更早的待保存操作。
        let previous = lastWrite
        persistence = .saving
        let write = Task { [self, store] in
            _ = await previous?.value
            do {
                try await store.write(snapshot)
                mutations.removeAll { $0.revision <= ticket }
                if revision == ticket {
                    persistence = .saved
                    lastError = nil
                }
                return true
            } catch {
                if revision == ticket {
                    persistence = .unsaved
                    lastError = error
                }
                diagnostics.record(.placesWrite, error)
                return false
            }
        }
        lastWrite = write
        return await write.value
    }

    func currentPoint(refresh: Bool) async throws -> Coordinates {
        let permission = authorization()
        if permission != .authorized { device = nil }
        guard permission != .denied else { throw LocationProblem.denied }
        if let acquiring {
            let point = try await acquiring.value
            try requireLocationPermission()
            return point
        }
        if !refresh, let device { return device }
        let task = Task { () throws -> Coordinates in
            defer { acquiring = nil }
            let point = try await acquire()
            // 授权可能在取位期间被修改，迟到坐标不能重新填入会话缓存。
            try requireLocationPermission()
            device = point
            return point
        }
        acquiring = task
        return try await task.value
    }

    private func requireLocationPermission() throws {
        let permission = authorization()
        guard permission == .authorized else {
            device = nil
            throw permission == .denied ? LocationProblem.denied : LocationProblem.unavailable
        }
    }

    func cachedName(at point: Coordinates, language: String) -> String? {
        names[NameKey(point: point, language: language)]?.value
    }

    func name(at point: Coordinates, language: String) async -> String? {
        let key = NameKey(point: point, language: language)
        if let entry = names[key],
            entry.value != nil || now().timeIntervalSince(entry.created) < policy.failedNameRetryInterval
        {
            return entry.value
        }
        if let pending = resolving[key] { return await pending.value }
        let task = Task { () -> String? in
            defer { resolving[key] = nil }
            let resolved = await resolve(point, language)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = resolved.flatMap { $0.isEmpty ? nil : $0 }
            names[key] = NameEntry(value: value, created: now())
            if names.count > policy.nameCacheCapacity,
                let oldest = names.min(by: { $0.value.created < $1.value.created })?.key
            {
                names[oldest] = nil
            }
            return value
        }
        resolving[key] = task
        return await task.value
    }
}
