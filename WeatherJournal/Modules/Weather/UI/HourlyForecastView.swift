import SwiftUI

/// 逐小时数据共用当天温度刻度，并把降水信息合并到对应小时的朗读标签。
struct HourlyForecastView: View {
    let hours: [HourlyForecast]
    let minimum: Double?
    let maximum: Double?

    init(hours: [HourlyForecast], minimum: Double? = nil, maximum: Double? = nil) {
        self.hours = hours
        self.minimum = minimum
        self.maximum = maximum
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(hours.indices, id: \.self) { index in hourCell(hours[index]) }
            }
            TemperatureTrend(hours: hours, minimum: minimum, maximum: maximum)
                .frame(height: WeatherStyle.trendHeight)
                .padding(.top, WeatherStyle.trendTop).padding(.bottom, WeatherStyle.trendBottom)
                .accessibilityHidden(true)
            precipitationLabel
            precipitationRow
        }
    }

    private func hourCell(_ hour: HourlyForecast) -> some View {
        let condition = WeatherPresentation.condition(hour.code, daylight: hour.daylight)
        let precipitation = WeatherPresentation.metric(hour.precipitationProbability, unit: WeatherFormat.percent)
        return VStack(spacing: 0) {
            Text(verbatim: hour.time.clock)
                .journalFont(size: WeatherStyle.FontSize.caption, relativeTo: .caption)
                .foregroundColor(WeatherStyle.Color.hourTime)
            WeatherArt(name: condition.art, size: WeatherStyle.hourIcon)
                .padding(.top, WeatherStyle.hourIconTop).padding(.bottom, WeatherStyle.hourIconBottom)
            Text(verbatim: WeatherPresentation.degrees(hour.temperature))
                .journalFont(size: WeatherStyle.FontSize.hourTemperature, weight: .medium, relativeTo: .title3)
        }
        .frame(maxWidth: .infinity).monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                verbatim: WeatherText.hourSummary.format(
                    hour.time.clock, condition.label.string, WeatherPresentation.degrees(hour.temperature),
                    precipitation)))
    }

    private var precipitationLabel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(WeatherStyle.Color.precipitationLine)
            HStack(spacing: JournalStyle.Space.small) {
                WeatherArt(name: WeatherAsset.humidity, size: WeatherStyle.precipitationIcon)
                Text(WeatherText.precipitation.value)
                    .journalFont(size: WeatherStyle.FontSize.caption, relativeTo: .caption)
                    .foregroundColor(JournalStyle.Color.secondary)
            }
            .padding(.top, JournalStyle.Space.row).padding(.bottom, JournalStyle.Space.related)
        }
        .accessibilityHidden(true)
    }

    private var precipitationRow: some View {
        HStack(spacing: 0) {
            ForEach(hours.indices, id: \.self) { index in
                Text(
                    verbatim: WeatherPresentation.metric(
                        hours[index].precipitationProbability, unit: WeatherFormat.percent)
                )
                .journalFont(size: WeatherStyle.FontSize.precipitation, relativeTo: .footnote)
                .foregroundColor(JournalStyle.Color.accent).monospacedDigit()
                .frame(maxWidth: .infinity)
            }
        }
        // 数值已合并到对应小时的朗读标签，避免重复播报。
        .accessibilityHidden(true)
    }
}

private struct TemperatureTrend: View {
    let hours: [HourlyForecast]
    let minimum: Double?
    let maximum: Double?

    var body: some View {
        Canvas { context, size in
            for segment in segments(in: size) { draw(segment, context: context, size: size) }
        }
    }

    private func draw(_ points: [CGPoint], context: GraphicsContext, size: CGSize) {
        guard let first = points.first, let last = points.last else { return }
        var line = Path()
        line.addLines(points)
        if points.count > 1 {
            var area = Path()
            area.move(to: CGPoint(x: first.x, y: size.height))
            for point in points { area.addLine(to: point) }
            area.addLine(to: CGPoint(x: last.x, y: size.height))
            area.closeSubpath()
            context.fill(
                area,
                with: .linearGradient(
                    WeatherStyle.trendGradient, startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(
                line, with: .color(WeatherStyle.Color.trend),
                style: StrokeStyle(lineWidth: WeatherStyle.lineWidth, lineJoin: .round))
        }
        for point in points {
            let circle = Path(
                ellipseIn: CGRect(
                    x: point.x - WeatherStyle.pointRadius,
                    y: point.y - WeatherStyle.pointRadius,
                    width: WeatherStyle.pointRadius * 2, height: WeatherStyle.pointRadius * 2))
            context.fill(circle, with: .color(JournalStyle.Color.surface))
            context.stroke(circle, with: .color(WeatherStyle.Color.trend), lineWidth: JournalStyle.Space.hairline)
        }
    }

    private func segments(in size: CGSize) -> [[CGPoint]] {
        let values = hours.compactMap(\.temperature).filter(\.isFinite)
        guard let measuredLow = values.min(), let measuredHigh = values.max() else { return [] }
        let low = minimum.flatMap { $0.isFinite ? $0 : nil } ?? measuredLow
        let high = maximum.flatMap { $0.isFinite ? $0 : nil } ?? measuredHigh
        var result: [[CGPoint]] = []
        var current: [CGPoint] = []
        for (index, hour) in hours.enumerated() {
            // 缺失指标形成断点，填充区域也分段，不能跨空值连接趋势线。
            guard let value = hour.temperature, value.isFinite else {
                if !current.isEmpty { result.append(current) }
                current = []
                continue
            }
            let fraction = high > low ? min(1, max(0, (value - low) / (high - low))) : Double(WeatherStyle.cellCenter)
            current.append(
                CGPoint(
                    x: (CGFloat(index) + WeatherStyle.cellCenter) * size.width / CGFloat(hours.count),
                    y: size.height - WeatherStyle.trendBottomInset - CGFloat(fraction)
                        * (size.height - WeatherStyle.trendTopInset - WeatherStyle.trendBottomInset)))
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

#if DEBUG
    @MainActor
    private struct HourlyForecastView_Previews: PreviewProvider {
        static var previews: some View {
            HourlyForecastView(
                hours: WeatherPreviewData.hours, minimum: WeatherPreviewData.day.low,
                maximum: WeatherPreviewData.day.high
            )
            .padding(JournalStyle.Space.card).frame(width: JournalPreview.contentWidth)
            .journalPreview().previewLayout(.sizeThatFits).previewDisplayName("逐小时 · 含缺失指标")
        }
    }
#endif
