import Combine
import Foundation

enum WeatherTarget: Codable, Equatable {
    case device
    case place(name: String, region: String, point: Coordinates)
}

/// 管理单个页面的请求、权限和刷新期限，旧请求不能覆盖当前地区或重新填入已撤权的数据。
@MainActor
final class WeatherViewModel: ObservableObject {
    enum Failure: Equatable { case denied, unavailable, forecast }
    enum Phase: Equatable {
        case idle, awaitingPermission, locating, loading, ready
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
    private let authorization: () -> LocationAuthorization
    private var language: String?
    private var revision = 0
    private var request: Task<Void, Never>?
    private var expiry: Task<Void, Never>?
    private var automaticUpdates: Task<Void, Never>?
    private var lastAuthorization: LocationAuthorization?
    private var needsFreshLocation = true
    private var requestingAuthorization = false
    private var lastAttemptAt: Date?

    init(
        target: WeatherTarget, weather: WeatherRepository, locate: @escaping (Bool) async throws -> Coordinates,
        cachedName: @escaping @MainActor (Coordinates, String) -> String?,
        lookup: @escaping (Coordinates, String) async -> String?,
        policy: WeatherPolicy, now: @escaping () -> Date, sleep: @escaping (UInt64) async throws -> Void,
        authorization: @escaping () -> LocationAuthorization = { .authorized }
    ) {
        self.target = target
        self.weather = weather
        self.locate = locate
        self.cachedName = cachedName
        self.lookup = lookup
        self.policy = policy
        self.now = now
        self.sleep = sleep
        self.authorization = authorization
    }

    func restoreDevicePoint(_ point: Coordinates?) { lastDevicePoint = point }

    /// 前台检查不触发定位或天气请求，隐藏页面也可及时丢弃撤权前的结果。
    func checkAuthorization(language: String) {
        let permission = authorization()
        if lastAuthorization != .authorized, permission == .authorized { needsFreshLocation = true }
        lastAuthorization = permission
        guard target == .device else { return }
        switch permission {
        case .authorized: break
        case .notDetermined:
            // 系统授权面板切换前后台时保留用户刚发起的请求，避免截断授权回调。
            if requestingAuthorization, phase == .locating { return }
            self.language = language
            blockLocation(.awaitingPermission)
        case .denied:
            self.language = language
            blockLocation(.failed(.denied))
        }
    }

    func activate(language: String) {
        checkAuthorization(language: language)
        guard target != .device || authorization() == .authorized else { return }
        discardExpiredSnapshot()
        if self.language == language, request != nil { return }
        let relocate = target == .device && needsFreshLocation
        if self.language == nil {
            load(target, language: language, forceNetwork: true)
        } else if self.language != language || relocate || snapshot?.isFresh(at: now(), policy: policy) != true {
            load(target, language: language, forceNetwork: relocate)
        }
    }

    func startAutomaticUpdates(language: String) {
        activate(language: language)
        guard automaticUpdates == nil else { return }
        automaticUpdates = Task { [weak self, sleep] in
            while !Task.isCancelled {
                guard let delay = self?.automaticDelay() else { return }
                do { try await sleep(delay) } catch { return }
                guard !Task.isCancelled else { return }
                await self?.performAutomaticUpdate()
            }
        }
    }

    func stopAutomaticUpdates() {
        automaticUpdates?.cancel()
        automaticUpdates = nil
    }

    func refresh() {
        if let language { load(target, language: language, refresh: true) }
    }

    @discardableResult
    func load(_ selection: WeatherTarget, language: String, refresh: Bool = false, forceNetwork: Bool = false) -> Task<
        Void, Never
    > {
        request?.cancel()
        revision += 1
        let ticket = revision
        if selection != target {
            clearSnapshot()
            name = nil
            lastAttemptAt = nil
            needsFreshLocation = true
        }
        if self.language != language { name = nil }
        self.language = language
        target = selection
        requestingAuthorization = selection == .device && refresh && authorization() == .notDetermined
        if requestingAuthorization { phase = .locating }
        checkAuthorization(language: language)
        if selection == .device, authorization() != .authorized, !requestingAuthorization {
            return Task {}
        }
        discardExpiredSnapshot()
        let refreshLocation = refresh || needsFreshLocation
        if selection == .device, refreshLocation { clearSnapshot() }
        phase = selection == .device ? .locating : .loading
        let task = Task<Void, Never> { [weak self] in
            await self?.performLoad(
                selection, language: language, ticket: ticket, refreshLocation: refreshLocation,
                forceNetwork: refresh || forceNetwork)
        }
        request = task
        return task
    }

