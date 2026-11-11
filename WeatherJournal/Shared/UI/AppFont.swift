import SwiftUI

/// 两个业务模块共用的字号层级，缩放规则由入口统一处理。
enum AppFont: CGFloat, CaseIterable {
    case caption = 12
    case small = 14
    case medium = 16
    case large = 18
    case title = 22
    case pageTitle = 30

    fileprivate var textStyle: Font.TextStyle {
        switch self {
        case .caption: return .caption
        case .small: return .footnote
        case .medium: return .body
        case .large: return .headline
        case .title: return .title2
        case .pageTitle: return .largeTitle
        }
    }
}

extension View {
    func appFont(_ font: AppFont, weight: Font.Weight = .regular) -> some View {
        modifier(AppFontModifier(font: font, weight: weight))
    }
}

private struct AppFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat

    let weight: Font.Weight

    init(font: AppFont, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: font.rawValue, relativeTo: font.textStyle)
        self.weight = weight
    }

    func body(content: Content) -> some View { content.font(.system(size: size, weight: weight)) }
}

#if DEBUG
    private struct AppFont_Previews: PreviewProvider {
        static var previews: some View {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                ForEach(AppFont.allCases, id: \.self) { font in
                    Text(CommonText.currentLocation.value).appFont(font)
                }
            }
            .padding(AppSpacing.large).journalPreview().previewLayout(.sizeThatFits)
            .previewDisplayName("共用字体层级")
        }
    }
#endif
