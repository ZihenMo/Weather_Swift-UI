import SwiftUI

/// 地区概览呈现关闭与收藏动作，天气内容由 App 注入，关闭后保留搜索状态。
struct PlacePreviewView<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var repository: PlacesRepository
    @State private var adding = false

    let place: Place
    let close: () -> Void
    let added: (PlacesRepository.SaveResult) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: JournalStyle.Space.card) {
            heading
                .padding(.horizontal, PlacesStyle.panelInset)
            content()
        }
        .background(JournalStyle.Color.panel)
    }

    @ViewBuilder private var heading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: JournalStyle.Space.small) {
                title
                actions
            }
        } else {
            ZStack {
                title
                actions
            }
        }
    }

    private var title: some View {
        Text(PlacesText.preview.value)
            .journalFont(size: PlacesStyle.previewTitleSize, weight: .semibold)
            .accessibilityAddTraits(.isHeader)
    }

    private var actions: some View {
        HStack {
            closeButton
            Spacer(minLength: JournalStyle.Space.item)
            addButton
        }
    }

    private var closeButton: some View {
        Button(CommonText.close.value, action: close)
            .journalFont(size: PlacesStyle.actionSize)
            .foregroundColor(JournalStyle.Color.accent)
            .frame(minHeight: JournalStyle.Size.touchTarget)
            .disabled(adding)
            .accessibilityIdentifier(PlacesIdentifier.closePreview)
    }

    private var addButton: some View {
        Button(action: add) {
            Text(isSaved ? PlacesText.added.value : PlacesText.add.value)
                .journalFont(size: PlacesStyle.bodySize, weight: .semibold)
                .foregroundColor(isSaved || adding ? JournalStyle.Color.secondary : JournalStyle.Color.onAccent)
                .padding(.horizontal, PlacesStyle.addHorizontalInset)
                .padding(.vertical, PlacesStyle.addVerticalInset)
                .background(
                    isSaved || adding ? JournalStyle.Color.search : JournalStyle.Color.accent,
                    in: RoundedRectangle(cornerRadius: PlacesStyle.addRadius)
                )
                .frame(minHeight: JournalStyle.Size.touchTarget)
        }
        .disabled(adding || isSaved)
        .accessibilityIdentifier(PlacesIdentifier.add)
    }

    private var isSaved: Bool { repository.saved.contains { $0.id == place.id } }

    private func add() {
        adding = true
        Task {
            let result = await repository.add(place)
            adding = false
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
                    PlaceRow(place: PlacesPreviewData.candidate, showsChevron: false).padding(JournalStyle.Space.page)
                }
            }
            .previewDisplayName("候选概览 · 标题与收藏")
        }
    }
#endif