    private func performLoad(
        _ selection: WeatherTarget, language: String, ticket: Int, refreshLocation: Bool, forceNetwork: Bool
    ) async {
        guard !Task.isCancelled, revision == ticket else { return }
        defer {
            if revision == ticket {
                request = nil
                requestingAuthorization = false
            }
        }
        do {
            let point: Coordinates
            switch selection {
            case .device:
                point = try await locate(refreshLocation)
                if revision == ticket { requestingAuthorization = false }
                guard canAccept(ticket, language: language) else { return }
                lastAuthorization = .authorized
                lastDevicePoint = point
                needsFreshLocation = false
                useDevicePoint(point, language: language, ticket: ticket)
            case .place(let placeName, _, let coordinate):
                point = coordinate
                name = placeName
            }
            guard canAccept(ticket, language: language) else { return }
            let cached = await weather.cached(at: point)
            guard canAccept(ticket, language: language) else { return }
            if let cached {
                accept(cached, source: .cache)
                if !forceNetwork, cached.isFresh(at: now(), policy: policy) {
                    phase = .ready
                    return
                }
            }
            lastAttemptAt = now()
            let value = try await weather.load(at: point)
            guard canAccept(ticket, language: language) else { return }
            accept(value, source: .live)
            phase = .ready
        } catch {
            if revision == ticket { requestingAuthorization = false }
            guard canAccept(ticket, language: language) else { return }
            lastAttemptAt = now()
            discardExpiredSnapshot()
            if phase == .locating {
                clearSnapshot()
                name = nil
                needsFreshLocation = true
                phase = .failed((error as? LocationProblem) == .denied ? .denied : .unavailable)
            } else {
                phase = .failed(.forecast)
                if snapshot != nil { source = .cache }
            }
        }
    }

    private func canAccept(_ ticket: Int, language: String) -> Bool {
        guard !Task.isCancelled, revision == ticket else { return false }
        if target == .device, authorization() != .authorized {
            checkAuthorization(language: language)
            return false
        }
        return true
    }

    private func blockLocation(_ blocked: Phase) {
        request?.cancel()
        request = nil
        revision += 1
        requestingAuthorization = false
        needsFreshLocation = true
        clearSnapshot()
        source = .live
        name = nil
        phase = blocked
    }

    private func automaticDelay() -> UInt64 {
        let date = now()
        let next: Date
        if target == .device, authorization() != .authorized {
            next = date.addingTimeInterval(policy.freshInterval)
        } else {
            let fetched = snapshot?.fetchedAt.addingTimeInterval(policy.freshInterval)
            let attempted = lastAttemptAt?.addingTimeInterval(policy.freshInterval)
            next = [fetched, attempted].compactMap { $0 }.max() ?? date.addingTimeInterval(policy.freshInterval)
        }
        return UInt64(max(0, next.timeIntervalSince(date)) * WeatherTiming.nanosecondsPerSecond)
    }

    private func performAutomaticUpdate() async {
        guard let language, !Task.isCancelled else { return }
        checkAuthorization(language: language)
        guard target != .device || authorization() == .authorized else { return }
        if let request {
            await request.value
            return
        }
        guard snapshot?.isFresh(at: now(), policy: policy) != true else { return }
        if target == .device { needsFreshLocation = true }
        await load(target, language: language, forceNetwork: true).value
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
        // 地名解析归地区仓库所有，页面只校验回填归属，不取消共享解析。
        Task { [weak self, lookup] in
            let value = await lookup(point, language)
            guard let self, self.canAccept(ticket, language: language) else { return }
            self.name = value
        }
    }

    deinit {
        request?.cancel()
        expiry?.cancel()
        automaticUpdates?.cancel()
    }
}
