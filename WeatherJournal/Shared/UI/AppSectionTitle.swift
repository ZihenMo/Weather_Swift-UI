import SwiftUI

/// 共用区块标题与可访问性语义。
struct AppSectionTitle: View {
    let title: LocalizedStringKey
    let icon: AppIcon.Name?

    init(_ title: LocalizedStringKey, icon: AppIcon.Name? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            if let icon { AppIcon(name: icon) }
            Text(title).appFont(.title, weight: .semibold)
        }
        .foregroundColor(AppColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
    private struct AppSectionTitle_Previews: PreviewProvider {
        static var previews: some View {
            AppSectionTitle(CommonText.currentLocation.value, icon: .location)
                .padding(AppSpacing.large).journalPreview().previewLayout(.sizeThatFits)
                .previewDisplayName("共用区块标题")
        }
    }
#endif
