#if DEBUG
    import SwiftUI

    /// 地点样本与恢复故障均在内存中构造，不接触真实收藏或设备定位。
    @MainActor
    enum PlacesPreviewData {
        enum Scenario: Equatable { case ready, empty, readFailure, writeFailure }

        static let city = Place(
            id: 1, name: "九龍城", region: "香港", point: Coordinates(latitude: 22.33, longitude: 114.19))
        static let anotherCity = Place(
            id: 2, name: "上海", region: "中国", point: Coordinates(latitude: 31.23, longitude: 121.47))
        static let candidate = Place(
            id: 3, name: "深圳", region: "广东 · 中国", point: Coordinates(latitude: 22.54, longitude: 114.06))
        static let saved = [city, anotherCity]
        static let now = Date(timeIntervalSince1970: 1_794_355_200)

        static func repository(_ scenario: Scenario = .ready) -> PlacesRepository {
            PlacesRepository(
                store: PreviewPlaceStore(
                    values: scenario == .empty ? [] : saved,
                    readFailure: scenario == .readFailure, writeFailure: scenario == .writeFailure),
                acquire: { [city] in city.point }, resolve: { [city] _, _ in city.name }, find: search,
                policy: .standard, now: { [now] in now }, diagnostics: .silent)
        }

        static func search(_ query: String, language: String) async throws -> [Place] {
            [city, anotherCity, candidate].filter { $0.name.localizedCaseInsensitiveContains(query) }
        }

        static func prepare(_ repository: PlacesRepository, scenario: Scenario) async {
            do { try await repository.restore() } catch {
                // 读取失败是此预览的目标状态，由页面中的仓库提示展示。
            }
            if scenario == .writeFailure { _ = await repository.add(candidate) }
        }
    }

    private actor PreviewPlaceStore: PlaceStore {
        private var values: [Place]
        private var readFailure: Bool
        private let writeFailure: Bool

        init(values: [Place], readFailure: Bool, writeFailure: Bool) {
            self.values = values
            self.readFailure = readFailure
            self.writeFailure = writeFailure
        }

        func read() throws -> [Place] {
            if readFailure { throw CocoaError(.fileReadCorruptFile) }
            return values
        }

        func write(_ places: [Place]) throws {
            if writeFailure { throw CocoaError(.fileWriteOutOfSpace) }
            values = places
        }

        func backupAndReplace(_ places: [Place]) throws {
            try write(places)
            readFailure = false
        }
    }

    /// 只负责预览状态的准备，页面仍使用正式的仓库接口。
    @MainActor
    struct PlacesPreviewScene<Content: View>: View {
        @StateObject private var repository: PlacesRepository
        @State private var prepared = false

        let scenario: PlacesPreviewData.Scenario
        @ViewBuilder let content: (PlacesRepository) -> Content

        init(
            _ scenario: PlacesPreviewData.Scenario = .ready,
            @ViewBuilder content: @escaping (PlacesRepository) -> Content
        ) {
            self.scenario = scenario
            self.content = content
            _repository = StateObject(wrappedValue: PlacesPreviewData.repository(scenario))
        }

        var body: some View {
            content(repository)
                .journalPreview()
                .task {
                    guard !prepared else { return }
                    prepared = true
                    await PlacesPreviewData.prepare(repository, scenario: scenario)
                }
        }
    }
#endif
