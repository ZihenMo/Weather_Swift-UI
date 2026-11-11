import SwiftUI

/// 单日详情持有进入时的预报快照，切换时段只筛选本地数据。
struct DayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var period: DayPeriod
    @State private var availableWidth: CGFloat = 0
    @ScaledMetric(relativeTo: .title2) private var extremeSize: CGFloat = 24

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
                navigationHeader.padding(.bottom, AppSpacing.small)
                dailySummary
                AppSectionTitle(WeatherText.hourly.value)
                    .padding(.top, AppSpacing.large).padding(.bottom, AppSpacing.small)

                hourlySection
            }
            .background {
                GeometryReader { geometry in
                    Color.clear.onAppear { availableWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { availableWidth = $0 }
                }
            }
            .padding(.horizontal, AppSpacing.large).padding(.bottom, AppSpacing.large)
        }
        .background(AppColor.background.ignoresSafeArea()).navigationBarHidden(true)
    }

    @ViewBuilder private var navigationHeader: some View {
        if dynamicTypeSize >= .xxLarge || availableWidth < 330 {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                backButton
                navigationTitle.frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: AppSpacing.small) {
                backButton.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                navigationTitle.lineLimit(1).minimumScaleFactor(0.8)
                    .layoutPriority(-1)
                    .frame(minWidth: 0, maxWidth: .infinity)
                Color.clear.frame(minWidth: 0, maxWidth: .infinity)
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
            .frame(minHeight: 56)
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: AppSpacing.xSmall) {
                AppIcon(name: .back, size: .small)
                Text(WeatherText.title.value)
            }
            .appFont(.medium)
            .foregroundColor(AppColor.accent)
            .frame(minWidth: 44, minHeight: 44)
            .fixedSize(horizontal: true, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var navigationTitle: some View {
        VStack(spacing: AppSpacing.xSmall) {
            Text(verbatim: name)
                .appFont(.large, weight: .semibold)
            Text(verbatim: WeatherPresentation.date(day.date, locale: locale))
                .appFont(.caption)
                .foregroundColor(AppColor.textSecondary)
        }
        .multilineTextAlignment(.center).accessibilityElement(children: .combine)
    }

    private var dailySummary: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize || availableWidth < 318 {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    conditionLabel
                    extremes
                }
            } else {
                HStack {
                    conditionLabel
                    Spacer(minLength: AppSpacing.small)
                    extremes
                }
            }
        }
        .foregroundColor(AppColor.textOnAccent)
        .padding(.vertical, AppSpacing.large).padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(summaryGradient, in: RoundedRectangle(cornerRadius: AppRadius.large))
    }

    private var conditionLabel: some View {
        let condition = WeatherPresentation.condition(day.code, daylight: .day)
        return HStack(spacing: AppSpacing.small) {
            WeatherArt(name: condition.art, size: 36)
            Text(condition.label.value)
                .appFont(.large, weight: .semibold)
        }
    }

    private var extremes: some View {
        HStack(spacing: AppSpacing.large) {
            extreme(WeatherText.low, day.low)
            extreme(WeatherText.high, day.high)
        }
    }

    private func extreme(_ title: LocalizedText, _ temperature: Double?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.value).appFont(.caption)
                .foregroundColor(AppColor.textOnAccent)
            Text(verbatim: WeatherPresentation.degrees(temperature))
                .font(.system(size: extremeSize, weight: .medium))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 49 / 255, green: 91 / 255, blue: 120 / 255),
                Color(red: 102 / 255, green: 137 / 255, blue: 154 / 255),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var hourlySection: some View {
        AppCard {
            VStack(spacing: 0) {
                periodSelection.padding(.bottom, AppSpacing.large)
                hourlyContent
            }
            .monospacedDigit()
            .padding(.horizontal, AppSpacing.small)
            .padding(.top, AppSpacing.medium).padding(.bottom, AppSpacing.large)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColor.border, lineWidth: 1)
        )
    }

    @ViewBuilder private var periodSelection: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker(WeatherText.period.value, selection: $period) {
                ForEach(DayPeriod.allCases, id: \.self) { value in Text(title(value).value).tag(value) }
            }
            .pickerStyle(.menu)
        } else {
            HStack(spacing: AppSpacing.xSmall) {
                ForEach(DayPeriod.allCases, id: \.self) { periodButton($0) }
            }
            .padding(AppSpacing.xSmall)
            .background(
                AppColor.fill,
                in: RoundedRectangle(cornerRadius: AppRadius.small)
            )
            .accessibilityElement(children: .contain).accessibilityLabel(Text(WeatherText.period.value))
        }
    }

    private func periodButton(_ value: DayPeriod) -> some View {
        Button {
            period = value
        } label: {
            Text(title(value).value)
                .appFont(
                    .small, weight: period == value ? .semibold : .regular
                )
                .foregroundColor(period == value ? AppColor.accent : AppColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    period == value ? AppColor.surface : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .buttonStyle(.plain).accessibilityAddTraits(period == value ? .isSelected : [])
    }

    @ViewBuilder private var hourlyContent: some View {
        let hours = forecast.hours(on: day.date, in: period)
        if hours.isEmpty {
            Text(WeatherText.noHours.value).foregroundColor(AppColor.textSecondary)
        } else if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                HourlyForecastView(hours: hours, minimum: day.low, maximum: day.high)
                    .frame(minWidth: CGFloat(hours.count) * 100)
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
