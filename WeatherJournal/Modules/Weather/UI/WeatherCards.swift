import SwiftUI

/// 当前天气主卡使用地区当地日期，候选概览采用紧凑高度。
struct WeatherCard: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize: CGFloat = 65

    let name: String
    let region: String
    let forecast: Forecast
    let isPreview: Bool
    let isDevice: Bool

    init(name: String, region: String, forecast: Forecast, isPreview: Bool = false, isDevice: Bool = false) {
        self.name = name
        self.region = region
        self.forecast = forecast
        self.isPreview = isPreview
        self.isDevice = isDevice
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            placeHeading
            Text(verbatim: name)
                .appFont(.pageTitle, weight: .semibold)
                .padding(.top, AppSpacing.xSmall)
            Text(verbatim: WeatherPresentation.degrees(forecast.temperature))
                .font(.system(size: temperatureSize, weight: .light))
                .tracking(temperatureSize * -0.07)
                .padding(.bottom, AppSpacing.small)
            conditionSummary
        }
        .foregroundColor(AppColor.textOnAccent)
        .padding(.horizontal, 20)
        .padding(.vertical, AppSpacing.large)
        .frame(
            maxWidth: .infinity, minHeight: isPreview ? 180 : 205,
            alignment: .leading
        )
        .background { artwork }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var placeHeading: some View {
        HStack(spacing: AppSpacing.xSmall) {
            if isDevice {
                AppIcon(name: .location, size: .small)
            }
            Text(verbatim: region + dateSuffix)
        }
        .appFont(.caption)
    }

    @ViewBuilder private var conditionSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                conditionLabel
                extremes
            }
        } else {
            HStack(spacing: AppSpacing.medium) {
                conditionLabel
                extremes
            }
        }
    }

    private var conditionLabel: some View {
        let condition = WeatherPresentation.condition(forecast.code, daylight: forecast.daylight)
        return HStack(spacing: AppSpacing.xSmall) {
            WeatherArt(name: condition.art, size: 24)
            Text(condition.label.value)
                .appFont(.medium, weight: .semibold)
        }
    }

    private var extremes: some View {
        let high = WeatherText.highValue.format(WeatherPresentation.degrees(forecast.days.first?.high))
        let low = WeatherText.lowValue.format(WeatherPresentation.degrees(forecast.days.first?.low))
        return Text(verbatim: high + WeatherFormat.extremesSeparator + low)
            .appFont(.caption).monospacedDigit()
    }

    private var artwork: some View {
        GeometryReader { frame in
            Image(decorative: WeatherAsset.harbour).resizable().scaledToFill()
                .frame(width: frame.size.width, height: frame.size.height).clipped()
                .background(Color(red: 76 / 255, green: 129 / 255, blue: 158 / 255))
                .overlay {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(
                                color: Color(red: 29 / 255, green: 66 / 255, blue: 93 / 255).opacity(0.82), location: 0),
                            .init(
                                color: Color(red: 30 / 255, green: 69 / 255, blue: 95 / 255).opacity(0.33),
                                location: 0.48),
                            .init(color: .clear, location: 0.8),
                        ]), startPoint: .leading, endPoint: .trailing)
                }
        }
    }

    private var dateSuffix: String {
        guard let date = forecast.time?.date ?? forecast.days.first?.date else { return "" }
        return WeatherFormat.dateSeparator + WeatherPresentation.heroDate(date, locale: locale)
    }
}

