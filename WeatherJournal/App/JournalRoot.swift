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
            homeContent
                .navigationTitle(WeatherText.title.value)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { placesButton } }
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

    private var placesButton: some View {
        Button {
            route = .places
        } label: {
            Image(systemName: JournalSymbol.places).accessibilityLabel(Text(PlacesText.title.value))
        }
        .disabled(!initialized)
        .accessibilityIdentifier(PlacesIdentifier.list)
    }

    @ViewBuilder private func destination(_ route: HomeRoute) -> some View {
        switch route {
        case .places:
            PlacesFlow(dependencies: dependencies, select: select)
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
    @State private var searching = false

    let dependencies: AppDependencies
    let select: (Place?) -> Void

    var body: some View {
        PlacesView(repository: dependencies.places, search: { searching = true }, select: select)
            .background {
                NavigationLink(isActive: $searching) {
                    SearchFlow(dependencies: dependencies) { _ in
                        searching = false
                    }
                } label: {
                    EmptyView()
                }
                .isDetailLink(false)
            }
    }
}

private struct SearchFlow: View {
    @State private var candidate: Place?

    let dependencies: AppDependencies
    let added: (PlacesRepository.SaveResult) -> Void

    var body: some View {
        PlaceSearchView(
            find: dependencies.places.find, delay: dependencies.placesPolicy.searchDelayNanoseconds,
            sleep: dependencies.sleep, preview: { candidate = $0 }
        )
        .background {
            DestinationLink(item: $candidate) { place in
                CandidateScreen(dependencies: dependencies, place: place, close: { candidate = nil }, added: added)
                    .id(place.id)
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
            WeatherView(model: weather, attributionURL: dependencies.attributionURL)
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
