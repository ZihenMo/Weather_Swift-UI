import SwiftUI

enum JournalStyle {
    enum Color {
        static let transparent = SwiftUI.Color.clear
        static let background = SwiftUI.Color(red: 0.933, green: 0.953, blue: 0.973)
        static let ink = SwiftUI.Color(red: 0.09, green: 0.17, blue: 0.24)
        static let accent = SwiftUI.Color(red: 0.14, green: 0.40, blue: 0.56)
        static let sea = SwiftUI.Color(red: 0.19, green: 0.36, blue: 0.47)
        static let sky = SwiftUI.Color(red: 0.40, green: 0.54, blue: 0.60)
        static let surface = SwiftUI.Color.white
        static let onAccent = SwiftUI.Color.white
        static let secondary = SwiftUI.Color(red: 83 / 255, green: 106 / 255, blue: 121 / 255)
        static let line = SwiftUI.Color(red: 217 / 255, green: 227 / 255, blue: 235 / 255)
        static let search = SwiftUI.Color(red: 224 / 255, green: 232 / 255, blue: 239 / 255)
        static let field = SwiftUI.Color(red: 229 / 255, green: 235 / 255, blue: 240 / 255)
        static let panel = SwiftUI.Color(red: 245 / 255, green: 248 / 255, blue: 251 / 255)
        static let scrim = SwiftUI.Color(red: 22 / 255, green: 43 / 255, blue: 58 / 255).opacity(0.33)
        static let warning = SwiftUI.Color(red: 1, green: 245 / 255, blue: 223 / 255)
        static let secondaryAction = SwiftUI.Color(red: 237 / 255, green: 243 / 255, blue: 247 / 255)
        static let warm = SwiftUI.Color.orange
        static let track = SwiftUI.Color.gray.opacity(0.18)
    }
    enum Font {
        static let title = SwiftUI.Font.largeTitle.weight(.semibold)
        static let section = SwiftUI.Font.title3.weight(.semibold)
        static let metric = SwiftUI.Font.title2.weight(.medium)
        static let headline = SwiftUI.Font.headline
        static let body = SwiftUI.Font.body
        static let callout = SwiftUI.Font.callout
        static let label = SwiftUI.Font.subheadline
        static let note = SwiftUI.Font.footnote
        static let caption = SwiftUI.Font.caption
        static func temperature(size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .light, design: .rounded)
        }
    }
    enum Space {
        static let hairline: CGFloat = 1
        static let tight: CGFloat = 2
        static let compact: CGFloat = 3
        static let small: CGFloat = 4
        static let label: CGFloat = 5
        static let related: CGFloat = 6
        static let item: CGFloat = 8
        static let row: CGFloat = 10
        static let card: CGFloat = 12
        static let section: CGFloat = 14
        static let page: CGFloat = 15
        static let prominent: CGFloat = 20
        static let status: CGFloat = 24
    }
    enum Radius {
        static let status: CGFloat = 16
        static let notice: CGFloat = 12
        static let card: CGFloat = 17
        static let summary: CGFloat = 18
        static let hero: CGFloat = 23
    }
    enum Size {
        static let statusPadding: CGFloat = 45
        static let statusTitle: CGFloat = 22.5
        static let body: CGFloat = 15
        static let caption: CGFloat = 12
        static let touchTarget: CGFloat = 44
        static let rowMinimum: CGFloat = 48
        static let navigationHeight: CGFloat = 61
        static let navigationButton: CGFloat = 40
        static let navigationIcon: CGFloat = 20
        static let pageTitle: CGFloat = 30
        static let sectionTitle: CGFloat = 21
        static let sectionIcon: CGFloat = 18
        static let panelFraction: CGFloat = 0.68
        static let panelMinimumHeight: CGFloat = 480
        static let panelWidth: CGFloat = 370
        static let panelInset: CGFloat = 10
        static let handleWidth: CGFloat = 36
        static let handleHeight: CGFloat = 5
    }
}

enum JournalSymbol {
    static let places = "list.bullet", search = "magnifyingglass", clear = "xmark.circle.fill"
    static let close = "xmark", location = "location.fill", remove = "minus.circle"
    static let forward = "chevron.right", back = "chevron.left", refresh = "arrow.clockwise"
}

enum JournalAsset {
    static let places = "places", back = "back", location = "location", search = "search", remove = "remove"
    static let calendar = "calendar", forward = "chevron"
}

/// 原型提供的线性图标统一作为模板绘制，颜色跟随所属控件。
struct JournalIcon: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Image(name).renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}

extension View {
    func journalAction(primary: Bool = false) -> some View {
        journalFont(size: JournalStyle.Size.body, weight: .medium)
            .foregroundColor(primary ? JournalStyle.Color.onAccent : JournalStyle.Color.accent)
            .padding(.horizontal, JournalStyle.Space.page).padding(.vertical, JournalStyle.Space.row)
            .background(
                primary ? JournalStyle.Color.accent : JournalStyle.Color.secondaryAction,
                in: RoundedRectangle(cornerRadius: JournalStyle.Radius.notice))
    }
    func journalFont(size: CGFloat, weight: SwiftUI.Font.Weight = .regular, relativeTo: SwiftUI.Font.TextStyle = .body)
        -> some View
    {
        modifier(JournalScaledFont(size: size, weight: weight, relativeTo: relativeTo))
    }
    func journalCard() -> some View {
        background(JournalStyle.Color.surface, in: RoundedRectangle(cornerRadius: JournalStyle.Radius.card))
    }
}

private struct JournalScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: SwiftUI.Font.Weight

    init(size: CGFloat, weight: SwiftUI.Font.Weight, relativeTo: SwiftUI.Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
        self.weight = weight
    }

    func body(content: Content) -> some View { content.font(.system(size: size, weight: weight)) }
}

/// 统一视觉层级与无障碍标题语义。
struct SectionHeading: View {
    let title: LocalizedStringKey
    let icon: String?
    init(_ title: LocalizedStringKey, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }
    var body: some View {
        HStack(spacing: JournalStyle.Space.small) {
            if let icon { JournalIcon(name: icon, size: JournalStyle.Size.sectionIcon) }
            Text(title).journalFont(size: JournalStyle.Size.sectionTitle, weight: .semibold, relativeTo: .title3)
        }
        .foregroundColor(JournalStyle.Color.ink)
        .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
    private struct SectionHeading_Previews: PreviewProvider {
        static var previews: some View {
            SectionHeading(CommonText.currentLocation.value, icon: JournalAsset.calendar)
                .padding(JournalStyle.Space.page)
                .journalPreview()
                .previewLayout(.sizeThatFits)
                .previewDisplayName("区块标题")
        }
    }
#endif
