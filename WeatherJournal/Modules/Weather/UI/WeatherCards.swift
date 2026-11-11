import SwiftUI

/// 当前天气主卡使用地区当地日期，候选概览采用紧凑高度。
struct WeatherCard: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize = WeatherStyle.temperatureSize

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
                .journalFont(size: WeatherStyle.FontSize.place, weight: .bold, relativeTo: .largeTitle)
                .tracking(WeatherStyle.heroNameTracking).padding(.top, JournalStyle.Space.label)
            Text(verbatim: WeatherPresentation.degrees(forecast.temperature))
                .journalFont(size: WeatherStyle.temperatureSize, weight: .light, relativeTo: .largeTitle)
                .tracking(temperatureSize * WeatherStyle.temperatureTrackingRatio)
                .padding(.top, JournalStyle.Space.hairline).padding(.bottom, WeatherStyle.conditionBottom)
            conditionSummary
        }
        .foregroundColor(JournalStyle.Color.onAccent)
        .padding(.horizontal, JournalStyle.Space.prominent)
        .padding(.vertical, WeatherStyle.heroVerticalPadding)
        .frame(
            maxWidth: .infinity, minHeight: isPreview ? WeatherStyle.previewHeroHeight : WeatherStyle.heroHeight,
            alignment: .leading
        )
        .background { artwork }
        .clipShape(RoundedRectangle(cornerRadius: JournalStyle.Radius.hero, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var placeHeading: some View {
        HStack(spacing: JournalStyle.Space.small) {
            if isDevice {
                Image(systemName: JournalSymbol.location)
                    .journalFont(size: WeatherStyle.locationIcon, relativeTo: .caption)
                    .accessibilityHidden(true)
            }
            Text(verbatim: region + dateSuffix)
        }
        .journalFont(size: WeatherStyle.FontSize.caption, relativeTo: .caption)
    }

    @ViewBuilder private var conditionSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: JournalStyle.Space.related) {
                conditionLabel
                extremes
            }
        } else {
            HStack(spacing: WeatherStyle.heroFootSpacing) {
                conditionLabel
                extremes
            }
        }
    }

    private var conditionLabel: some View {
        let condition = WeatherPresentation.condition(forecast.code, daylight: forecast.daylight)
        return HStack(spacing: JournalStyle.Space.small) {
            WeatherArt(name: condition.art, size: WeatherStyle.conditionIcon)
            Text(condition.label.value)
                .journalFont(size: WeatherStyle.FontSize.body, weight: .semibold, relativeTo: .body)
        }
    }

    private var extremes: some View {
        let high = WeatherText.highValue.format(WeatherPresentation.degrees(forecast.days.first?.high))
        let low = WeatherText.lowValue.format(WeatherPresentation.degrees(forecast.days.first?.low))
        return Text(verbatim: high + WeatherFormat.extremesSeparator + low)
            .journalFont(size: WeatherStyle.FontSize.caption, relativeTo: .caption).monospacedDigit()
    }

    private var artwork: some View {
        GeometryReader { frame in
            Image(decorative: WeatherAsset.harbour).resizable().scaledToFill()
                .frame(width: frame.size.width, height: frame.size.height).clipped()
                .background(JournalStyle.Color.sky)
                .overlay(LinearGradient(gradient: WeatherStyle.heroGradient, startPoint: .leading, endPoint: .trailing))
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
    @ScaledMetric(relativeTo: .body) private var rowHeight = WeatherStyle.dayRowHeight

    let days: [DailyForecast]
    let today: String?
    let select: (DailyForecast) -> Void

    init(days: [DailyForecast], today: String? = nil, select: @escaping (DailyForecast) -> Void) {
        self.days = days
        self.today = today
        self.select = select
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(days) { day in
                dayRow(day)
                if day.id != days.last?.id { Divider().overlay(WeatherStyle.Color.forecastLine) }
            }
        }
        .padding(.horizontal, JournalStyle.Space.card).journalCard()
    }

    private func dayRow(_ day: DailyForecast) -> some View {
        Button {
            select(day)
        } label: {
            rowContent(day).monospacedDigit().foregroundColor(JournalStyle.Color.ink)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(WeatherIdentifier.day(day.date))
    }

    @ViewBuilder private func rowContent(_ day: DailyForecast) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: JournalStyle.Space.item) {
                dateLabel(day)
                condition(day)
                temperatureRange(day)
            }
            .padding(.vertical, JournalStyle.Space.row)
        } else {
            GeometryReader { frame in standardRow(day, width: frame.size.width) }.frame(height: rowHeight)
        }
    }

    private func standardRow(_ day: DailyForecast, width: CGFloat) -> some View {
        let available =
            width - WeatherStyle.chevronWidth - WeatherStyle.forecastColumnGap * WeatherStyle.forecastGapCount
        let unit =
            available
            / (WeatherStyle.dateColumnRatio + WeatherStyle.conditionColumnRatio
                + WeatherStyle.temperatureColumnRatio)
        return HStack(spacing: WeatherStyle.forecastColumnGap) {
            dateLabel(day).lineLimit(1).minimumScaleFactor(WeatherStyle.minimumLabelScale).frame(
                width: unit * WeatherStyle.dateColumnRatio, alignment: .leading)
            condition(day).lineLimit(1).minimumScaleFactor(WeatherStyle.minimumLabelScale).frame(
                width: unit * WeatherStyle.conditionColumnRatio, alignment: .leading)
            temperatureRange(day).lineLimit(1).minimumScaleFactor(WeatherStyle.minimumLabelScale).frame(
                width: unit * WeatherStyle.temperatureColumnRatio, alignment: .trailing)
            JournalIcon(name: JournalAsset.forward, size: WeatherStyle.FontSize.caption)
                .foregroundColor(JournalStyle.Color.secondary).frame(width: WeatherStyle.chevronWidth)
        }
        .frame(height: rowHeight)
    }

    private func dateLabel(_ day: DailyForecast) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: JournalStyle.Space.small) {
            Group {
                if day.date == today {
                    Text(WeatherText.today.value)
                } else {
                    Text(verbatim: WeatherPresentation.weekday(day.date, locale: locale))
                }
            }
            .journalFont(size: WeatherStyle.FontSize.body, weight: .semibold, relativeTo: .body)
            Text(verbatim: WeatherPresentation.shortDate(day.date, locale: locale))
                .journalFont(size: WeatherStyle.FontSize.date, relativeTo: .caption2)
                .foregroundColor(JournalStyle.Color.secondary)
        }
    }

    private func condition(_ day: DailyForecast) -> some View {
        let condition = WeatherPresentation.condition(day.code, daylight: .day)
        return HStack(spacing: JournalStyle.Space.label) {
            WeatherArt(name: condition.art, size: WeatherStyle.dayIcon)
            Text(condition.label.value).journalFont(size: WeatherStyle.FontSize.caption, relativeTo: .caption)
        }
    }

    private func temperatureRange(_ day: DailyForecast) -> some View {
        HStack(spacing: JournalStyle.Space.label) {
            Text(verbatim: WeatherPresentation.degrees(day.low))
                .accessibilityLabel(Text(verbatim: WeatherText.lowValue.format(WeatherPresentation.degrees(day.low))))
            if let low = day.low, let high = day.high, let lowest, let highest, highest > lowest {
                TemperatureRange(low: low, high: high, minimum: lowest, maximum: highest)
            }
            Text(verbatim: WeatherPresentation.degrees(day.high))
                .accessibilityLabel(Text(verbatim: WeatherText.highValue.format(WeatherPresentation.degrees(day.high))))
        }
        .journalFont(size: WeatherStyle.FontSize.temperatureRange, relativeTo: .footnote)
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
            Capsule().fill(WeatherStyle.Color.track)
                .overlay(alignment: .leading) {
                    Capsule().fill(
                        LinearGradient(
                            colors: [WeatherStyle.Color.rangeCool, WeatherStyle.Color.rangeWarm],
                            startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(WeatherStyle.minimumRangeWidth, span)).offset(x: start)
                }
                .clipShape(Capsule())
        }
        .frame(width: WeatherStyle.rangeWidth, height: WeatherStyle.rangeHeight).accessibilityHidden(true)
    }
}

/// 当前天气指标按辅助功能字号切换列数，保持标题和值的朗读关系。
struct WeatherMetrics: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let forecast: Forecast

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: JournalStyle.Space.item) {
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: JournalStyle.Space.small) {
                WeatherArt(name: art, size: WeatherStyle.metricIcon)
                Text(title).journalFont(size: WeatherStyle.FontSize.caption, relativeTo: .caption)
                    .foregroundColor(JournalStyle.Color.secondary)
            }
            Text(verbatim: value).journalFont(size: WeatherStyle.FontSize.metric, weight: .medium, relativeTo: .title2)
                .monospacedDigit()
        }
        .padding(JournalStyle.Space.card).frame(maxWidth: .infinity, alignment: .leading)
        .background(JournalStyle.Color.surface, in: RoundedRectangle(cornerRadius: WeatherStyle.metricRadius))
        .accessibilityElement(children: .combine)
    }

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: JournalStyle.Space.item), GridItem(.flexible())]
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
            .padding(JournalStyle.Space.page).frame(width: JournalPreview.contentWidth)
            .journalPreview().previewLayout(.sizeThatFits)
        }
    }
#endif
