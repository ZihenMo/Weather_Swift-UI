import XCTest

@testable import WeatherJournal

/// Protects injected endpoints, server error information and weather semantics at the external-data boundary.
@MainActor
final class ContractTests: XCTestCase {
    /// A literal plus sign must survive URL encoding, and an injected host must be used unchanged.
    func testClientUsesInjectedEndpointAndEncodesQuery() async throws {
        struct Reply: Decodable { let value: Int }
        let endpoint = try XCTUnwrap(URL(string: "https://fixture.example.test/search"))
        var captured: URLRequest?
        let client = OpenMeteoClient(
            transport: HTTPTransport { request in
                captured = request
                let response = try XCTUnwrap(
                    HTTPURLResponse(url: endpoint, statusCode: 200, httpVersion: nil, headerFields: nil))
                return (Data("{\"value\":1}".utf8), response)
            }, diagnostics: .silent)
        let _: Reply = try await client.get(endpoint, query: [URLQueryItem(name: "name", value: "A+B")])
        let url = try XCTUnwrap(captured?.url)
        XCTAssertEqual(url.host, "fixture.example.test")
        XCTAssertEqual(url.path, "/search")
        XCTAssertTrue(url.absoluteString.contains("A%2BB"))
    }

    /// Rate-limit status and service reasons remain available after the request fails.
    func testHTTPFailurePreservesStatusAndReason() async throws {
        struct Reply: Decodable { let value: Int }
        let endpoint = try XCTUnwrap(URL(string: "https://fixture.example.test/forecast"))
        let client = OpenMeteoClient(
            transport: HTTPTransport { _ in
                let response = try XCTUnwrap(
                    HTTPURLResponse(url: endpoint, statusCode: 429, httpVersion: nil, headerFields: nil))
                return (Data("{\"reason\":\"quota\"}".utf8), response)
            }, diagnostics: .silent)
        do {
            let _: Reply = try await client.get(endpoint, query: [])
            XCTFail("HTTP failure must not decode as a successful reply")
        } catch NetworkFailure.http(let status, let reason) {
            XCTAssertEqual(status, 429)
            XCTAssertEqual(reason, "quota")
        }
    }

    /// Missing day/night data must not manufacture daylight, and WMO 97 must retain thunderstorm semantics.
    func testMissingDaylightAndSevereThunderstormMapping() throws {
        let forecast = try WeatherRepository.map(TestDependencies.response())
        XCTAssertEqual(forecast.daylight, .unknown)
        XCTAssertEqual(forecast.hours.first?.daylight, .unknown)
        XCTAssertEqual(WeatherCondition(code: 97), .thunderstorm)
    }

    /// Impossible calendar dates must not reach the UI as stable row identities.
    func testInvalidCalendarDateRejectsForecast() throws {
        let json = """
            {"current":{"temperature_2m":20},"daily":{"time":["2026-02-30"]},"hourly":{"time":[]}}
            """
        let response = try JSONDecoder().decode(ForecastResponse.self, from: Data(json.utf8))
        XCTAssertThrowsError(try WeatherRepository.map(response))
    }
}
