import XCTest

@testable import WeatherJournal

/// Protects session mutations, recoverable storage and the age boundaries of offline forecasts.
@MainActor
final class RecoveryAndCacheTests: XCTestCase {
    private let point = Coordinates(latitude: 22.3, longitude: 114.1)
    private let old = Place(id: 1, name: "Old", region: "", point: Coordinates(latitude: 22, longitude: 114))
    private let new = Place(id: 2, name: "New", region: "", point: Coordinates(latitude: 23, longitude: 115))

    /// Failed restoration must not overwrite the original; retry replays both additions and deletions.
    func testRecoveryMergesSessionChangesWithoutOverwritingUnreadableStorage() async throws {
        let store = MemoryPlaceStore([old])
        await store.setFailures(read: true)
        let places = TestDependencies.places(store: store)
        do {
            try await places.restore()
            XCTFail("Corrupt storage must fail restoration")
        } catch {}
        let added = await places.add(new)
        _ = await places.remove(old.id)
        XCTAssertEqual(added, .sessionOnly)
        XCTAssertEqual(places.saved, [new])
        let writesBeforeRecovery = await store.writeCount
        XCTAssertEqual(writesBeforeRecovery, 0)
        XCTAssertEqual(places.recovery, .failed)

        await store.setFailures()
        await places.retryPersistence()
        let persisted = try await store.read()
        XCTAssertEqual(persisted, [new])
        XCTAssertEqual(places.persistence, .saved)
        XCTAssertEqual(places.recovery, .ready)
    }

    /// Disk space recovery can persist an already-added place without deleting and adding it again.
    func testRetryPersistsUnsavedListAfterWriteFailure() async throws {
        let store = MemoryPlaceStore()
        let places = TestDependencies.places(store: store)
        try await places.restore()
        await store.setFailures(write: true)
        let result = await places.add(new)
        XCTAssertEqual(result, .sessionOnly)
        XCTAssertEqual(places.persistence, .unsaved)
        await store.setFailures()
        await places.retryPersistence()
        XCTAssertEqual(places.persistence, .saved)
        let restored = try await store.read()
        XCTAssertEqual(restored, [new])
    }

    /// Rebuilding a corrupt file must preserve its exact bytes before replacing the primary file.
    func testRebuildBacksUpCorruptFileBeforeWritingVersionedRecords() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(PlacesContract.fileName)
        let corrupt = Data("incomplete JSON".utf8)
        try corrupt.write(to: file)
        let store = SavedPlacesStore(file: file, files: TestDependencies.files, backupID: { "recovery" })
        let places = TestDependencies.places(store: store)
        _ = await places.add(new)
        await places.rebuild()
        let backup = file.appendingPathExtension(PlacesContract.backupExtension).appendingPathExtension("recovery")
        XCTAssertEqual(try Data(contentsOf: backup), corrupt)
        let restored = try await store.read()
        XCTAssertEqual(restored, [new])
        XCTAssertEqual(places.recovery, .ready)
    }

    /// Cache reads after a new repository instance must keep the original timestamp and reject the 24-hour boundary.
    func testCacheSurvivesRepositoryRecreationAndExpiresAtDisplayLimit() async throws {
        let store = MemoryForecastStore()
        var clock = TestDependencies.now
        let response = try TestDependencies.response()
        let writer = WeatherRepository(
            fetch: { _ in response }, cache: store, policy: .standard, now: { clock }, diagnostics: .silent)
        _ = try await writer.load(at: point)
        let reader = WeatherRepository(
            fetch: { _ in throw URLError(.notConnectedToInternet) }, cache: store,
            policy: .standard, now: { clock }, diagnostics: .silent)
        let cached = await reader.cached(at: point)
        XCTAssertEqual(cached?.forecast.temperature, 20)
        XCTAssertEqual(cached?.fetchedAt, TestDependencies.now)
        clock = clock.addingTimeInterval(WeatherPolicy.standard.displayInterval)
        let expired = await reader.cached(at: point)
        XCTAssertNil(expired)
    }

    /// 定位被拒绝时不得继续展示历史定位天气，即使恢复的快照仍在有效期内。
    func testDeniedLocationClearsPreviousLocationSnapshot() async throws {
        let snapshot = ForecastSnapshot(
            point: point, forecast: try WeatherRepository.map(TestDependencies.response()),
            fetchedAt: TestDependencies.now)
        let weather = WeatherRepository(
            fetch: { _ in throw URLError(.notConnectedToInternet) }, cache: MemoryForecastStore([snapshot]),
            policy: .standard, now: { TestDependencies.now }, diagnostics: .silent)
        let model = TestDependencies.model(
            target: .device, weather: weather,
            locate: { _ in throw LocationProblem.denied }, cachedName: { _, _ in nil }, lookup: { _, _ in nil })
        model.restoreDevicePoint(point)
        await model.load(.device, language: "en", forceNetwork: true).value
        XCTAssertEqual(model.phase, .failed(.denied))
        XCTAssertNil(model.snapshot)
        XCTAssertNil(model.forecast)
    }

    /// Fresh snapshots avoid automatic requests, while an explicit refresh always reaches the transport.
    func testManualRefreshBypassesFreshCache() async throws {
        let snapshot = ForecastSnapshot(
            point: point, forecast: try WeatherRepository.map(TestDependencies.response()),
            fetchedAt: TestDependencies.now)
        var requests = 0
        let weather = WeatherRepository(
            fetch: { _ in
                requests += 1
                throw URLError(.notConnectedToInternet)
            },
            cache: MemoryForecastStore([snapshot]), policy: .standard, now: { TestDependencies.now },
            diagnostics: .silent)
        let target = WeatherTarget.place(name: "City", region: "", point: point)
        let model = TestDependencies.model(
            target: target, weather: weather, locate: { _ in throw LocationProblem.unavailable },
            cachedName: { _, _ in nil }, lookup: { _, _ in nil })
        await model.load(target, language: "en").value
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(model.phase, .ready)
        await model.load(target, language: "en", refresh: true).value
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(model.phase, .failed(.forecast))
        XCTAssertEqual(model.forecast?.temperature, 20)
    }

    /// Reading the pre-envelope format preserves user data; the next save writes an explicit version.
    func testLegacySavedPlacesRemainReadableAfterSchemaUpgrade() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(PlacesContract.fileName)
        let legacy = """
            [{"id":2,"name":"New","region":"","point":{"latitude":23,"longitude":115}}]
            """
        try Data(legacy.utf8).write(to: file)
        let store = TestDependencies.placeStore(directory)
        let restored = try await store.read()
        XCTAssertEqual(restored, [new])
        try await store.write(restored)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 2)
    }

}
