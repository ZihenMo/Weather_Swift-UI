import SwiftUI

/// 只读的小时天气区域，通过列位置和完整朗读标签表达同一时段的数据。
struct HourlyForecastView: View {
    let hours: [HourlyForecast]

    var body: some View {
        VStack(spacing: JournalStyle.Space.section) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(hours.indices, id: \.self) { index in hourCell(hours[index]) }
            }
            TemperatureTrend(hours: hours)
                .frame(height: WeatherStyle.trendHeight)
                .accessibilityHidden(true)
            Text(WeatherText.precipitation.value)
                .font(JournalStyle.Font.caption)
                .foregroundColor(JournalStyle.Color.secondary)
                .accessibilityHidden(true)
            precipitationRow
        }
    }

    private func hourCell(_ hour: HourlyForecast) -> some View {
        let condition = WeatherPresentation.condition(hour.code, daylight: hour.daylight)
        let precipitation = WeatherPresentation.metric(hour.precipitationProbability, unit: WeatherFormat.percent)
        return VStack(spacing: JournalStyle.Space.related) {
            Text(verbatim: hour.time.clock).font(JournalStyle.Font.caption)
            WeatherArt(name: condition.art, size: WeatherStyle.conditionIcon)
            Text(verbatim: WeatherPresentation.degrees(hour.temperature))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                verbatim: WeatherText.hourSummary.format(
                    hour.time.clock, condition.label.string, WeatherPresentation.degrees(hour.temperature),
                    precipitation)))
    }

    private var precipitationRow: some View {
        HStack(spacing: 0) {
            ForEach(hours.indices, id: \.self) { index in
                Text(
                    verbatim: WeatherPresentation.metric(
                        hours[index].precipitationProbability, unit: WeatherFormat.percent)
                )
                .font(JournalStyle.Font.note)
                .frame(maxWidth: .infinity)
            }
        }
        // 该数值已合并到对应小时的朗读标签，避免重复播报。
        .accessibilityHidden(true)
    }
}

private struct TemperatureTrend: View {
    let hours: [HourlyForecast]
    var body: some View {
        Canvas { context, size in
            let values = hours.compactMap(\.temperature)
            guard let low = values.min(), let high = values.max() else { return }
            var line = Path()
            var points = Path()
            var connected = false
            for (index, hour) in hours.enumerated() {
                // 缺失指标形成断点，不能跨越空值连接趋势线。
                guard let value = hour.temperature else {
                    connected = false
                    continue
                }
                let fraction = high == low ? Double(WeatherStyle.cellCenter) : (value - low) / (high - low)
                let point = CGPoint(
                    x: (CGFloat(index) + WeatherStyle.cellCenter) * size.width / CGFloat(hours.count),
                    y: size.height - WeatherStyle.trendInset - CGFloat(fraction)
                        * (size.height - WeatherStyle.trendInset * 2))
                if connected { line.addLine(to: point) } else { line.move(to: point) }
                points.addEllipse(
                    in: CGRect(
                        x: point.x - WeatherStyle.pointRadius, y: point.y - WeatherStyle.pointRadius,
                        width: WeatherStyle.pointRadius * 2, height: WeatherStyle.pointRadius * 2))
                connected = true
            }
            context.stroke(line, with: .color(JournalStyle.Color.accent), lineWidth: WeatherStyle.lineWidth)
            context.fill(points, with: .color(JournalStyle.Color.accent))
        }
    }
}

#if DEBUG
    @MainActor
    private struct HourlyForecastView_Previews: PreviewProvider {
        static var previews: some View {
            HourlyForecastView(hours: WeatherPreviewData.hours)
                .padding(JournalStyle.Space.card)
                .frame(width: JournalPreview.contentWidth)
                .journalPreview()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("逐小时 · 含缺失指标")
        }
    }
#endif
