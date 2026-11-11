#if DEBUG
    import SwiftUI

    enum JournalPreview { static let contentWidth: CGFloat = 360 }

    extension View {
        /// 固定预览语言与主题，拦截外链，保证画布交互不打开外部服务。
        func journalPreview() -> some View {
            environment(\.locale, Locale(identifier: JournalLocalization.fallbackLanguage))
                .environment(\.openURL, OpenURLAction { _ in .handled })
                .preferredColorScheme(.light)
        }
    }
#endif
