import SwiftUI

/// 单日详情持有进入时的预报快照，切换时段只筛选本地数据。
struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var period: DayPeriod
    @State private var availableWidth: CGFloat = 0

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
            VStack(alignment: .leading, spacing: 0) {
                navigationHeader.padding(.bottom, JournalStyle.Space.item)
                dailySummary
                SectionHeading(WeatherText.hourly.value)
                    .padding(.top, WeatherStyle.sectionTop).padding(.bottom, WeatherStyle.sectionBottom)
                    .padding(.horizontal, JournalStyle.Space.tight)
                hourlySection
            }
            .background {
                GeometryReader { geometry in
                    JournalStyle.Color.transparent.onAppear { availableWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { availableWidth = $0 }
                }
            }
            .padding(.horizontal, JournalStyle.Space.page).padding(.bottom, JournalStyle.Space.page)
        }
        .background(JournalStyle.Color.background.ignoresSafeArea()).navigationBarHidden(true)
    }

    @ViewBuilder private var navigationHeader: some View {
        if dynamicTypeSize >= .xxLarge || availableWidth < WeatherStyle.compactNavigationWidth {
            VStack(alignment: .leading, spacing: JournalStyle.Space.item) {
                backButton
                navigationTitle.frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: JournalStyle.Space.item) {
                backButton.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                navigationTitle.lineLimit(1).minimumScaleFactor(WeatherStyle.minimumLabelScale)
                    .layoutPriority(WeatherStyle.navigationTitlePriority)
                    .frame(minWidth: 0, maxWidth: .infinity)
                JournalStyle.Color.transparent.frame(minWidth: 0, maxWidth: .infinity)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
            .frame(minHeight: WeatherStyle.navigationHeight)
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: JournalStyle.Space.small) {
                JournalIcon(name: JournalAsset.back, size: WeatherStyle.FontSize.back)
                Text(WeatherText.title.value)
            }
            .journalFont(size: WeatherStyle.FontSize.back, relativeTo: .callout)
            .foregroundColor(JournalStyle.Color.accent)
            .frame(minWidth: JournalStyle.Size.touchTarget, minHeight: JournalStyle.Size.touchTarget)
            .fixedSize(horizontal: true, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var navigationTitle: some View {
        VStack(spacing: JournalStyle.Space.small) {
            Text(verbatim: name)
                .journalFont(size: WeatherStyle.FontSize.navigation, weight: .semibold, relativeTo: .headline)
            Text(verbatim: WeatherPresentation.date(day.date, locale: locale))
                .journalFont(size: WeatherStyle.FontSize.caption, relativeTo: .caption)
                .foregroundColor(JournalStyle.Color.secondary)
        }
        .multilineTextAlignment(.center).accessibilityElement(children: .combine)
    }

    private var dailySummary: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: JournalStyle.Space.related) {
                    conditionLabel
                    extremes
                }
            } else {
                HStack {
                    conditionLabel
                    Spacer(minLength: JournalStyle.Space.item)
                    extremes
                }
            }
        }
        .foregroundColor(JournalStyle.Color.onAccent)
        .padding(.vertical, WeatherStyle.summaryVerticalPadding).padding(.horizontal, JournalStyle.Space.prominent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(summaryGradient, in: RoundedRectangle(cornerRadius: WeatherStyle.summaryRadius))
    }

    private var conditionLabel: some View {
        let condition = WeatherPresentation.condition(day.code, daylight: .day)
        return HStack(spacing: JournalStyle.Space.item) {
            WeatherArt(name: condition.art, size: WeatherStyle.detailIcon)
            Text(condition.label.value)
                .journalFont(size: WeatherStyle.FontSize.summary, weight: .bold, relativeTo: .title3)
        }
    }

    private var extremes: some View {
        HStack(spacing: WeatherStyle.extremeSpacing) {
            extreme(WeatherText.low, day.low)
            extreme(WeatherText.high, day.high)
        }
    }

    private func extreme(_ title: LocalizedText, _ temperature: Double?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.value).journalFont(size: WeatherStyle.FontSize.extremeLabel, relativeTo: .caption2)
                .foregroundColor(WeatherStyle.Color.extremeLabel)
            Text(verbatim: WeatherPresentation.degrees(temperature))
                .journalFont(size: WeatherStyle.FontSize.extreme, weight: .medium, relativeTo: .title2)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryGradient: LinearGradient {
        LinearGradient(
            colors: [WeatherStyle.Color.summaryStart, WeatherStyle.Color.summaryEnd],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var hourlySection: some View {
        VStack(spacing: 0) {
            periodSelection.padding(.bottom, WeatherStyle.periodBottom)
            hourlyContent
        }
        .monospacedDigit()
        .padding(.horizontal, WeatherStyle.hourCardHorizontalPadding)
        .padding(.top, WeatherStyle.hourCardTopPadding).padding(.bottom, WeatherStyle.hourCardBottomPadding)
        .background(
            LinearGradient(gradient: WeatherStyle.hourGradient, startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: WeatherStyle.hourCardRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WeatherStyle.hourCardRadius)
                .stroke(WeatherStyle.Color.hourBorder, lineWidth: JournalStyle.Space.hairline)
        )
        .shadow(
            color: WeatherStyle.Color.hourShadow, radius: WeatherStyle.shadowRadius,
            y: WeatherStyle.shadowOffset)
    }

    @ViewBuilder private var periodSelection: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker(WeatherText.period.value, selection: $period) {
                ForEach(DayPeriod.allCases, id: \.self) { value in Text(title(value).value).tag(value) }
            }
            .pickerStyle(.menu)
        } else {
            HStack(spacing: JournalStyle.Space.tight) {
                ForEach(DayPeriod.allCases, id: \.self) { periodButton($0) }
            }
            .padding(JournalStyle.Space.compact)
            .background(
                WeatherStyle.Color.periodBackground,
                in: RoundedRectangle(cornerRadius: WeatherStyle.periodRadius)
            )
            .padding(.horizontal, JournalStyle.Space.hairline)
            .accessibilityElement(children: .contain).accessibilityLabel(Text(WeatherText.period.value))
        }
    }

    private func periodButton(_ value: DayPeriod) -> some View {
        Button {
            period = value
        } label: {
            Text(title(value).value)
                .journalFont(
                    size: WeatherStyle.FontSize.period, weight: period == value ? .semibold : .regular,
                    relativeTo: .footnote
                )
                .foregroundColor(period == value ? WeatherStyle.Color.selectedPeriod : WeatherStyle.Color.periodText)
                .frame(maxWidth: .infinity, minHeight: WeatherStyle.periodButtonHeight)
                .background(
                    period == value ? JournalStyle.Color.surface : JournalStyle.Color.transparent,
                    in: RoundedRectangle(cornerRadius: WeatherStyle.periodButtonRadius)
                )
                .shadow(
                    color: period == value ? WeatherStyle.Color.periodShadow : JournalStyle.Color.transparent,
                    radius: JournalStyle.Space.tight, y: JournalStyle.Space.hairline)
        }
        .buttonStyle(.plain).accessibilityAddTraits(period == value ? .isSelected : [])
    }

    @ViewBuilder private var hourlyContent: some View {
        let hours = forecast.hours(on: day.date, in: period)
        if hours.isEmpty {
            Text(WeatherText.noHours.value).foregroundColor(JournalStyle.Color.secondary)
        } else if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                HourlyForecastView(hours: hours, minimum: day.low, maximum: day.high)
                    .frame(minWidth: CGFloat(hours.count) * WeatherStyle.accessibleHourWidth)
            }
        } else {
            HourlyForecastView(hours: hours, minimum: day.low, maximum: day.high)
        }
    }

    private func title(_ value: DayPeriod) -> LocalizedText {
        switch value {
        case .night: return WeatherText.night
        case .morning: return WeatherText.morning
        case .afternoon: return WeatherText.afternoon
        case .evening: return WeatherText.evening
        }
    }
}

#if DEBUG
    @MainActor
    private struct DayDetailView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                scene.previewDisplayName("单日详情")
                scene.environment(\.dynamicTypeSize, .accessibility3).previewDisplayName("单日详情 · 大字号")
            }
            .journalPreview()
        }

        private static var scene: some View {
            NavigationView {
                DayDetailView(
                    name: WeatherPreviewData.name, forecast: WeatherPreviewData.forecast,
                    day: WeatherPreviewData.day)
            }
            .navigationViewStyle(.stack)
        }
    }
#endif
