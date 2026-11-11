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
                .frame(height: 44)
                .padding(.top, AppSpacing.xSmall).padding(.bottom, AppSpacing.medium)
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
                .appFont(.caption)
                .foregroundColor(AppColor.textSecondary)
            WeatherArt(name: condition.art, size: 28)
                .padding(.top, AppSpacing.small).padding(.bottom, AppSpacing.xSmall)
            Text(verbatim: WeatherPresentation.degrees(hour.temperature))
                .appFont(.large, weight: .medium)
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
            Divider().overlay(AppColor.border)
            HStack(spacing: AppSpacing.xSmall) {
                WeatherArt(name: WeatherAsset.humidity, size: 16)
                Text(WeatherText.precipitation.value)
                    .appFont(.caption)
                    .foregroundColor(AppColor.textSecondary)
            }
            .padding(.top, AppSpacing.medium).padding(.bottom, AppSpacing.small)
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
                .appFont(.small)
                .foregroundColor(AppColor.accent).monospacedDigit()
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
        let lineColor = Color(red: 91 / 255, green: 144 / 255, blue: 170 / 255)
        let fillColor = Color(red: 146 / 255, green: 184 / 255, blue: 206 / 255)
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
                    Gradient(colors: [fillColor.opacity(0.48), fillColor.opacity(0.03)]), startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(
                line, with: .color(lineColor),
                style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
        for point in points {
            let circle = Path(
                ellipseIn: CGRect(
                    x: point.x - 2.5,
                    y: point.y - 2.5,
                    width: 2.5 * 2, height: 2.5 * 2))
            context.fill(circle, with: .color(AppColor.surface))
            context.stroke(circle, with: .color(lineColor), lineWidth: 1)
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
            let fraction = high > low ? min(1, max(0, (value - low) / (high - low))) : Double(0.5)
            current.append(
                CGPoint(
                    x: (CGFloat(index) + 0.5) * size.width / CGFloat(hours.count),
                    y: size.height - 8 - CGFloat(fraction)
                        * (size.height - 8 - 8)))
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
            .padding(AppSpacing.medium).frame(width: JournalPreview.contentWidth)
            .journalPreview().previewLayout(.sizeThatFits).previewDisplayName("逐小时 · 含缺失指标")
        }
    }
#endif
