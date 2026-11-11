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
        .background((isPreview ? AppColor.surfaceRaised : AppColor.background).ignoresSafeArea())
        .onAppear(perform: appear)
        .onDisappear(perform: disappear)
        .onChange(of: language) { if isVisible, scenePhase == .active { model.startAutomaticUpdates(language: $0) } }
        .onChange(of: scenePhase, perform: sceneChanged)
    }

    // MARK: - 天气内容

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).id(WeatherIdentifier.top)
            if let forecast = model.forecast {
                forecastContent(forecast)
            } else {
                status
            }
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.bottom, AppSpacing.large)
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
            AppSectionTitle(WeatherText.week.value, icon: .calendar)
                .padding(.top, AppSpacing.large).padding(.bottom, AppSpacing.small)
            ForecastWeek(days: forecast.days, today: forecast.time?.date) { openDay(displayName, forecast, $0) }
        }
        if !isPreview {
            AppSectionTitle(WeatherText.details.value)
                .padding(.top, AppSpacing.large).padding(.bottom, AppSpacing.small)
        }
        WeatherMetrics(forecast: forecast)
            .padding(.top, isPreview ? AppSpacing.medium : 0)
        Link(WeatherText.attribution.value, destination: attributionURL)
            .appFont(.caption)
            .foregroundColor(AppColor.accent)
            .padding(.top, AppSpacing.medium)
            .frame(minHeight: 44)
    }

    @ViewBuilder private func updateInformation(_ forecast: Forecast) -> some View {
        if let time = forecast.time {
            Text(verbatim: WeatherText.asOf.format(time.clock))
                .appFont(.caption)
                .foregroundColor(AppColor.textSecondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder private var updateStatus: some View {
        if case .failed = model.phase {
            AppNotice(WeatherText.updateFailed.value)
        }
    }

    private var status: some View {
        AppCard {
            VStack(spacing: AppSpacing.small) {
                Text(WeatherText.title.value)
                    .appFont(.caption)
                    .foregroundColor(AppColor.textSecondary)
                Text(statusTitle.value)
                    .appFont(.title, weight: .semibold)
                Text(statusExplanation.value)
                    .appFont(.medium)
                    .foregroundColor(AppColor.textSecondary)
                    .padding(.bottom, AppSpacing.large)
                statusActions
            }
            .multilineTextAlignment(.center)
            .padding(.vertical, 48).padding(.horizontal, AppSpacing.medium)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var statusActions: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: AppSpacing.small) {
                recoveryAction
                chooseRegionAction
            }
        } else {
            HStack(spacing: AppSpacing.small) {
                recoveryAction
                chooseRegionAction
            }
        }
    }

    @ViewBuilder private var chooseRegionAction: some View {
        if let openPlaces, model.phase != .loading {
            Button(CommonText.choosePlace.value, action: openPlaces)
                .buttonStyle(AppButtonStyle(model.phase == .failed(.denied) ? .primary : .secondary))
        }
    }

    @ViewBuilder private var recoveryAction: some View {
        switch model.phase {
        case .awaitingPermission:
            Button(WeatherText.refresh.value, action: model.refresh).buttonStyle(AppButtonStyle(.secondary))
        case .failed(.denied):
            if let requestLocationSettings {
                Button(WeatherText.openSettings.value, action: requestLocationSettings)
                    .buttonStyle(AppButtonStyle(.secondary))
            }
        case .failed(let failure):
            Button(action: model.refresh) {
                Text(failure == .unavailable ? WeatherText.retryLocation.value : CommonText.retry.value)
            }
            .buttonStyle(AppButtonStyle(failure == .forecast ? .primary : .secondary))
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
