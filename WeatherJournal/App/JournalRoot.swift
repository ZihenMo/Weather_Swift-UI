import SwiftUI

private enum HomeRoute {
    case places
    case day(String, Forecast, DailyForecast)
}

/// 应用导航与恢复入口；收藏读取失败由仓库提示，不阻断天气页面。
struct JournalRoot: View {
    @Environment(\.locale) private var locale
    @StateObject private var home: WeatherViewModel
    @State private var initialized = false
    @State private var route: HomeRoute?

    let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _home = StateObject(wrappedValue: dependencies.weatherModel(for: .device))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header
                homeContent
            }
            .background(JournalStyle.Color.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .background { DestinationLink(item: $route, destination: destination) }
        }
        .navigationViewStyle(.stack)
        .task { await initialize() }
        .onChange(of: home.lastDevicePoint) { dependencies.session.remember($0) }
    }

    @ViewBuilder private var homeContent: some View {
        if initialized {
            WeatherView(
                model: home, attributionURL: dependencies.attributionURL,
                openPlaces: { route = .places }, openDay: { route = .day($0, $1, $2) }
            )
            .safeAreaInset(edge: .bottom) { PlacesPersistenceNotice(repository: dependencies.places) }
        } else {
            ProgressView(WeatherText.loading.value)
        }
    }

    private var header: some View {
        HStack {
            Text(WeatherText.title.value)
                .journalFont(size: JournalStyle.Size.pageTitle, weight: .bold, relativeTo: .largeTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            placesButton
        }
        .foregroundColor(JournalStyle.Color.ink)
        .frame(minHeight: JournalStyle.Size.navigationHeight)
        .padding(.horizontal, JournalStyle.Space.page)
    }

    private var placesButton: some View {
        Button {
            route = .places
        } label: {
            JournalIcon(name: JournalAsset.places, size: JournalStyle.Size.navigationIcon)
                .frame(width: JournalStyle.Size.navigationButton, height: JournalStyle.Size.navigationButton)
                .background(JournalStyle.Color.surface, in: Circle())
                .accessibilityLabel(Text(PlacesText.title.value))
        }
        .disabled(!initialized)
        .accessibilityIdentifier(PlacesIdentifier.list)
    }

    @ViewBuilder private func destination(_ route: HomeRoute) -> some View {
        switch route {
        case .places:
            PlacesFlow(home: home, dependencies: dependencies, select: select)
        case .day(let name, let forecast, let day):
            DayDetailView(name: name, forecast: forecast, day: day)
        }
    }

    private func select(_ place: Place?) {
        let target = place?.weatherTarget ?? .device
        dependencies.session.select(target)
        home.load(target, language: JournalLocalization.language(for: locale))
        route = nil
    }

    private func initialize() async {
        guard !initialized else { return }
        // 两类本地状态独立恢复，天气可先于收藏完成展示。
        async let places: Void = restorePlaces()
        await dependencies.session.restore()
        home.restoreDevicePoint(dependencies.session.devicePoint)
        home.load(dependencies.session.target, language: JournalLocalization.language(for: locale), forceNetwork: true)
        initialized = true
        await places
    }

    private func restorePlaces() async {
        do { try await dependencies.places.restore() } catch {
            // 仓库保留恢复失败状态，首页和列表共同观察同一提示。
        }
    }
}

private struct PlacesFlow: View {
    @ObservedObject var home: WeatherViewModel
    @State private var searching = false

    let dependencies: AppDependencies
    let select: (Place?) -> Void

    var body: some View {
        ZStack {
            PlacesView(
                repository: dependencies.places, search: { searching = true }, select: select,
                selectedPlaceID: selectedPlaceID, isDeviceSelected: home.target == .device,
                deviceName: home.target == .device ? home.name : nil, deviceStatus: deviceStatus
            )
            .accessibilityHidden(searching)
            if searching {
                SearchFlow(dependencies: dependencies, close: { searching = false })
            }
        }
        .navigationBarHidden(true)
    }

    private var selectedPlaceID: Int? {
        dependencies.places.saved.first { $0.weatherTarget == home.target }?.id
    }

    private var deviceStatus: String? {
        switch home.phase {
        case .failed(.denied): return WeatherText.permissionDenied.string
        case .failed(.unavailable): return WeatherText.locationUnavailable.string
        default: return nil
        }
    }
}

private struct SearchFlow: View {
    @State private var candidate: Place?

    let dependencies: AppDependencies
    let close: () -> Void

    var body: some View {
        ZStack {
            JournalPanel(close: close) {
                PlaceSearchView(
                    find: dependencies.places.find, delay: dependencies.placesPolicy.searchDelayNanoseconds,
                    sleep: dependencies.sleep, preview: { candidate = $0 }, close: close)
            }
            .accessibilityHidden(candidate != nil)
            if let place = candidate {
                JournalPanel(close: { candidate = nil }) {
                    CandidateScreen(
                        dependencies: dependencies, place: place, close: { candidate = nil }, added: { _ in close() }
                    )
                    .id(place.id)
                }
            }
        }
    }
}

private struct CandidateScreen: View {
    @StateObject private var weather: WeatherViewModel

    let dependencies: AppDependencies
    let place: Place
    let close: () -> Void
    let added: (PlacesRepository.SaveResult) -> Void
    init(
        dependencies: AppDependencies, place: Place, close: @escaping () -> Void,
        added: @escaping (PlacesRepository.SaveResult) -> Void
    ) {
        self.dependencies = dependencies
        self.place = place
        self.close = close
        self.added = added
        _weather = StateObject(wrappedValue: dependencies.weatherModel(for: place.weatherTarget))
    }

    var body: some View {
        PlacePreviewView(repository: dependencies.places, place: place, close: close, added: added) {
            WeatherView(model: weather, isPreview: true, attributionURL: dependencies.attributionURL)
        }
    }
}

// iOS 15 使用绑定驱动页面呈现；子页面压栈时保留父页面的状态身份。
private struct DestinationLink<Item, Destination: View>: View {
    @Binding var item: Item?
    @ViewBuilder let destination: (Item) -> Destination

    var body: some View {
        NavigationLink(isActive: Binding(get: { item != nil }, set: { active in if !active { item = nil } })) {
            if let item { destination(item) }
        } label: {
            EmptyView()
        }
        .isDetailLink(false)
    }
}

#if DEBUG
    @MainActor
    private struct JournalRoot_Previews: PreviewProvider {
        static var previews: some View {
            JournalRoot(dependencies: AppPreviewData.dependencies())
                .journalPreview()
                .previewDisplayName("天气 · 完整导航")
        }
    }
#endif
