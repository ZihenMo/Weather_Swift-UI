import SwiftUI

/// 首页与候选概览共用的天气内容，只展示模型状态并转发用户操作。
struct WeatherView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var model: WeatherViewModel
    @State private var isVisible = false

    var isPreview = false
    let attributionURL: URL
    var openPlaces: (() -> Void)?
    var openDay: ((String, Forecast, DailyForecast) -> Void)?
    var requestLocationSettings: (() -> Void)?

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView { content }
                .onChange(of: model.target) { _ in scroll.scrollTo(WeatherIdentifier.top, anchor: .top) }
        }
        .background((isPreview ? JournalStyle.Color.panel : JournalStyle.Color.background).ignoresSafeArea())
        .onAppear(perform: appear)
        .onDisappear(perform: disappear)
        .onChange(of: language) { if isVisible, scenePhase == .active { model.startAutomaticUpdates(language: $0) } }
        .onChange(of: scenePhase, perform: sceneChanged)
    }

    // MARK: - 天气内容

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            JournalStyle.Color.transparent.frame(height: 0).id(WeatherIdentifier.top)
            if let forecast = model.forecast {
                forecastContent(forecast)
            } else {
                status
            }
        }
        .padding(.horizontal, JournalStyle.Space.page)
        .padding(.bottom, JournalStyle.Space.prominent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func forecastContent(_ forecast: Forecast) -> some View {
        WeatherCard(
            name: displayName, region: region, forecast: forecast, isPreview: isPreview,
            isDevice: model.target == .device)
        if !isPreview {
            updateInformation(forecast)
            updateStatus
        }
        if let openDay {
            SectionHeading(WeatherText.week.value, icon: JournalAsset.calendar)
                .padding(.top, WeatherStyle.sectionTop).padding(.bottom, WeatherStyle.sectionBottom)
            ForecastWeek(days: forecast.days, today: forecast.time?.date) { openDay(displayName, forecast, $0) }
        }
        if !isPreview {
            SectionHeading(WeatherText.details.value)
                .padding(.top, WeatherStyle.sectionTop).padding(.bottom, WeatherStyle.sectionBottom)
        }
        WeatherMetrics(forecast: forecast)
            .padding(.top, isPreview ? JournalStyle.Space.card : 0)
        Link(WeatherText.attribution.value, destination: attributionURL)
            .font(JournalStyle.Font.caption)
            .padding(.top, JournalStyle.Space.card)
    }

    @ViewBuilder private func updateInformation(_ forecast: Forecast) -> some View {
        if let time = forecast.time {
            Text(verbatim: WeatherText.asOf.format(time.clock))
                .font(JournalStyle.Font.caption)
                .foregroundColor(JournalStyle.Color.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder private var updateStatus: some View {
        if case .failed = model.phase {
            Text(WeatherText.updateFailed.value).font(JournalStyle.Font.note)
                .padding(JournalStyle.Space.page).frame(maxWidth: .infinity, alignment: .leading)
                .background(JournalStyle.Color.warning, in: RoundedRectangle(cornerRadius: JournalStyle.Radius.status))
        }
    }

    private var status: some View {
        VStack(spacing: JournalStyle.Space.item) {
            Text(WeatherText.title.value)
                .journalFont(size: JournalStyle.Size.caption, relativeTo: .caption)
                .foregroundColor(JournalStyle.Color.secondary)
            Text(statusTitle.value)
                .journalFont(size: JournalStyle.Size.statusTitle, weight: .bold, relativeTo: .title2)
            Text(statusExplanation.value)
                .journalFont(size: JournalStyle.Size.body)
                .foregroundColor(JournalStyle.Color.secondary)
                .padding(.bottom, JournalStyle.Space.row)
            statusActions
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, JournalStyle.Size.statusPadding).padding(.horizontal, JournalStyle.Space.card)
        .frame(maxWidth: .infinity)
        .background(JournalStyle.Color.surface, in: RoundedRectangle(cornerRadius: JournalStyle.Radius.status))
    }

    @ViewBuilder private var statusActions: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: JournalStyle.Space.item) {
                recoveryAction
                chooseRegionAction
            }
        } else {
            HStack(spacing: JournalStyle.Space.item) {
                recoveryAction
                chooseRegionAction
            }
        }
    }

    @ViewBuilder private var chooseRegionAction: some View {
        if let openPlaces, model.phase != .loading {
            Button(action: openPlaces) {
                Text(CommonText.choosePlace.value).journalAction(primary: model.phase == .failed(.denied))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var recoveryAction: some View {
        switch model.phase {
        case .awaitingPermission:
            Button(action: model.refresh) { Text(WeatherText.refresh.value).journalAction() }.buttonStyle(.plain)
        case .failed(.denied):
            if let requestLocationSettings {
                Button(action: requestLocationSettings) { Text(WeatherText.openSettings.value).journalAction() }
                    .buttonStyle(.plain)
            }
        case .failed(let failure):
            Button(action: model.refresh) {
                Text(failure == .unavailable ? WeatherText.retryLocation.value : CommonText.retry.value)
                    .journalAction(primary: failure == .forecast)
            }
            .buttonStyle(.plain)
        default: EmptyView()
        }
    }

    private var statusTitle: LocalizedText {
        switch model.phase {
        case .awaitingPermission: return WeatherText.enableCurrentWeather
        case .locating: return WeatherText.locating
        case .failed(.denied): return WeatherText.chooseRegionTitle
        case .failed(.unavailable): return WeatherText.locationFailureTitle
        case .failed(.forecast): return WeatherText.loadFailed
        default: return WeatherText.loading
        }
    }

    private var statusExplanation: LocalizedText {
        switch model.phase {
        case .awaitingPermission: return WeatherText.permissionUnknown
        case .locating: return WeatherText.manualChoiceHelp
        case .failed(.denied): return WeatherText.settingsExplanation
        case .failed(.unavailable): return WeatherText.locationHelp
        case .failed(.forecast): return WeatherText.networkHelp
        default: return WeatherText.loadingHelp
        }
    }

    // MARK: - 展示数据与生命周期

    private var language: String { JournalLocalization.language(for: locale) }
    private var displayName: String { model.name ?? WeatherText.currentLocation.string }

    private var region: String {
        if case .place(_, let region, _) = model.target, !region.isEmpty { return region }
        return model.target == .device ? WeatherText.currentLocation.string : WeatherText.selectedPlace.string
    }

    private func appear() {
        isVisible = true
        if scenePhase == .active { model.startAutomaticUpdates(language: language) }
    }

    private func disappear() {
        isVisible = false
        model.stopAutomaticUpdates()
    }

    private func sceneChanged(_ phase: ScenePhase) {
        // 导航栈中的隐藏页面不在回前台时重复发起刷新。
        if phase == .active, isVisible {
            model.startAutomaticUpdates(language: language)
        } else {
            model.stopAutomaticUpdates()
        }
    }
}

#if DEBUG
    @MainActor
    private struct WeatherView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                WeatherPreviewScene(.ready).previewDisplayName("天气 · 正常")
                WeatherPreviewScene(.offline).previewDisplayName("天气 · 离线缓存")
                WeatherPreviewScene(.failure).previewDisplayName("天气 · 加载失败")
                WeatherPreviewScene(.ready)
                    .environment(\.dynamicTypeSize, .accessibility3)
                    .previewDisplayName("天气 · 辅助功能字号")
            }
        }
    }
#endif
