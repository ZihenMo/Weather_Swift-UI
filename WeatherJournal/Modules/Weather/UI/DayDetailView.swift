import SwiftUI

/// 单日详情持有进入时的预报快照，切换时段只筛选本地数据。
struct DayDetailView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var period: DayPeriod

    let name: String
    let forecast: Forecast
    let day: DailyForecast

    init(name: String, forecast: Forecast, day: DailyForecast) {
        self.name = name
        self.forecast = forecast
        self.day = day
        _period = State(initialValue: forecast.initialPeriod(for: day.date))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: JournalStyle.Space.section) {
                dailySummary
                SectionHeading(WeatherText.hourly.value)
                hourlySection
            }
            .padding(JournalStyle.Space.page)
        }
        .background(JournalStyle.Color.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { navigationTitle } }
    }

    private var dailySummary: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: JournalStyle.Space.related) {
                    conditionLabel
                    HStack {
                        extreme(WeatherText.low, day.low)
                        Spacer()
                        extreme(WeatherText.high, day.high)
                    }
                }
            } else {
                HStack {
                    conditionLabel
                    Spacer()
                    extreme(WeatherText.low, day.low)
                    extreme(WeatherText.high, day.high)
                }
            }
        }
        .foregroundColor(JournalStyle.Color.onAccent)
        .padding(JournalStyle.Space.page)
        .background(JournalStyle.Color.sea, in: RoundedRectangle(cornerRadius: JournalStyle.Radius.summary))
    }

    private var conditionLabel: some View {
        let condition = WeatherPresentation.condition(day.code, daylight: .day)
        return HStack {
            WeatherArt(name: condition.art, size: WeatherStyle.detailIcon)
            Text(condition.label.value).font(JournalStyle.Font.headline)
        }
    }

    private func extreme(_ title: LocalizedText, _ temperature: Double?) -> some View {
        VStack(alignment: .leading, spacing: JournalStyle.Space.hairline) {
            Text(title.value).font(JournalStyle.Font.caption)
            Text(verbatim: WeatherPresentation.degrees(temperature)).font(JournalStyle.Font.section)
        }
        .accessibilityElement(children: .combine)
    }

    private var hourlySection: some View {
        VStack(spacing: JournalStyle.Space.section) {
            if dynamicTypeSize.isAccessibilitySize {
                periodPicker.pickerStyle(.menu)
            } else {
                periodPicker.pickerStyle(.segmented)
            }
            hourlyContent
        }
        .monospacedDigit()
        .padding(JournalStyle.Space.card)
        .journalCard()
    }

    private var periodPicker: some View {
        Picker(WeatherText.period.value, selection: $period) {
            Text(WeatherText.night.value).tag(DayPeriod.night)
            Text(WeatherText.morning.value).tag(DayPeriod.morning)
            Text(WeatherText.afternoon.value).tag(DayPeriod.afternoon)
            Text(WeatherText.evening.value).tag(DayPeriod.evening)
        }
    }

    @ViewBuilder private var hourlyContent: some View {
        let hours = forecast.hours(on: day.date, in: period)
        if hours.isEmpty {
            Text(WeatherText.noHours.value).foregroundColor(JournalStyle.Color.secondary)
        } else if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                HourlyForecastView(hours: hours).frame(
                    minWidth: CGFloat(hours.count) * WeatherStyle.accessibleHourWidth)
            }
        } else {
            HourlyForecastView(hours: hours)
        }
    }

    private var navigationTitle: some View {
        VStack(spacing: JournalStyle.Space.hairline) {
            Text(verbatim: name).font(JournalStyle.Font.headline)
            Text(verbatim: WeatherPresentation.date(day.date, locale: locale)).font(JournalStyle.Font.caption)
        }
        .accessibilityElement(children: .combine)
    }
}
