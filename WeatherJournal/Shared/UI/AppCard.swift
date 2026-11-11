import SwiftUI

/// 普通卡片只统一表面和圆角，业务内容负责自己的布局。
struct AppCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content().background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}

#if DEBUG
    private struct AppCard_Previews: PreviewProvider {
        static var previews: some View {
            AppCard {
                Text(CommonText.currentLocation.value).appFont(.medium).padding(AppSpacing.large)
            }
            .padding(AppSpacing.large).background(AppColor.background)
            .journalPreview().previewLayout(.sizeThatFits).previewDisplayName("通用卡片")
        }
    }
#endif
