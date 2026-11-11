import SwiftUI

private enum HomeRoute {
    case places
    case day(String, Forecast, DailyForecast)
}

/// 应用导航与恢复入口；收藏读取失败由仓库提示，不阻断天气页面。
struct JournalRoot: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var home: WeatherViewModel
    @State private var initialized = false
    @State private var route: HomeRoute?
    @State private var showsSettings = false
    @State private var offeredSettings = false

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
        .onChange(of: home.phase) { _ in checkLocationAccess() }
        .onChange(of: scenePhase) { if $0 == .active { checkLocationAccess() } }
        .alert(WeatherText.enableLocation.value, isPresented: $showsSettings) {
            Button(WeatherText.notNow.value, role: .cancel) {}
            Button(WeatherText.openSettings.value, action: openSettings)
        } message: {
            Text(WeatherText.settingsExplanation.value)
        }
    }

    @ViewBuilder private var homeContent: some View {
        if initialized {
            WeatherView(
                model: home, attributionURL: dependencies.attributionURL,
                openPlaces: { route = .places }, openDay: { route = .day($0, $1, $2) },
                requestLocationSettings: { showsSettings = true }
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
        }
        .accessibilityLabel(Text(PlacesText.title.value))
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
        checkLocationAccess()
        await places
    }

    private func checkLocationAccess() {
        guard initialized else { return }
        home.checkAuthorization(language: JournalLocalization.language(for: locale))
        let authorization = dependencies.places.authorization()
        if authorization != .denied { offeredSettings = false }
        // 同一拒绝状态只自动提示一次；手动“前往设置”仍可再次打开引导。
        if home.target == .device, authorization == .denied, !offeredSettings {
            offeredSettings = true
            showsSettings = true
        }
    }

    private func openSettings() {
        if let url = AppConstants.settingsURL { openURL(url) }
    }

    private func restorePlaces() async {
        do { try await dependencies.places.restore() } catch {
            // 仓库保留恢复失败状态，首页和列表共同观察同一提示。
        }
    }
}

private struct PlacesFlow: View {
    @Environment(\.locale) private var locale
    @ObservedObject var home: WeatherViewModel
    @State private var searching = false

    let dependencies: AppDependencies
    let select: (Place?) -> Void

    var body: some View {
        ZStack {
            PlacesView(
                repository: dependencies.places, search: { searching = true }, select: select,
                selectedPlaceID: selectedPlaceID, isDeviceSelected: home.target == .device,
                deviceName: deviceName, deviceStatus: deviceStatus
            )
            .accessibilityHidden(searching)
            .allowsHitTesting(!searching)
            if searching {
                SearchFlow(dependencies: dependencies, close: { searching = false })
            }
        }
        .navigationBarHidden(true)
    }

    private var selectedPlaceID: Int? {
        dependencies.places.saved.first { $0.weatherTarget == home.target }?.id
    }

    private var deviceName: String? {
        guard dependencies.places.authorization() == .authorized, let point = home.lastDevicePoint else { return nil }
        return dependencies.places.cachedName(at: point, language: JournalLocalization.language(for: locale))
    }

    private var deviceStatus: String? {
        switch dependencies.places.authorization() {
        case .denied: return WeatherText.permissionDenied.string
        case .notDetermined: return WeatherText.permissionPending.string
        case .authorized: break
        }
        guard home.target == .device else { return nil }
        switch home.phase {
        case .failed(.unavailable): return WeatherText.locationFailureTitle.string
        default: return nil
        }
    }
}

private struct SearchFlow: View {
    @State private var candidate: Place?
    @State private var adding = false
    @State private var isVisible = true

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
            .allowsHitTesting(candidate == nil)
            if let place = candidate {
                JournalPanel(close: closeCandidate) {
                    CandidateScreen(
                        dependencies: dependencies, place: place, close: closeCandidate,
                        added: { _ in finishAdding(place) },
                        savingChanged: { adding = $0 }
                    )
                    .id(place.id)
                }
            }
        }
        .onDisappear { isVisible = false }
    }

    private func closeCandidate() { if !adding { candidate = nil } }

    private func finishAdding(_ place: Place) {
        if isVisible, candidate?.id == place.id { close() }
    }
}

private struct CandidateScreen: View {
    @StateObject private var weather: WeatherViewModel

    let dependencies: AppDependencies
    let place: Place
    let close: () -> Void
    let added: (PlacesRepository.SaveResult) -> Void
    let savingChanged: (Bool) -> Void
    init(
        dependencies: AppDependencies, place: Place, close: @escaping () -> Void,
        added: @escaping (PlacesRepository.SaveResult) -> Void, savingChanged: @escaping (Bool) -> Void
    ) {
        self.dependencies = dependencies
        self.place = place
        self.close = close
        self.added = added
        self.savingChanged = savingChanged
        _weather = StateObject(wrappedValue: dependencies.weatherModel(for: place.weatherTarget))
    }

    var body: some View {
        PlacePreviewView(
            repository: dependencies.places, place: place, close: close, added: added,
            savingChanged: savingChanged
        ) {
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
