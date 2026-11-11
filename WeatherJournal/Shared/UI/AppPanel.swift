import SwiftUI

/// 单一导航栈内的底部浮层，保留底层搜索状态并兼容 iOS 15。
struct AppPanel<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    let close: () -> Void
    let allowsDismiss: Bool
    @ViewBuilder let content: () -> Content

    init(close: @escaping () -> Void, allowsDismiss: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.close = close
        self.allowsDismiss = allowsDismiss
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                AppColor.scrim.ignoresSafeArea()
                    .onTapGesture(perform: dismiss)
                    .accessibilityHidden(true)
                panel
                    .frame(maxWidth: 370)
                    .frame(maxHeight: maximumHeight(in: geometry), alignment: .top)
                    .background(AppColor.surfaceRaised, in: RoundedRectangle(cornerRadius: AppRadius.large))
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.bottom, AppSpacing.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
    }

    private var panel: some View {
        VStack(spacing: AppSpacing.small) {
            Capsule().fill(AppColor.border)
                .frame(width: 36, height: 4)
                .accessibilityHidden(true)
            content()
        }
        .padding(.top, AppSpacing.medium)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
    }

    private func dismiss() { if allowsDismiss { close() } }

    private func maximumHeight(in geometry: GeometryProxy) -> CGFloat {
        // 辅助功能字号与键盘同时出现时允许浮层使用全部可用高度。
        if typeSize.isAccessibilitySize { return geometry.size.height }
        return min(
            geometry.size.height,
            max(
                480,
                geometry.size.height * 0.68))
    }
}

#if DEBUG
    private struct AppPanel_Previews: PreviewProvider {
        static var previews: some View {
            AppPanel(close: {}) {
                Text(CommonText.choosePlace.value).appFont(.medium).padding(AppSpacing.large)
            }
            .journalPreview()
            .previewDisplayName("底部浮层")
        }
    }
#endif
