import SwiftUI

/// 单一导航栈内的底部浮层，保留底层搜索状态并兼容 iOS 15。
struct JournalPanel<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    let close: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                JournalStyle.Color.scrim.ignoresSafeArea()
                    .onTapGesture(perform: close)
                    .accessibilityHidden(true)
                panel
                    .frame(maxWidth: JournalStyle.Size.panelWidth)
                    .frame(maxHeight: maximumHeight(in: geometry), alignment: .top)
                    .background(JournalStyle.Color.panel, in: RoundedRectangle(cornerRadius: JournalStyle.Radius.hero))
                    .padding(.horizontal, JournalStyle.Size.panelInset)
                    .padding(.bottom, JournalStyle.Space.item)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
    }

    private var panel: some View {
        VStack(spacing: JournalStyle.Space.item) {
            Capsule().fill(JournalStyle.Color.line)
                .frame(width: JournalStyle.Size.handleWidth, height: JournalStyle.Size.handleHeight)
                .accessibilityHidden(true)
            content()
        }
        .padding(.top, JournalStyle.Space.card)
        .clipShape(RoundedRectangle(cornerRadius: JournalStyle.Radius.hero))
    }

    private func maximumHeight(in geometry: GeometryProxy) -> CGFloat {
        // 辅助功能字号与键盘同时出现时允许浮层使用全部可用高度。
        if typeSize.isAccessibilitySize { return geometry.size.height }
        return min(
            geometry.size.height,
            max(
                JournalStyle.Size.panelMinimumHeight,
                geometry.size.height * JournalStyle.Size.panelFraction))
    }
}

#if DEBUG
    private struct JournalPanel_Previews: PreviewProvider {
        static var previews: some View {
            JournalPanel(close: {}) {
                Text(CommonText.choosePlace.value).padding(JournalStyle.Space.prominent)
            }
            .journalPreview()
            .previewDisplayName("底部浮层")
        }
    }
#endif
