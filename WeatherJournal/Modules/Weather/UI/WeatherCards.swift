import SwiftUI

/// 当前天气主卡，日期使用预报所属地点的当地日期。
struct WeatherCard: View {
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize = WeatherStyle.temperatureSize

    let name: String
    let region: String
    let forecast: Forecast

    var body: some View {
        VStack(alignment: .leading, spacing: JournalStyle.Space.label) {
            placeHeading
            Text(verbatim: name).font(JournalStyle.Font.title)
            Text(verbatim: WeatherPresentation.degrees(forecast.temperature))
                .font(JournalStyle.Font.temperature(size: temperatureSize))
            conditionSummary
        }
        .foregroundColor(JournalStyle.Color.onAccent)
        .padding(JournalStyle.Space.prominent)
        .frame(maxWidth: .infinity, minHeight: WeatherStyle.heroHeight, alignment: .leading)
        .background { artwork }
        .clipShape(RoundedRectangle(cornerRadius: JournalStyle.Radius.hero, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var placeHeading: some View {
        HStack {
            Text(verbatim: region)
            if let today = forecast.days.first {
                Text(verbatim: WeatherFormat.dateSeparator + WeatherPresentation.date(today.date, locale: locale))
            }
        }
        .font(JournalStyle.Font.caption)
    }

    private var conditionSummary: some View {
        let condition = WeatherPresentation.condition(forecast.code, daylight: forecast.daylight)
        return HStack(spacing: JournalStyle.Space.related) {
            WeatherArt(name: condition.art, size: WeatherStyle.conditionIcon)
            Text(condition.label.value)
            Spacer(minLength: JournalStyle.Space.small)
            extremes
        }
    }

    private var extremes: some View {
        let high = WeatherPresentation.degrees(forecast.days.first?.high)
        let low = WeatherPresentation.degrees(forecast.days.first?.low)
        return Text(verbatim: String(format: WeatherFormat.extremes, high, low))
            .monospacedDigit()
            .accessibilityLabel(
                Text(
                    verbatim: WeatherText.highValue.format(high)
                        + WeatherFormat.dateSeparator + WeatherText.lowValue.format(low)))
    }

    private var artwork: some View {
        GeometryReader { frame in
            Image(decorative: WeatherAsset.harbour)
                .resizable()
                .scaledToFill()
                .frame(width: frame.size.width, height: frame.size.height)
                .clipped()
                .background(JournalStyle.Color.sky)
                .overlay(
                    LinearGradient(
                        colors: [
                            JournalStyle.Color.sea.opacity(WeatherStyle.gradientStart),
                            JournalStyle.Color.sea.opacity(WeatherStyle.gradientEnd),
                        ],
                        startPoint: .leading, endPoint: .trailing))
        }
    }
}

/// 七日列表只负责展示与选择，温度范围共用同一周的刻度。
struct ForecastWeek: View {
    @Environment(\.locale) private var locale

    let days: [DailyForecast]
    let select: (DailyForecast) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(days) { day in
                dayRow(day)
                if day.id != days.last?.id { Divider() }
            }
        }
        .padding(.horizontal, JournalStyle.Space.card)
        .journalCard()
    }

    private func dayRow(_ day: DailyForecast) -> some View {
        Button {
            select(day)
        } label: {
            rowContent(day)
                .monospacedDigit()
                .padding(.vertical, WeatherStyle.dayRowPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(WeatherIdentifier.day(day.date))
    }

    private func rowContent(_ day: DailyForecast) -> some View {
        let condition = WeatherPresentation.condition(day.code, daylight: .day)
        return HStack(spacing: JournalStyle.Space.item) {
            WeatherArt(name: condition.art, size: WeatherStyle.dayIcon)
            VStack(alignment: .leading, spacing: JournalStyle.Space.tight) {
                Text(verbatim: WeatherPresentation.date(day.date, locale: locale)).font(JournalStyle.Font.headline)
                Text(condition.label.value)
                    .font(JournalStyle.Font.caption)
                    .foregroundColor(JournalStyle.Color.secondary)
            }
            Spacer(minLength: 0)
            temperatureRange(day)
            Image(systemName: JournalSymbol.forward)
                .font(JournalStyle.Font.caption)
                .foregroundColor(JournalStyle.Color.secondary)
        }
    }

    @ViewBuilder private func temperatureRange(_ day: DailyForecast) -> some View {
        Text(verbatim: WeatherPresentation.degrees(day.low))
            .accessibilityLabel(Text(verbatim: WeatherText.lowValue.format(WeatherPresentation.degrees(day.low))))
        if let low = day.low, let high = day.high, let lowest, let highest, highest > lowest {
            TemperatureRange(low: low, high: high, minimum: lowest, maximum: highest)
        }
        Text(verbatim: WeatherPresentation.degrees(day.high))
            .accessibilityLabel(Text(verbatim: WeatherText.highValue.format(WeatherPresentation.degrees(day.high))))
    }

    private var lowest: Double? { days.compactMap(\.low).min() }
    private var highest: Double? { days.compactMap(\.high).max() }
}

private struct TemperatureRange: View {
    let low, high, minimum, maximum: Double

    var body: some View {
        GeometryReader { frame in
            let width = frame.size.width
            let start = CGFloat((low - minimum) / (maximum - minimum)) * width
            let span = CGFloat((high - low) / (maximum - minimum)) * width
            Capsule().fill(JournalStyle.Color.track)
                .overlay(alignment: .leading) {
                    Capsule().fill(
                        LinearGradient(
                            colors: [JournalStyle.Color.sky, JournalStyle.Color.warm], startPoint: .leading,
                            endPoint: .trailing)
                    )
                    .frame(width: max(WeatherStyle.minimumRangeWidth, span)).offset(x: start)
                }
                .clipShape(Capsule())
        }
        .frame(width: WeatherStyle.rangeWidth, height: WeatherStyle.rangeHeight)
        .accessibilityHidden(true)
    }
}

/// 当前天气指标按辅助功能字号切换列数，保持标题和值的朗读关系。
struct WeatherMetrics: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let forecast: Forecast

    var body: some View {
        LazyVGrid(
            columns: dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading,
            spacing: JournalStyle.Space.item
        ) {
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
        VStack(alignment: .leading, spacing: JournalStyle.Space.related) {
            HStack(spacing: JournalStyle.Space.related) {
                WeatherArt(name: art, size: WeatherStyle.metricIcon)
                Text(title).font(JournalStyle.Font.label).foregroundColor(JournalStyle.Color.secondary)
            }
            Text(verbatim: value).font(JournalStyle.Font.metric).monospacedDigit()
        }
        .padding(JournalStyle.Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .journalCard()
        .accessibilityElement(children: .combine)
    }
}
