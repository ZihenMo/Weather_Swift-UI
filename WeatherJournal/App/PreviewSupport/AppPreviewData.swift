#if DEBUG
    import Foundation

    /// 根页面预览统一装配两个模块的内存实现，导航操作不会落盘。
    @MainActor
    enum AppPreviewData {
        static func dependencies() -> AppDependencies {
            AppDependencies(
                places: PlacesPreviewData.repository(), weather: WeatherPreviewData.repository(),
                session: SessionRepository(store: PreviewSelectionStore(), diagnostics: .silent),
                attributionURL: WeatherPreviewData.attributionURL, weatherPolicy: .standard, placesPolicy: .standard,
                now: { [now = WeatherPreviewData.now] in now }, sleep: { try await Task.sleep(nanoseconds: $0) })
        }
    }

    private actor PreviewSelectionStore: SelectionStore {
        private var value: SavedSelection?
        func read() -> SavedSelection? { value }
        func write(_ selection: SavedSelection) { value = selection }
    }
#endif
