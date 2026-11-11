import SwiftUI

/// 首页与候选概览共用的天气内容，只展示模型状态并转发用户操作。
struct WeatherView: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var model: WeatherViewModel
    @State private var isVisible = false

    var isPreview = false
    let attributionURL: URL
    var openPlaces: (() -> Void)?
    var openDay: ((String, Forecast, DailyForecast) -> Void)?

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView { content }
                .onChange(of: model.target) { _ in scroll.scrollTo(WeatherIdentifier.top, anchor: .top) }
        }
        .background((isPreview ? JournalStyle.Color.panel : JournalStyle.Color.background).ignoresSafeArea())
        .onAppear(perform: appear)
        .onDisappear { isVisible = false }
        .onChange(of: language) { model.activate(language: $0) }
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
