import Combine
import Foundation

enum WeatherTarget: Codable, Equatable {
    case device
    case place(name: String, region: String, point: Coordinates)
}

/// 管理单个页面的天气请求与缓存来源，过期或旧地点结果不能覆盖当前选择。
@MainActor
final class WeatherViewModel: ObservableObject {
    enum Failure: Equatable { case denied, unavailable, forecast }
    enum Phase: Equatable {
        case idle, locating, loading, ready
        case failed(Failure)
    }
    enum Source: Equatable { case live, cache, previousLocation }

    @Published private(set) var target: WeatherTarget
    @Published private(set) var snapshot: ForecastSnapshot?
    @Published private(set) var source: Source = .live
    @Published private(set) var name: String?
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastDevicePoint: Coordinates?
    var forecast: Forecast? { snapshot?.forecast }
    private let weather: WeatherRepository
    private let locate: (Bool) async throws -> Coordinates
    private let cachedName: @MainActor (Coordinates, String) -> String?
    private let lookup: (Coordinates, String) async -> String?
    private let policy: WeatherPolicy
    private let now: () -> Date
    private let sleep: (UInt64) async throws -> Void
    private var language: String?
    private var revision = 0
    private var request: Task<Void, Never>?
    private var expiry: Task<Void, Never>?

    init(
        target: WeatherTarget, weather: WeatherRepository, locate: @escaping (Bool) async throws -> Coordinates,
        cachedName: @escaping @MainActor (Coordinates, String) -> String?,
        lookup: @escaping (Coordinates, String) async -> String?,
        policy: WeatherPolicy, now: @escaping () -> Date, sleep: @escaping (UInt64) async throws -> Void
    ) {
        self.target = target
        self.weather = weather
        self.locate = locate
        self.cachedName = cachedName
        self.lookup = lookup
        self.policy = policy
        self.now = now
        self.sleep = sleep
    }

    func restoreDevicePoint(_ point: Coordinates?) { lastDevicePoint = point }

    func activate(language: String) {
        discardExpiredSnapshot()
        if self.language == language, phase == .loading || phase == .locating { return }
        if self.language == nil {
            load(target, language: language, forceNetwork: true)
        } else if self.language != language || snapshot?.isFresh(at: now(), policy: policy) != true {
            load(target, language: language)
        }
    }

    func refresh() {
        if let language { load(target, language: language, refresh: true) }
    }

    @discardableResult
    func load(_ selection: WeatherTarget, language: String, refresh: Bool = false, forceNetwork: Bool = false) -> Task<
        Void, Never
    > {
        request?.cancel()
        discardExpiredSnapshot()
        // 版本号与取消标记共同拦截不响应取消的旧请求。
        revision += 1
        let ticket = revision
        if selection != target {
            clearSnapshot()
            name = nil
        }
        if self.language != language { name = nil }
        self.language = language
        target = selection
        phase = selection == .device ? .locating : .loading

        let task = Task { [weak self, locate, weather] in
            do {
                let point: Coordinates
                switch selection {
                case .device:
                    if let fallback = self?.lastDevicePoint,
                        let value = await weather.cached(at: fallback), self?.revision == ticket, !Task.isCancelled
                    {
                        self?.accept(value, source: .previousLocation)
                        self?.name = self?.cachedName(fallback, language)
                    }
                    point = try await locate(refresh)
                    guard !Task.isCancelled, self?.revision == ticket else { return }
                    self?.lastDevicePoint = point
                    self?.useDevicePoint(point, language: language, ticket: ticket)
                case .place(let placeName, _, let coordinate):
                    point = coordinate
                    self?.name = placeName
                }
                guard !Task.isCancelled, self?.revision == ticket else { return }
                if let value = await weather.cached(at: point), !Task.isCancelled, self?.revision == ticket {
                    self?.accept(value, source: .cache)
                    if !refresh, !forceNetwork, let self, value.isFresh(at: self.now(), policy: self.policy) {
                        self.phase = .ready
                        return
                    }
                }
                let value = try await weather.load(at: point)
                guard !Task.isCancelled, let self, self.revision == ticket else { return }
                self.accept(value, source: .live)
                self.phase = .ready
            } catch {
                guard !Task.isCancelled, let self, self.revision == ticket else { return }
                self.discardExpiredSnapshot()
                if self.phase == .locating {
                    self.phase = .failed((error as? LocationProblem) == .denied ? .denied : .unavailable)
                    if self.snapshot != nil { self.source = .previousLocation }
                } else {
                    self.phase = .failed(.forecast)
                    if self.snapshot != nil { self.source = .cache }
                }
            }
        }
        request = task
        return task
    }

    private func accept(_ snapshot: ForecastSnapshot, source: Source) {
        guard snapshot.isUsable(at: now(), policy: policy) else { return }
        self.snapshot = snapshot
        self.source = source
        expiry?.cancel()
        let remaining = max(0, policy.displayInterval - now().timeIntervalSince(snapshot.fetchedAt))
        expiry = Task { [weak self, sleep] in
            do { try await sleep(UInt64(remaining * WeatherTiming.nanosecondsPerSecond)) } catch { return }
            self?.discardExpiredSnapshot()
        }
    }

    private func discardExpiredSnapshot() {
        if let snapshot, !snapshot.isUsable(at: now(), policy: policy) {
            clearSnapshot()
            if phase == .ready { phase = .failed(.forecast) }
        }
    }

    private func clearSnapshot() {
        snapshot = nil
        expiry?.cancel()
        expiry = nil
    }

    private func useDevicePoint(_ point: Coordinates, language: String, ticket: Int) {
        if snapshot?.point != point { clearSnapshot() }
        name = cachedName(point, language)
        phase = .loading
        guard name == nil else { return }
        // 地名解析归地点仓库所有，页面只校验回填归属，不取消共享解析。
        Task { [weak self, lookup] in
            let value = await lookup(point, language)
            guard let self, self.revision == ticket else { return }
            self.name = value
        }
    }

    deinit {
        request?.cancel()
        expiry?.cancel()
    }
}
