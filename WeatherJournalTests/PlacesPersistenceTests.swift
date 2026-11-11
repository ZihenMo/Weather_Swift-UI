import XCTest

@testable import WeatherJournal

/// Protects source-ID uniqueness, disk restoration and session-only changes after a write failure.
@MainActor
final class PlacesPersistenceTests: XCTestCase {
    private let city = Place(id: 42, name: "九龍城", region: "香港", point: Coordinates(latitude: 22.33, longitude: 114.19))

    /// A new store instance recovers the original ID and coordinates and observes a subsequent deletion.
    func testAddDeduplicateRestoreAndDeleteAcrossStoreInstances() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = repository(directory)
        try await first.restore()
        let saved = await first.add(city)
        let alias = Place(id: city.id, name: "Kowloon City", region: "HK", point: city.point)
        let repeated = await first.add(alias)
        XCTAssertEqual(saved, .saved)
        XCTAssertEqual(repeated, .alreadySaved)

        let next = repository(directory)
        try await next.restore()
        XCTAssertEqual(next.saved, [city])
        let removed = await next.remove(city.id)
        XCTAssertTrue(removed)
        let recovered = try await TestDependencies.placeStore(directory).read()
        XCTAssertTrue(recovered.isEmpty)
    }

    /// A non-directory storage path makes persistence fail without undoing the visible add or remove.
    func testWriteFailureKeepsChangesForTheSession() async throws {
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        let places = repository(blocker)
        let result = await places.add(city)
        XCTAssertEqual(result, .sessionOnly)
        XCTAssertEqual(places.saved, [city])
        let persisted = await places.remove(city.id)
        XCTAssertFalse(persisted)
        XCTAssertTrue(places.saved.isEmpty)
    }

    private func repository(_ directory: URL) -> PlacesRepository {
        TestDependencies.places(
            store: TestDependencies.placeStore(directory), acquire: { throw LocationProblem.unavailable },
            resolve: { _, _ in nil }, find: { _, _ in [] })
    }
}
