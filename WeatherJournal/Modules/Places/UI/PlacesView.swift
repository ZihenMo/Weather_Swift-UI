import SwiftUI

/// 收藏列表观察仓库的长期状态，编辑模式与删除动作归页面所有。
struct PlacesView: View {
    @ObservedObject var repository: PlacesRepository
    @State private var editing = false
    @State private var removing = false

    let search: () -> Void
    let select: (Place?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: JournalStyle.Space.section) {
                searchButton
                PlacesPersistenceNotice(repository: repository, allowsRebuild: true)
                currentLocationButton
                SectionHeading(PlacesText.saved.value)
                savedContent
            }
            .padding(JournalStyle.Space.page)
        }
        .background(JournalStyle.Color.background.ignoresSafeArea())
        .navigationTitle(PlacesText.title.value)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { editButton } }
        .onChange(of: repository.saved.isEmpty) { empty in if empty { editing = false } }
    }

    private var searchButton: some View {
        Button(action: search) {
            Label(PlacesText.search.value, systemImage: JournalSymbol.search)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(JournalStyle.Space.card)
        }
        .buttonStyle(.plain)
        .journalCard()
        .accessibilityIdentifier(PlacesIdentifier.search)
    }

    private var currentLocationButton: some View {
        Button {
            select(nil)
        } label: {
            Label(CommonText.currentLocation.value, systemImage: JournalSymbol.location)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(JournalStyle.Space.section)
        }
        .buttonStyle(.plain)
        .journalCard()
        .accessibilityIdentifier(PlacesIdentifier.device)
    }

    @ViewBuilder private var savedContent: some View {
        if repository.saved.isEmpty {
            Text(PlacesText.empty.value)
                .foregroundColor(JournalStyle.Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(JournalStyle.Space.prominent)
                .journalCard()
        } else {
            VStack(spacing: 0) {
                ForEach(repository.saved) { place in
                    savedRow(place)
                    if place.id != repository.saved.last?.id { Divider() }
                }
            }
            .padding(.horizontal, JournalStyle.Space.card)
            .journalCard()
        }
    }

    private func savedRow(_ place: Place) -> some View {
        HStack {
            Button {
                select(place)
            } label: {
                PlaceRow(place: place, showsChevron: !editing)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(PlacesIdentifier.saved(place.id))
            if editing { removeButton(place) }
        }
    }

    private func removeButton(_ place: Place) -> some View {
        Button(role: .destructive) {
            remove(place)
        } label: {
            Image(systemName: JournalSymbol.remove)
                .frame(width: JournalStyle.Size.touchTarget, height: JournalStyle.Size.touchTarget)
                .accessibilityLabel(Text(verbatim: PlacesText.removeNamed.format(place.name)))
        }
        .disabled(removing)
        .accessibilityIdentifier(PlacesIdentifier.remove(place.id))
    }

    @ViewBuilder private var editButton: some View {
        if !repository.saved.isEmpty {
            Button {
                editing.toggle()
            } label: {
                if editing { Text(PlacesText.done.value) } else { Text(PlacesText.edit.value) }
            }
        }
    }

    private func remove(_ place: Place) {
        removing = true
        Task {
            _ = await repository.remove(place.id)
            removing = false
        }
    }
}

/// 搜索候选和收藏列表共用的地点摘要，不持有导航状态。
struct PlaceRow: View {
    let place: Place
    var showsChevron = true

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: JournalStyle.Space.compact) {
                Text(verbatim: place.name).font(JournalStyle.Font.headline)
                if !place.region.isEmpty {
                    Text(verbatim: place.region)
                        .font(JournalStyle.Font.caption)
                        .foregroundColor(JournalStyle.Color.secondary)
                }
            }
            Spacer(minLength: JournalStyle.Space.item)
            if showsChevron {
                Image(systemName: JournalSymbol.forward)
                    .font(JournalStyle.Font.caption)
                    .foregroundColor(JournalStyle.Color.secondary)
            }
        }
        .padding(.vertical, JournalStyle.Space.row)
        .frame(minHeight: JournalStyle.Size.rowMinimum)
        .contentShape(Rectangle())
    }
}

#if DEBUG
    @MainActor
    private struct PlacesView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                scene(.ready).previewDisplayName("地点列表")
                scene(.empty).previewDisplayName("地点列表 · 空态")
                PlaceRow(place: PlacesPreviewData.city)
                    .padding(JournalStyle.Space.page).previewLayout(.sizeThatFits).previewDisplayName("地点摘要")
            }
            .journalPreview()
        }

        private static func scene(_ scenario: PlacesPreviewData.Scenario) -> some View {
            PlacesPreviewScene(scenario) { repository in
                NavigationView { PlacesView(repository: repository, search: {}, select: { _ in }) }
                    .navigationViewStyle(.stack)
            }
        }
    }
#endif
