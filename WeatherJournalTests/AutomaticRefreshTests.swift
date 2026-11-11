import XCTest

@testable import WeatherJournal

/// 使用可推进时钟验证自动刷新期限、后台停止和网络失败后的重试节奏。
@MainActor
final class AutomaticRefreshTests: XCTestCase {
    private let point = Coordinates(latitude: 22.3, longitude: 114.1)
    private let interval: TimeInterval = 15 * 60

    /// 新鲜天气满十五分钟只刷新一次，停止后即使到期也不能再次请求网络。
    func testRefreshesAtDeadlineAndStopsWhileHidden() async throws {
        let clock = RefreshTestClock(TestDependencies.now)
        let sleeper = RefreshTestSleeper(clock: clock, interval: interval)
        let requests = RefreshForecastStub(response: try TestDependencies.response())
        let model = makeModel(clock: clock, sleeper: sleeper, requests: requests)
        defer {
            model.stopAutomaticUpdates()
            Task { await sleeper.cancelAll() }
        }
        await model.load(model.target, language: "en").value
        let scheduled = expectation(description: "首次自动刷新已排期")
        await sleeper.observeNextInterval(scheduled)
        model.startAutomaticUpdates(language: "en")
        await fulfillment(of: [scheduled], timeout: 2)
        let initialCount = await requests.count
        XCTAssertEqual(initialCount, 1)

        let refreshed = expectation(description: "到期后只请求一次天气")
        let rescheduled = expectation(description: "刷新完成后排定下次更新")
        await requests.observeNextRequest(refreshed)
        await sleeper.observeNextInterval(rescheduled)
        clock.advance(by: interval)
        await sleeper.wakeDue()
        await fulfillment(of: [refreshed, rescheduled], timeout: 2)
        let refreshedCount = await requests.count
        XCTAssertEqual(refreshedCount, 2)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.snapshot?.fetchedAt, clock.now)

        let unexpected = expectation(description: "隐藏页面不得自动请求")
        unexpected.isInverted = true
        await requests.observeNextRequest(unexpected)
        model.stopAutomaticUpdates()
        clock.advance(by: interval)
        await sleeper.wakeDue()
        await fulfillment(of: [unexpected], timeout: 0.1)
        let stoppedCount = await requests.count
        XCTAssertEqual(stoppedCount, 2)
    }

    /// 请求失败后也必须等待完整刷新间隔，避免旧快照过期导致立即重复请求。
    func testFailedRefreshWaitsForNextIntervalInsteadOfRetryingImmediately() async throws {
        let clock = RefreshTestClock(TestDependencies.now)
        let sleeper = RefreshTestSleeper(clock: clock, interval: interval)
        let requests = RefreshForecastStub(response: try TestDependencies.response())
        let model = makeModel(clock: clock, sleeper: sleeper, requests: requests)
        defer {
            model.stopAutomaticUpdates()
            Task { await sleeper.cancelAll() }
        }
        await model.load(model.target, language: "en").value
        let scheduled = expectation(description: "自动更新已排期")
        await sleeper.observeNextInterval(scheduled)
        model.startAutomaticUpdates(language: "en")
        await fulfillment(of: [scheduled], timeout: 2)
        await requests.setFailure(true)

        let failed = expectation(description: "到期请求失败")
        let retryScheduled = expectation(description: "失败后排定下一次尝试")
        await requests.observeNextRequest(failed)
        await sleeper.observeNextInterval(retryScheduled)
        clock.advance(by: interval)
        await sleeper.wakeDue()
        await fulfillment(of: [failed, retryScheduled], timeout: 2)
        XCTAssertEqual(model.phase, .failed(.forecast))
        XCTAssertEqual(model.forecast?.temperature, 20)

        let earlyRetry = expectation(description: "间隔尚未结束时不得再次请求")
        earlyRetry.isInverted = true
        await requests.observeNextRequest(earlyRetry)
        clock.advance(by: interval - 1)
        await sleeper.wakeDue()
        await fulfillment(of: [earlyRetry], timeout: 0.1)
        let beforeDeadline = await requests.count
        XCTAssertEqual(beforeDeadline, 2)

        let retry = expectation(description: "下一次期限到达后重试")
        let nextInterval = expectation(description: "连续失败仍保持定时节奏")
        await requests.observeNextRequest(retry)
        await sleeper.observeNextInterval(nextInterval)
        clock.advance(by: 1)
        await sleeper.wakeDue()
        await fulfillment(of: [retry, nextInterval], timeout: 2)
        let afterDeadline = await requests.count
        XCTAssertEqual(afterDeadline, 3)
        XCTAssertEqual(model.phase, .failed(.forecast))
    }

    private func makeModel(clock: RefreshTestClock, sleeper: RefreshTestSleeper, requests: RefreshForecastStub)
        -> WeatherViewModel
    {
        let weather = WeatherRepository(
            fetch: requests.fetch, cache: MemoryForecastStore(), policy: .standard,
            now: { clock.now }, diagnostics: .silent)
        return WeatherViewModel(
            target: .place(name: "Region", region: "", point: point), weather: weather,
            locate: { _ in throw LocationProblem.unavailable }, cachedName: { _, _ in nil },
            lookup: { _, _ in nil }, policy: .standard, now: { clock.now }, sleep: sleeper.sleep)
    }
}

/// 同一时钟供主线程模型和天气仓库读取，不依赖真实时间流逝。
private final class RefreshTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(_ date: Date) { self.date = date }
    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return date
    }
    func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        date = date.addingTimeInterval(interval)
    }
}

/// 同时接管十五分钟刷新和二十四小时失效等待，取消会释放所有对应 continuation。
private actor RefreshTestSleeper {
    private struct Wait {
        let deadline: Date
        let continuation: CheckedContinuation<Void, Error>
    }
    private let clock: RefreshTestClock
    private let intervalNanoseconds: UInt64
    private var waits: [UUID: Wait] = [:]
    private var intervalObserver: XCTestExpectation?

    init(clock: RefreshTestClock, interval: TimeInterval) {
        self.clock = clock
        intervalNanoseconds = UInt64(interval * 1_000_000_000)
    }
    func observeNextInterval(_ observer: XCTestExpectation) { intervalObserver = observer }

    func sleep(_ nanoseconds: UInt64) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                waits[id] = Wait(
                    deadline: clock.now.addingTimeInterval(Double(nanoseconds) / 1_000_000_000),
                    continuation: continuation)
                if nanoseconds <= intervalNanoseconds {
                    intervalObserver?.fulfill()
                    intervalObserver = nil
                }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    func wakeDue() {
        let due = waits.filter { $0.value.deadline <= clock.now }.map(\.key)
        for id in due { waits.removeValue(forKey: id)?.continuation.resume() }
    }
    func cancelAll() {
        let pending = waits.values
        waits = [:]
        for wait in pending { wait.continuation.resume(throwing: CancellationError()) }
    }
    private func cancel(_ id: UUID) {
        waits.removeValue(forKey: id)?.continuation.resume(throwing: CancellationError())
    }
}

private actor RefreshForecastStub {
    private let response: ForecastResponse
    private var fails = false
    private var nextRequest: XCTestExpectation?
    private(set) var count = 0

    init(response: ForecastResponse) { self.response = response }
    func setFailure(_ fails: Bool) { self.fails = fails }
    func observeNextRequest(_ observer: XCTestExpectation) { nextRequest = observer }
    func fetch(_ point: Coordinates) async throws -> ForecastResponse {
        count += 1
        nextRequest?.fulfill()
        nextRequest = nil
        if fails { throw URLError(.notConnectedToInternet) }
        return response
    }
}