/// 七日预报按日期、天气、温度分列；“今天”以预报地区的当地日期判断。
struct ForecastWeek: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 48

    let days: [DailyForecast]
    let today: String?
    let select: (DailyForecast) -> Void

    init(days: [DailyForecast], today: String? = nil, select: @escaping (DailyForecast) -> Void) {
        self.days = days
        self.today = today
        self.select = select
    }

    var body: some View {
        AppCard {
            VStack(spacing: 0) {
                ForEach(days) { day in
                    dayRow(day)
                    if day.id != days.last?.id { Divider().overlay(AppColor.border) }
                }
            }
            .padding(.horizontal, AppSpacing.medium)
        }
    }

    private func dayRow(_ day: DailyForecast) -> some View {
        Button {
            select(day)
        } label: {
            rowContent(day).monospacedDigit().foregroundColor(AppColor.textPrimary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(WeatherIdentifier.day(day.date))
    }

    @ViewBuilder private func rowContent(_ day: DailyForecast) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                dateLabel(day)
                condition(day)
                temperatureRange(day)
            }
            .padding(.vertical, AppSpacing.medium)
        } else {
            GeometryReader { frame in standardRow(day, width: frame.size.width) }.frame(height: rowHeight)
        }
    }

    private func standardRow(_ day: DailyForecast, width: CGFloat) -> some View {
        let gap = AppSpacing.xSmall
        let available = max(0, width - 16 - gap * 3)
        let unit = available / (1.08 + 0.85 + 1.1)
        return HStack(spacing: gap) {
            dateLabel(day).lineLimit(1).minimumScaleFactor(0.8).frame(
                width: unit * 1.08, alignment: .leading)
            condition(day).lineLimit(1).minimumScaleFactor(0.8).frame(
                width: unit * 0.85, alignment: .leading)
            temperatureRange(day).lineLimit(1).minimumScaleFactor(0.8).frame(
                width: unit * 1.1, alignment: .trailing)
            AppIcon(name: .forward, size: .small)
                .foregroundColor(AppColor.textSecondary).frame(width: 16)
        }
        .frame(height: rowHeight)
    }

    private func dateLabel(_ day: DailyForecast) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xSmall) {
            Group {
                if day.date == today {
                    Text(WeatherText.today.value)
                } else {
                    Text(verbatim: WeatherPresentation.weekday(day.date, locale: locale))
                }
            }
            .appFont(.medium, weight: .semibold)
            Text(verbatim: WeatherPresentation.shortDate(day.date, locale: locale))
                .appFont(.caption)
                .foregroundColor(AppColor.textSecondary)
        }
    }

    private func condition(_ day: DailyForecast) -> some View {
        let condition = WeatherPresentation.condition(day.code, daylight: .day)
        return HStack(spacing: AppSpacing.xSmall) {
            WeatherArt(name: condition.art, size: 28)
            Text(condition.label.value).appFont(.caption)
        }
    }

    private func temperatureRange(_ day: DailyForecast) -> some View {
        HStack(spacing: AppSpacing.xSmall) {
            Text(verbatim: WeatherPresentation.degrees(day.low))
                .accessibilityLabel(Text(verbatim: WeatherText.lowValue.format(WeatherPresentation.degrees(day.low))))
            if let low = day.low, let high = day.high, let lowest, let highest, highest > lowest {
                TemperatureRange(low: low, high: high, minimum: lowest, maximum: highest)
            }
            Text(verbatim: WeatherPresentation.degrees(day.high))
                .accessibilityLabel(Text(verbatim: WeatherText.highValue.format(WeatherPresentation.degrees(day.high))))
        }
        .appFont(.small)
    }

    private var lowest: Double? { days.compactMap(\.low).min() }
    private var highest: Double? { days.compactMap(\.high).max() }
}

private struct TemperatureRange: View {
    let low, high, minimum, maximum: Double

    var body: some View {
        GeometryReader { frame in
            let start = CGFloat((low - minimum) / (maximum - minimum)) * frame.size.width
            let span = CGFloat((high - low) / (maximum - minimum)) * frame.size.width
            Capsule().fill(AppColor.fill)
                .overlay(alignment: .leading) {
                    Capsule().fill(
                        LinearGradient(
                            colors: [
                                Color(red: 115 / 255, green: 175 / 255, blue: 191 / 255),
                                Color(red: 240 / 255, green: 189 / 255, blue: 105 / 255),
                            ],
                            startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(2, span)).offset(x: start)
                }
                .clipShape(Capsule())
        }
        .frame(width: 37, height: 4).accessibilityHidden(true)
    }
}

/// 当前天气指标按辅助功能字号切换列数，保持标题和值的朗读关系。
struct WeatherMetrics: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var metricSize: CGFloat = 23

    let forecast: Forecast

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.small) {
            metric(
                WeatherText.feelsLike.value, art: WeatherAsset.thermometer,
                value: WeatherPresentation.degrees(forecast.feelsLike))
            metric(
                WeatherText.humidity.value, art: WeatherAsset.humidity,
                value: WeatherPresentation.metric(forecast.humidity, unit: WeatherFormat.percent))
            metric(
                WeatherText.wind.value, art: WeatherAsset.wind,
                value: WeatherPresentation.metric(forecast.wind, unit: WeatherFormat.windUnit))
            metric(
                WeatherText.sunset.value, art: WeatherAsset.sunset,
                value: forecast.days.first?.sunset?.clock ?? WeatherFormat.unavailable)
        }
    }

    private func metric(_ title: LocalizedStringKey, art: String, value: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: AppSpacing.xSmall) {
                    WeatherArt(name: art, size: 16)
                    Text(title).appFont(.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
                Text(verbatim: value).font(.system(size: metricSize, weight: .medium)).monospacedDigit()
            }
            .padding(AppSpacing.medium).frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: AppSpacing.small), GridItem(.flexible())]
    }
}

#if DEBUG
    @MainActor
    private struct WeatherCards_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                WeatherCard(
                    name: WeatherPreviewData.name, region: WeatherPreviewData.region,
                    forecast: WeatherPreviewData.forecast, isDevice: true
                ).previewDisplayName("当前天气卡")
                ForecastWeek(
                    days: WeatherPreviewData.forecast.days, today: WeatherPreviewData.forecast.time?.date,
                    select: { _ in }
                ).previewDisplayName("七日预报")
                WeatherMetrics(forecast: WeatherPreviewData.forecast).previewDisplayName("天气指标")
                WeatherMetrics(forecast: WeatherPreviewData.forecast)
                    .environment(\.dynamicTypeSize, .accessibility3).previewDisplayName("天气指标 · 大字号")
            }
            .padding(AppSpacing.large).frame(width: JournalPreview.contentWidth)
            .journalPreview().previewLayout(.sizeThatFits)
        }
    }
#endif
