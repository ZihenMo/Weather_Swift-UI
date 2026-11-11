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
        static let secondary = SwiftUI.Color.secondary
        static let warning = SwiftUI.Color.orange.opacity(0.14)
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
        static let page: CGFloat = 16
        static let prominent: CGFloat = 20
        static let status: CGFloat = 24
    }
    enum Radius {
        static let notice: CGFloat = 12
        static let card: CGFloat = 17
        static let summary: CGFloat = 18
        static let hero: CGFloat = 23
    }
    enum Size {
        static let touchTarget: CGFloat = 44
        static let rowMinimum: CGFloat = 48
    }
}

enum JournalSymbol {
    static let places = "list.bullet", search = "magnifyingglass", clear = "xmark.circle.fill"
    static let close = "xmark", location = "location.fill", remove = "minus.circle"
    static let forward = "chevron.right", refresh = "arrow.clockwise"
}

extension View {
    func journalCard() -> some View {
        background(JournalStyle.Color.surface, in: RoundedRectangle(cornerRadius: JournalStyle.Radius.card))
    }
}

/// 统一视觉层级与无障碍标题语义。
struct SectionHeading: View {
    let title: LocalizedStringKey
    init(_ title: LocalizedStringKey) { self.title = title }
    var body: some View {
        Text(title).font(JournalStyle.Font.section).foregroundColor(JournalStyle.Color.ink)
            .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
    }
}
