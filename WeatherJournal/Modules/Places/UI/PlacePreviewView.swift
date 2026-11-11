import SwiftUI

/// 地区概览呈现关闭与收藏动作，天气内容由 App 注入，关闭后保留搜索状态。
struct PlacePreviewView<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var repository: PlacesRepository
    @State private var adding = false
    @State private var availableWidth: CGFloat = 0

    let place: Place
    let close: () -> Void
    let added: (PlacesRepository.SaveResult) -> Void
    var savingChanged: (Bool) -> Void = { _ in }
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            heading
                .padding(.horizontal, AppSpacing.large)
            content()
        }
        .background(AppColor.surfaceRaised)
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { availableWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { availableWidth = $0 }
            }
        }
    }

    @ViewBuilder private var heading: some View {
        if usesStackedHeading {
            VStack(spacing: AppSpacing.xSmall) {
                title
                actions
            }
        } else {
            HStack(spacing: AppSpacing.small) {
                closeButton.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                title.lineLimit(1).minimumScaleFactor(0.8)
                    .layoutPriority(-1)
                    .frame(minWidth: 0, maxWidth: .infinity)
                addButton.frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var title: some View {
        Text(PlacesText.preview.value)
            .appFont(.large, weight: .semibold)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    private var usesStackedHeading: Bool {
        dynamicTypeSize >= .xxLarge || availableWidth < 350
    }

    private var actions: some View {
        HStack {
            closeButton
            Spacer(minLength: AppSpacing.small)
            addButton
        }
    }

    private var closeButton: some View {
        Button(CommonText.close.value, action: close)
            .buttonStyle(AppButtonStyle(.plain))
            .fixedSize(horizontal: true, vertical: true)
            .disabled(adding)
            .accessibilityIdentifier(PlacesIdentifier.closePreview)
    }

    private var addButton: some View {
        Button(action: add) {
            Text(isSaved ? PlacesText.added.value : PlacesText.add.value)
        }
        .buttonStyle(AppButtonStyle(.primary))
        .fixedSize(horizontal: true, vertical: true)
        .disabled(adding || isSaved)
        .accessibilityIdentifier(PlacesIdentifier.add)
    }

    private var isSaved: Bool { repository.saved.contains { $0.id == place.id } }

    private func add() {
        adding = true
        savingChanged(true)
        Task {
            let result = await repository.add(place)
            adding = false
            savingChanged(false)
            if result != .alreadySaved { added(result) }
        }
    }
}

#if DEBUG
    @MainActor
    private struct PlacePreviewView_Previews: PreviewProvider {
        static var previews: some View {
            PlacesPreviewScene { repository in
                PlacePreviewView(
                    repository: repository, place: PlacesPreviewData.candidate, close: {}, added: { _ in }
                ) {
                    PlaceRow(place: PlacesPreviewData.candidate, showsChevron: false).padding(AppSpacing.large)
                }
            }
            .previewDisplayName("候选概览 · 标题与收藏")
        }
    }
#endif
