import SwiftUI

/// 跨模块的提示容器只接收文案和操作，不持有恢复、搜索或天气状态。
struct AppNotice<Actions: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    let message: LocalizedStringKey
    @ViewBuilder let actions: () -> Actions

    init(_ message: LocalizedStringKey, @ViewBuilder actions: @escaping () -> Actions) {
        self.message = message
        self.actions = actions
    }

    var body: some View {
        layout
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.warningBackground, in: RoundedRectangle(cornerRadius: AppRadius.medium))
            .buttonStyle(AppButtonStyle(.plain))
    }

    @ViewBuilder private var layout: some View {
        if typeSize >= .xxLarge {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                text
                actions()
            }
        } else {
            HStack(spacing: AppSpacing.small) {
                text
                actions()
            }
        }
    }

    private var text: some View {
        Text(message).appFont(.small).foregroundColor(AppColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension AppNotice where Actions == EmptyView {
    init(_ message: LocalizedStringKey) { self.init(message) { EmptyView() } }
}

#if DEBUG
    private struct AppNotice_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                sample.previewDisplayName("通用提示")
                sample.environment(\.dynamicTypeSize, .accessibility3).previewDisplayName("通用提示 · 大字号")
            }
            .padding(AppSpacing.large).frame(width: JournalPreview.contentWidth)
            .journalPreview().previewLayout(.sizeThatFits)
        }

        private static var sample: some View {
            AppNotice(CommonText.startupFailure.value) { Button(CommonText.retry.value) {} }
        }
    }
#endif
