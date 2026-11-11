import Combine
import XCTest

@testable import WeatherJournal

/// 验证定位授权变化对自动请求、手动授权、已显示天气与地区选择的影响。
@MainActor
final class LocationAuthorizationTests: XCTestCase {
    private let point = Coordinates(latitude: 22.3, longitude: 114.1)
    private let movedPoint = Coordinates(latitude: 23.1, longitude: 113.3)

    /// 即使天气尚未过期，撤销定位权限也应立即清空，并阻止自动定位与网络请求。
    func testRevocationClearsFreshDeviceWeatherWithoutMakingRequests() async throws {
        let access = LocationAccessStub(point: point)
        let response = try TestDependencies.response()
        let requests = AuthorizationForecastStub(response: response)
        let snapshot = ForecastSnapshot(
            point: point, forecast: try WeatherRepository.map(response),
            fetchedAt: TestDependencies.now)
        let weather = WeatherRepository(
            fetch: requests.fetch, cache: MemoryForecastStore([snapshot]),
            policy: .standard, now: { TestDependencies.now }, diagnostics: .silent)
        let model = makeModel(weather: weather, access: access)
        await model.load(.device, language: "en").value
        XCTAssertEqual(model.phase, .ready)
        XCTAssertNotNil(model.snapshot)

        access.status = .denied
        model.checkAuthorization(language: "en")
        XCTAssertNil(model.snapshot)
        XCTAssertEqual(model.phase, .failed(.denied))
        model.activate(language: "en")
        await model.load(.device, language: "en").value
        XCTAssertEqual(access.refreshRequests.count, 1)
        let count = await requests.count
        XCTAssertEqual(count, 0)
        XCTAssertNil(model.snapshot)
    }

    /// 未决定权限时自动进入页面不能弹系统授权框，只有手动刷新才请求定位。
    func testUndeterminedPermissionWaitsUntilManualRefresh() async throws {
        let access = LocationAccessStub(point: point, status: .notDetermined)
        access.grantsPermissionOnAcquire = true
        let requests = AuthorizationForecastStub(response: try TestDependencies.response())
        let model = makeModel(weather: TestDependencies.weather(requests.fetch), access: access)
        model.startAutomaticUpdates(language: "en")
        defer { model.stopAutomaticUpdates() }
        model.activate(language: "en")
        await model.load(.device, language: "en").value
        XCTAssertEqual(model.phase, .awaitingPermission)
        XCTAssertTrue(access.refreshRequests.isEmpty)
        let automaticCount = await requests.count
        XCTAssertEqual(automaticCount, 0)

        let ready = expectation(description: "手动授权后天气就绪")
        let observer = model.$phase.filter { $0 == .ready }.prefix(1).sink { _ in ready.fulfill() }
        defer { observer.cancel() }
        model.refresh()
        await fulfillment(of: [ready], timeout: 2)
        XCTAssertEqual(access.refreshRequests, [true])
        XCTAssertEqual(access.status, .authorized)
        XCTAssertEqual(model.forecast?.temperature, 20)
        let manualCount = await requests.count
        XCTAssertEqual(manualCount, 1)
    }

    /// 从设置恢复授权后必须重新取位并联网，不能继续使用仍新鲜的旧坐标天气。
    func testRestoredPermissionForcesLocationAndWeatherRefresh() async throws {
        let access = LocationAccessStub(point: point)
        let requests = AuthorizationForecastStub(response: try TestDependencies.response())
        let model = makeModel(weather: TestDependencies.weather(requests.fetch), access: access)
        await model.load(.device, language: "en").value
        access.status = .denied
        model.checkAuthorization(language: "en")
        access.point = movedPoint
        access.status = .authorized
        model.checkAuthorization(language: "en")
        XCTAssertEqual(access.refreshRequests.count, 1)
        let beforeActivation = await requests.count
        XCTAssertEqual(beforeActivation, 1)

        let ready = expectation(description: "恢复授权后取得新坐标天气")
        let observer = model.$phase.filter { $0 == .ready }.prefix(1).sink { _ in ready.fulfill() }
        defer {
            observer.cancel()
            model.stopAutomaticUpdates()
        }
        model.startAutomaticUpdates(language: "en")
        await fulfillment(of: [ready], timeout: 2)
        XCTAssertEqual(access.refreshRequests.count, 2)
        XCTAssertEqual(access.refreshRequests.last, true)
        XCTAssertEqual(model.snapshot?.point, movedPoint)
        let afterActivation = await requests.count
        XCTAssertEqual(afterActivation, 2)
    }

