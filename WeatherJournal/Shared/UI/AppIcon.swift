import SwiftUI

/// 通用线性图标使用有限尺寸档位，点击区域由所属控件提供。
struct AppIcon: View {
    enum Name: String {
        case places, back, location, search, remove, calendar
        case forward = "chevron"
    }
    enum Size: CGFloat {
        case small = 16
        case regular = 20
    }

    let name: Name
    let size: Size

    init(name: Name, size: Size = .regular) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image(name.rawValue).renderingMode(.template).resizable().scaledToFit()
            .frame(width: size.rawValue, height: size.rawValue).accessibilityHidden(true)
    }
}

enum AppSymbol { static let clear = "xmark.circle.fill" }

#if DEBUG
    private struct AppIcon_Previews: PreviewProvider {
        static var previews: some View {
            HStack(spacing: AppSpacing.large) {
                AppIcon(name: .back, size: .small)
                AppIcon(name: .places)
                AppIcon(name: .search)
            }
            .foregroundColor(AppColor.accent).padding(AppSpacing.large)
            .journalPreview().previewLayout(.sizeThatFits).previewDisplayName("通用图标")
        }
    }
#endif
