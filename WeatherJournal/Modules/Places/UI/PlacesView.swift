import SwiftUI

/// 收藏列表观察仓库的长期状态，选择与定位摘要由 App 注入，编辑状态归页面所有。
struct PlacesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var repository: PlacesRepository
    @State private var editing = false
    @State private var removing = false

    let search: () -> Void
    let select: (Place?) -> Void
    let selectedPlaceID: Int?
    let isDeviceSelected: Bool
    let deviceName: String?
    let deviceStatus: String?

    init(
        repository: PlacesRepository, search: @escaping () -> Void, select: @escaping (Place?) -> Void,
        selectedPlaceID: Int? = nil, isDeviceSelected: Bool = true, deviceName: String? = nil,
        deviceStatus: String? = nil
    ) {
        self.repository = repository
        self.search = search
        self.select = select
        self.selectedPlaceID = selectedPlaceID
        self.isDeviceSelected = isDeviceSelected
        self.deviceName = deviceName
        self.deviceStatus = deviceStatus
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heading
                searchButton
                PlacesPersistenceNotice(repository: repository, allowsRebuild: true)
                Text(PlacesText.location.value)
                    .journalFont(size: PlacesStyle.noteSize, relativeTo: .caption)
                    .foregroundColor(JournalStyle.Color.secondary)
                currentLocationButton
                savedHeading
                savedContent
            }
            .padding(.horizontal, JournalStyle.Space.page)
            .padding(.bottom, JournalStyle.Space.page)
        }
        .background(JournalStyle.Color.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onChange(of: repository.saved.isEmpty) { empty in if empty { editing = false } }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                dismiss()
            } label: {
                Label {
                    Text(PlacesText.backToWeather.value)
                } icon: {
                    JournalIcon(name: JournalAsset.back, size: PlacesStyle.backSize)
                }
                .journalFont(size: PlacesStyle.backSize)
                .frame(minHeight: PlacesStyle.backHeight)
            }
            .foregroundColor(JournalStyle.Color.accent)
            Text(PlacesText.title.value)
                .journalFont(size: PlacesStyle.titleSize, weight: .bold, relativeTo: .largeTitle)
                .frame(minHeight: PlacesStyle.titleHeight, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var searchButton: some View {
        Button(action: search) {
            Label {
                Text(PlacesText.query.value)
            } icon: {
                JournalIcon(name: JournalAsset.search, size: PlacesStyle.iconSize)
            }
            .journalFont(size: PlacesStyle.bodySize)
            .foregroundColor(JournalStyle.Color.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(JournalStyle.Space.card)
            .background(JournalStyle.Color.search, in: RoundedRectangle(cornerRadius: PlacesStyle.searchRadius))
        }
        .buttonStyle(.plain)
        .padding(.top, JournalStyle.Space.related)
        .padding(.bottom, PlacesStyle.searchBottom)
        .accessibilityIdentifier(PlacesIdentifier.search)
    }

    private var currentLocationButton: some View {
        Button {
            select(nil)
        } label: {
            HStack(spacing: JournalStyle.Space.small) {
                JournalIcon(name: JournalAsset.location, size: PlacesStyle.iconSize)
                Text(verbatim: deviceName ?? CommonText.currentLocation.string)
                    .journalFont(size: PlacesStyle.bodySize, weight: isDeviceSelected ? .semibold : .regular)
                Spacer(minLength: JournalStyle.Space.small)
                Text(verbatim: deviceStatus ?? (deviceName == nil ? "" : CommonText.currentLocation.string))
                    .journalFont(size: PlacesStyle.noteSize, relativeTo: .caption)
                    .foregroundColor(JournalStyle.Color.secondary)
            }
            .foregroundColor(isDeviceSelected ? JournalStyle.Color.accent : JournalStyle.Color.ink)
            .frame(minHeight: PlacesStyle.rowHeight)
            .padding(.horizontal, PlacesStyle.rowInset)
            .padding(.vertical, JournalStyle.Space.tight)
            .background(JournalStyle.Color.surface, in: RoundedRectangle(cornerRadius: PlacesStyle.groupRadius))
        }
        .buttonStyle(.plain)
        .padding(.top, PlacesStyle.groupTop)
        .padding(.bottom, PlacesStyle.groupBottom)
        .accessibilityIdentifier(PlacesIdentifier.device)
    }

    private var savedHeading: some View {
        HStack {
            Text(PlacesText.saved.value)
                .journalFont(size: PlacesStyle.sectionSize, weight: .semibold)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: JournalStyle.Space.item)
            editButton
        }
    }

    @ViewBuilder private var savedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if repository.saved.isEmpty {
                Text(PlacesText.empty.value)
                    .journalFont(size: PlacesStyle.noteSize, relativeTo: .caption)
                    .foregroundColor(JournalStyle.Color.secondary)
                    .padding(.vertical, JournalStyle.Space.card)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                savedRows
            }
        }
        .padding(.horizontal, PlacesStyle.rowInset)
        .padding(.vertical, JournalStyle.Space.tight)
        .background(JournalStyle.Color.surface, in: RoundedRectangle(cornerRadius: PlacesStyle.groupRadius))
        .padding(.top, PlacesStyle.groupTop)
    }

    private var savedRows: some View {
        ForEach(repository.saved) { place in
            savedRow(place)
            if place.id != repository.saved.last?.id { Divider().overlay(JournalStyle.Color.line) }
        }
    }

    private func savedRow(_ place: Place) -> some View {
        HStack(spacing: JournalStyle.Space.small) {
            Button {
                select(place)
            } label: {
                Text(verbatim: place.name)
                    .journalFont(size: PlacesStyle.bodySize, weight: isSelected(place) ? .semibold : .regular)
                    .foregroundColor(isSelected(place) ? JournalStyle.Color.accent : JournalStyle.Color.ink)
                    .frame(maxWidth: .infinity, minHeight: PlacesStyle.rowHeight, alignment: .leading)
                    .contentShape(Rectangle())
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
            JournalIcon(name: JournalAsset.remove, size: PlacesStyle.iconSize)
                .foregroundColor(JournalStyle.Color.accent)
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
                Text(editing ? PlacesText.done.value : PlacesText.edit.value)
                    .journalFont(size: PlacesStyle.actionSize)
                    .frame(minHeight: JournalStyle.Size.touchTarget)
            }
            .foregroundColor(JournalStyle.Color.accent)
        }
    }

    private func isSelected(_ place: Place) -> Bool { !isDeviceSelected && selectedPlaceID == place.id }

    private func remove(_ place: Place) {
        removing = true
        Task {
            _ = await repository.remove(place.id)
            removing = false
        }
    }
}

