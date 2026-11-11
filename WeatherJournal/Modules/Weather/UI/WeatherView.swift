import SwiftUI

/// 首页与候选概览共用的天气内容，只展示模型状态并转发用户操作。
struct WeatherView: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var model: WeatherViewModel
    @State private var isVisible = false

    let attributionURL: URL
    var openPlaces: (() -> Void)?
    var openDay: ((String, Forecast, DailyForecast) -> Void)?

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView { content }
                .onChange(of: model.target) { _ in scroll.scrollTo(WeatherIdentifier.top, anchor: .top) }
        }
        .background(JournalStyle.Color.background.ignoresSafeArea())
        .onAppear(perform: appear)
        .onDisappear { isVisible = false }
        .onChange(of: language) { model.activate(language: $0) }
        .onChange(of: scenePhase, perform: sceneChanged)
    }

    // MARK: - 天气内容

    private var content: some View {
        VStack(alignment: .leading, spacing: JournalStyle.Space.card) {
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
        WeatherCard(name: displayName, region: region, forecast: forecast)
        updateInformation(forecast)
        updateStatus
        if let openDay {
            SectionHeading(WeatherText.week.value)
            ForecastWeek(days: forecast.days) { openDay(displayName, forecast, $0) }
        }
        SectionHeading(WeatherText.details.value)
        WeatherMetrics(forecast: forecast)
        Link(WeatherText.attribution.value, destination: attributionURL)
            .font(JournalStyle.Font.caption)
    }

    private func updateInformation(_ forecast: Forecast) -> some View {
        VStack(alignment: .leading, spacing: JournalStyle.Space.item) {
            if let time = forecast.time {
                Text(verbatim: WeatherText.asOf.format(WeatherPresentation.timestamp(time, locale: locale)))
                    .font(JournalStyle.Font.note)
                    .foregroundColor(JournalStyle.Color.secondary)
            }
            cacheInformation
            Button(action: model.refresh) {
                Label(WeatherText.refresh.value, systemImage: JournalSymbol.refresh)
            }
            .disabled(isUpdating)
        }
    }

    @ViewBuilder private var cacheInformation: some View {
        if model.source != .live, let snapshot = model.snapshot {
            Text(verbatim: WeatherText.cached.format(WeatherPresentation.cachedAt(snapshot.fetchedAt, locale: locale)))
                .font(JournalStyle.Font.note)
        }
        if model.source == .previousLocation {
            Text(WeatherText.previousLocation.value).font(JournalStyle.Font.note)
        }
    }

    @ViewBuilder private var updateStatus: some View {
        if isUpdating { ProgressView().progressViewStyle(.linear) }
        if case .failed = model.phase {
            Text(WeatherText.updateFailed.value).font(JournalStyle.Font.note)
        }
    }

    private var status: some View {
        VStack(spacing: JournalStyle.Space.page) {
            statusMessage
            if let openPlaces { Button(CommonText.choosePlace.value, action: openPlaces) }
        }
        .multilineTextAlignment(.center)
        .padding(JournalStyle.Space.status)
        .frame(maxWidth: .infinity)
        .journalCard()
    }

    @ViewBuilder private var statusMessage: some View {
        switch model.phase {
        case .idle, .locating, .loading:
            ProgressView()
            Text(model.phase == .locating ? WeatherText.locating.value : WeatherText.loading.value)
        case .failed(let failure):
            failureMessage(failure)
            Button(CommonText.retry.value, action: model.refresh).buttonStyle(.bordered)
        case .ready:
            EmptyView()
        }
    }

    @ViewBuilder private func failureMessage(_ failure: WeatherViewModel.Failure) -> some View {
        switch failure {
        case .denied: Text(WeatherText.permissionDenied.value)
        case .unavailable: Text(WeatherText.locationUnavailable.value)
        case .forecast: Text(WeatherText.loadFailed.value)
        }
    }

    // MARK: - 展示数据与生命周期

    private var language: String { JournalLocalization.language(for: locale) }
    private var displayName: String { model.name ?? WeatherText.currentLocation.string }
    private var isUpdating: Bool { model.phase == .loading || model.phase == .locating }

    private var region: String {
        if case .place(_, let region, _) = model.target, !region.isEmpty { return region }
        return model.target == .device ? WeatherText.currentLocation.string : WeatherText.selectedPlace.string
    }

    private func appear() {
        isVisible = true
        model.activate(language: language)
    }

    private func sceneChanged(_ phase: ScenePhase) {
        // 导航栈中的隐藏页面不在回前台时重复发起刷新。
        if phase == .active, isVisible { model.activate(language: language) }
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
