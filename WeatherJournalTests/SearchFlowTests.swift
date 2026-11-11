import XCTest

@testable import WeatherJournal

/// Protects query ownership when a transport completes after cancellation.
@MainActor
final class SearchFlowTests: XCTestCase {
    private let oldPlace = Place(id: 1, name: "Old", region: "", point: Coordinates(latitude: 22, longitude: 114))
    private let newPlace = Place(id: 2, name: "New", region: "", point: Coordinates(latitude: 23, longitude: 115))

    /// A slow earlier query must not replace a newer completed query even if transport cancellation is ignored.
    func testLateSearchDoesNotReplaceLatestResults() async throws {
        let started = expectation(description: "Old request started")
        var pending: CheckedContinuation<[Place], Never>?
        let model = PlaceSearchModel(
            find: { [newPlace] query, _ in
                if query == "old" {
                    return await withCheckedContinuation {
                        pending = $0
                        started.fulfill()
                    }
                }
                return [newPlace]
            }, delay: 0, sleep: { _ in })
        let oldRequest = try XCTUnwrap(model.search("old", language: "en"))
        await fulfillment(of: [started], timeout: 2)
        let newRequest = try XCTUnwrap(model.search("new", language: "en"))
        await newRequest.value
        pending?.resume(returning: [oldPlace])
        await oldRequest.value
        guard case .results(let results) = model.state else { return XCTFail("Latest query must remain visible") }
        XCTAssertEqual(results, [newPlace])
    }

    /// Clearing the query invalidates an in-flight response immediately.
    func testClearQueryKeepsIdleAfterLateResponse() async throws {
        let started = expectation(description: "Request started")
        var pending: CheckedContinuation<[Place], Never>?
        let model = PlaceSearchModel(
            find: { _, _ in
                await withCheckedContinuation {
                    pending = $0
                    started.fulfill()
                }
            }, delay: 0, sleep: { _ in })
        let request = try XCTUnwrap(model.search("old", language: "en"))
        await fulfillment(of: [started], timeout: 2)
        model.search("  ", language: "en")
        pending?.resume(returning: [oldPlace])
        await request.value
        guard case .idle = model.state else { return XCTFail("Cleared query must stay idle") }
    }
}