/// 搜索候选摘要保留地区层级和查看动作，收藏行另按选择状态展示。
struct PlaceRow: View {
    let place: Place
    let showsChevron: Bool

    init(place: Place, showsChevron: Bool = true) {
        self.place = place
        self.showsChevron = showsChevron
    }

    var body: some View {
        HStack(spacing: JournalStyle.Space.item) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: place.name).journalFont(size: PlacesStyle.bodySize)
                if !place.region.isEmpty {
                    Text(verbatim: place.region)
                        .journalFont(size: PlacesStyle.noteSize, relativeTo: .caption)
                        .foregroundColor(JournalStyle.Color.secondary)
                }
            }
            Spacer(minLength: JournalStyle.Space.item)
            if showsChevron {
                Text(PlacesText.view.value)
                    .journalFont(size: PlacesStyle.resultActionSize)
                    .foregroundColor(JournalStyle.Color.accent)
            }
        }
        .foregroundColor(JournalStyle.Color.ink)
        .padding(.vertical, JournalStyle.Space.small)
        .frame(minHeight: PlacesStyle.resultHeight)
        .contentShape(Rectangle())
    }
}

#if DEBUG
    @MainActor
    private struct PlacesView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                scene(.ready).previewDisplayName("地区列表")
                scene(.empty).previewDisplayName("地区列表 · 空态")
                scene(.ready).environment(\.dynamicTypeSize, .accessibility3).previewDisplayName("地区 · 大字号")
                PlaceRow(place: PlacesPreviewData.city)
                    .padding(JournalStyle.Space.page).previewLayout(.sizeThatFits).previewDisplayName("地区摘要")
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
