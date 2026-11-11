import XCTest

@testable import WeatherJournal

/// Protects place-local hourly data and the ownership of asynchronous weather and district results.
@MainActor
final class ForecastFlowTests: XCTestCase {
    private let device = Coordinates(latitude: 22.3, longitude: 114.1)
    private let city = Coordinates(latitude: 31.2, longitude: 121.5)

    /// The last forecast day keeps its own hours and missing metrics retain their original indexes.
    func testSeventhDayEveningUsesPlaceLocalTimesAndKeepsMetricGaps() async throws {
        let response = try sample(temperature: 19)
        let forecast = try await TestDependencies.weather({ _ in response }).load(at: device).forecast
        XCTAssertEqual(forecast.days.count, 7)
        let date = try XCTUnwrap(forecast.days.last?.date)
        XCTAssertEqual(forecast.initialPeriod(for: "2026-11-04"), .evening)
        XCTAssertEqual(forecast.initialPeriod(for: date), .night)
        let hours = forecast.hours(on: date, in: .evening)
        XCTAssertEqual(hours.map(\.time.clock), ["18:00", "19:00", "23:00"])
        XCTAssertEqual(hours.map(\.temperature), [19, nil, 16])
        XCTAssertEqual(hours.map(\.precipitationProbability), [70, nil, nil])
    }

    /// A late forecast from the previous city cannot displace the new snapshot, even if its next refresh fails.
    func testLateForecastAndFailedRefreshPreserveSelectedCityWeather() async throws {
        let old = try sample(temperature: 10)
        let new = try sample(temperature: 25)
        let started = expectation(description: "First coordinate requested")
        let gate = Deferred<ForecastResponse>(started: started)
        var failRefresh = false
        let repo = TestDependencies.weather { [device] point in
            if point == device { return await gate.wait() }
            if failRefresh { throw URLError(.timedOut) }
            return new
        }
        let model = TestDependencies.model(
            target: .device, weather: repo, locate: { [device] _ in device },
            cachedName: { _, _ in nil }, lookup: { _, _ in nil })
        let first = model.load(.device, language: "en")
        await fulfillment(of: [started], timeout: 2)
        let selection = WeatherTarget.place(name: "Shanghai", region: "CN", point: city)
        await model.load(selection, language: "en").value
        gate.release(old)
        await first.value
        XCTAssertEqual(model.forecast?.temperature, 25)
        XCTAssertEqual(model.phase, .ready)

        failRefresh = true
        await model.load(selection, language: "en", refresh: true).value
        XCTAssertEqual(model.forecast?.temperature, 25)
        XCTAssertEqual(model.phase, .failed(.forecast))
    }

    /// A district received while viewing a saved place is reused only for the matching coordinate and language.
    func testDistrictFinishesOffscreenAndIsReusedWhenReturningToDevice() async throws {
        let response = try sample(temperature: 20)
        let started = expectation(description: "Device lookup in progress")
        let gate = Deferred<String?>(started: started)
        var lookups: [String] = []
        let places = TestDependencies.places(
            store: MemoryPlaceStore(),
            acquire: { [device] in device },
            resolve: { _, language in
                lookups.append(language)
                return language == "en" ? await gate.wait() : "九龍城"
            }, find: { _, _ in [] })
        let model = TestDependencies.model(
            target: .device, weather: TestDependencies.weather { _ in response },
            locate: places.currentPoint, cachedName: places.cachedName, lookup: places.name)
        let initialLoad = model.load(.device, language: "en")
        await fulfillment(of: [started], timeout: 2)
        await model.load(.place(name: "Shanghai", region: "CN", point: city), language: "en").value
        gate.release("Kowloon City")
        await initialLoad.value
        let district = await places.name(at: device, language: "en")
        XCTAssertEqual(district, "Kowloon City")
        XCTAssertEqual(model.name, "Shanghai")

        await model.load(.device, language: "en").value
        XCTAssertEqual(model.name, "Kowloon City")
        let otherLanguage = await places.name(at: device, language: "zh-Hant")
        XCTAssertEqual(otherLanguage, "九龍城")
        XCTAssertEqual(lookups, ["en", "zh-Hant"])
    }

    private func sample(temperature: Int) throws -> ForecastResponse {
        let json = """
            {
              "current": {"time":"2026-11-04T23:45","temperature_2m":\(temperature)},
              "daily": {"time":["2026-11-04","2026-11-05","2026-11-06","2026-11-07","2026-11-08","2026-11-09","2026-11-10"]},
              "hourly": {
                "time":["2026-11-09T23:00","2026-11-10T17:00","2026-11-10T18:00","2026-11-10T19:00","2026-11-10T23:00"],
                "temperature_2m":[11,23,19,null,16],
                "precipitation_probability":[0,50,70]
              }
            }
            """
        return try JSONDecoder().decode(ForecastResponse.self, from: Data(json.utf8))
    }
}

@MainActor
private final class Deferred<Value> {
    private let started: XCTestExpectation
    private var waiting: CheckedContinuation<Value, Never>?

    init(started: XCTestExpectation) { self.started = started }

    func wait() async -> Value {
        await withCheckedContinuation {
            waiting = $0
            started.fulfill()
        }
    }

    func release(_ value: Value) {
        waiting?.resume(returning: value)
        waiting = nil
    }
}
