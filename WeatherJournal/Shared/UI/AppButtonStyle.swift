import SwiftUI

/// 按操作层级统一按钮表现，禁用和按压状态无需页面重复配置。
struct AppButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, plain }

    @Environment(\.isEnabled) private var isEnabled

    let kind: Kind

    init(_ kind: Kind) { self.kind = kind }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(kind == .plain ? .small : .medium, weight: kind == .plain ? .regular : .medium)
            .foregroundColor(foreground)
            .padding(.horizontal, kind == .plain ? AppSpacing.small : AppSpacing.large)
            .padding(.vertical, kind == .plain ? AppSpacing.xSmall : AppSpacing.small)
            .frame(minWidth: 44, minHeight: 44)
            .background(background, in: RoundedRectangle(cornerRadius: AppRadius.small))
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.65 : 1)
    }

    private var foreground: Color {
        if !isEnabled { return AppColor.textSecondary }
        return kind == .primary ? AppColor.textOnAccent : AppColor.accent
    }

    private var background: Color {
        if kind == .plain { return .clear }
        return kind == .primary && isEnabled ? AppColor.accent : AppColor.fill
    }
}

#if DEBUG
    private struct AppButtonStyle_Previews: PreviewProvider {
        static var previews: some View {
            VStack(spacing: AppSpacing.medium) {
                Button(CommonText.choosePlace.value) {}.buttonStyle(AppButtonStyle(.primary))
                Button(CommonText.retry.value) {}.buttonStyle(AppButtonStyle(.secondary))
                Button(CommonText.close.value) {}.buttonStyle(AppButtonStyle(.plain))
                Button(CommonText.choosePlace.value) {}.buttonStyle(AppButtonStyle(.primary)).disabled(true)
            }
            .padding(AppSpacing.large).journalPreview().previewLayout(.sizeThatFits)
            .previewDisplayName("通用按钮与禁用状态")
        }
    }
#endif