    /// 已取消的外部请求可能仍返回，撤权后其结果不能重新填回天气页面。
    func testLateForecastDoesNotRestoreWeatherAfterRevocation() async throws {
        let access = LocationAccessStub(point: point)
        let started = expectation(description: "天气请求已发出")
        let gate = AuthorizationResponseGate(started: started)
        let model = makeModel(weather: TestDependencies.weather { _ in await gate.wait() }, access: access)
        let load = model.load(.device, language: "en")
        await fulfillment(of: [started], timeout: 2)
        access.status = .denied
        model.checkAuthorization(language: "en")
        await gate.release(try TestDependencies.response())
        await load.value
        XCTAssertNil(model.forecast)
        XCTAssertNil(model.snapshot)
        XCTAssertEqual(model.phase, .failed(.denied))
    }

    /// 手选地区不依赖定位授权，权限拒绝或未知均不应清空其天气或触发系统定位。
    func testManualRegionRemainsAvailableWithoutLocationPermission() async throws {
        let access = LocationAccessStub(point: point, status: .denied)
        let target = WeatherTarget.place(name: "Region", region: "", point: movedPoint)
        let requests = AuthorizationForecastStub(response: try TestDependencies.response())
        let model = makeModel(target: target, weather: TestDependencies.weather(requests.fetch), access: access)
        await model.load(target, language: "en").value
        model.checkAuthorization(language: "en")
        access.status = .notDetermined
        model.checkAuthorization(language: "en")
        model.activate(language: "en")
        XCTAssertEqual(model.target, target)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.snapshot?.point, movedPoint)
        XCTAssertTrue(access.refreshRequests.isEmpty)
        let count = await requests.count
        XCTAssertEqual(count, 1)
    }

    /// 仓库在返回会话内旧坐标前也必须检查权限，恢复授权后不得复用已撤销的坐标。
    func testPlacesRepositoryRejectsCachedCoordinateAfterRevocation() async throws {
        let access = LocationAccessStub(point: point)
        let places = PlacesRepository(
            store: MemoryPlaceStore(), acquire: { try await access.acquire(refresh: false) },
            resolve: { _, _ in nil }, find: { _, _ in [] }, policy: .standard,
            now: { TestDependencies.now }, diagnostics: .silent,
            authorization: { access.status })
        let initial = try await places.currentPoint(refresh: false)
        XCTAssertEqual(initial, point)
        access.status = .denied
        do {
            _ = try await places.currentPoint(refresh: false)
            XCTFail("撤权后不得返回缓存坐标")
        } catch {
            XCTAssertEqual(error as? LocationProblem, .denied)
        }
        XCTAssertEqual(access.refreshRequests.count, 1)
        access.status = .authorized
        access.point = movedPoint
        let restored = try await places.currentPoint(refresh: false)
        XCTAssertEqual(restored, movedPoint)
        XCTAssertEqual(access.refreshRequests.count, 2)
    }

    private func makeModel(target: WeatherTarget = .device, weather: WeatherRepository, access: LocationAccessStub)
        -> WeatherViewModel
    {
        WeatherViewModel(
            target: target, weather: weather, locate: access.acquire,
            cachedName: { _, _ in nil }, lookup: { _, _ in nil }, policy: .standard,
            now: { TestDependencies.now }, sleep: { _ in throw CancellationError() },
            authorization: { access.status })
    }
}

@MainActor
private final class LocationAccessStub {
    var point: Coordinates
    var status: LocationAuthorization
    var grantsPermissionOnAcquire = false
    private(set) var refreshRequests: [Bool] = []

    init(point: Coordinates, status: LocationAuthorization = .authorized) {
        self.point = point
        self.status = status
    }

    func acquire(refresh: Bool) async throws -> Coordinates {
        refreshRequests.append(refresh)
        if grantsPermissionOnAcquire { status = .authorized }
        if status != .authorized { throw LocationProblem.denied }
        return point
    }
}

private actor AuthorizationForecastStub {
    let response: ForecastResponse
    private(set) var count = 0

    init(response: ForecastResponse) { self.response = response }
    func fetch(_ point: Coordinates) async throws -> ForecastResponse {
        count += 1
        return response
    }
}

private actor AuthorizationResponseGate {
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<ForecastResponse, Never>?

    init(started: XCTestExpectation) { self.started = started }
    func wait() async -> ForecastResponse {
        await withCheckedContinuation {
            continuation = $0
            started.fulfill()
        }
    }
    func release(_ response: ForecastResponse) {
        continuation?.resume(returning: response)
        continuation = nil
    }
}
