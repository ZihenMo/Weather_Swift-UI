import SwiftUI

/// 收藏列表观察仓库的长期状态，选择与定位摘要由 App 注入，编辑状态归页面所有。
struct PlacesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
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
                    .appFont(.caption)
                    .foregroundColor(AppColor.textSecondary)
                currentLocationButton
                savedHeading
                savedContent
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.bottom, AppSpacing.large)
        }
        .background(AppColor.background.ignoresSafeArea())
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
                    AppIcon(name: .back, size: .small)
                }
                .appFont(.medium)
                .frame(minHeight: 44)
            }
            .foregroundColor(AppColor.accent)
            Text(PlacesText.title.value)
                .appFont(.pageTitle, weight: .semibold)
                .frame(minHeight: 48, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var searchButton: some View {
        Button(action: search) {
            Label {
                Text(PlacesText.query.value)
            } icon: {
                AppIcon(name: .search)
            }
            .appFont(.medium)
            .foregroundColor(AppColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.medium)
            .background(AppColor.fill, in: RoundedRectangle(cornerRadius: AppRadius.small))
        }
        .buttonStyle(.plain)
        .padding(.top, AppSpacing.small)
        .padding(.bottom, AppSpacing.xLarge)
        .accessibilityIdentifier(PlacesIdentifier.search)
    }

    private var currentLocationButton: some View {
        Button {
            select(nil)
        } label: {
            AppCard {
                locationContent
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .frame(minHeight: 48)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, AppSpacing.small)
        .padding(.bottom, AppSpacing.xLarge)
        .accessibilityIdentifier(PlacesIdentifier.device)
    }

    @ViewBuilder private var locationContent: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                locationName
                locationNote
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: AppSpacing.xSmall) {
                locationName
                Spacer(minLength: AppSpacing.xSmall)
                locationNote
            }
        }
    }

    private var locationName: some View {
        HStack(spacing: AppSpacing.xSmall) {
            AppIcon(name: .location)
            Text(verbatim: deviceName ?? CommonText.currentLocation.string)
                .appFont(.medium, weight: isDeviceSelected ? .semibold : .regular)
        }
        .foregroundColor(isDeviceSelected ? AppColor.accent : AppColor.textPrimary)
    }

    private var locationNote: some View {
        Text(verbatim: deviceStatus ?? (deviceName == nil ? "" : CommonText.currentLocation.string))
            .appFont(.caption).foregroundColor(AppColor.textSecondary)
    }

    private var savedHeading: some View {
        HStack {
            Text(PlacesText.saved.value)
                .appFont(.medium, weight: .semibold)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: AppSpacing.small)
            editButton
        }
    }

    @ViewBuilder private var savedContent: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 0) {
                if repository.saved.isEmpty {
                    Text(PlacesText.empty.value)
                        .appFont(.caption)
                        .foregroundColor(AppColor.textSecondary)
                        .padding(.vertical, AppSpacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    savedRows
                }
            }
            .padding(.horizontal, AppSpacing.medium)
        }
        .padding(.top, AppSpacing.small)
    }

    private var savedRows: some View {
        ForEach(repository.saved) { place in
            savedRow(place)
            if place.id != repository.saved.last?.id { Divider().overlay(AppColor.border) }
        }
    }

    private func savedRow(_ place: Place) -> some View {
        HStack(spacing: AppSpacing.xSmall) {
            Button {
                select(place)
            } label: {
                Text(verbatim: place.name)
                    .appFont(.medium, weight: isSelected(place) ? .semibold : .regular)
                    .foregroundColor(isSelected(place) ? AppColor.accent : AppColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
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
            AppIcon(name: .remove)
                .foregroundColor(AppColor.accent)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(Text(verbatim: PlacesText.removeNamed.format(place.name)))
        .disabled(removing)
        .accessibilityIdentifier(PlacesIdentifier.remove(place.id))
    }

    @ViewBuilder private var editButton: some View {
        if !repository.saved.isEmpty {
            Button {
                editing.toggle()
            } label: {
                Text(editing ? PlacesText.done.value : PlacesText.edit.value)
            }
            .buttonStyle(AppButtonStyle(.plain))
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
        HStack(spacing: AppSpacing.small) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: place.name).appFont(.medium)
                if !place.region.isEmpty {
                    Text(verbatim: place.region)
                        .appFont(.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            Spacer(minLength: AppSpacing.small)
            if showsChevron {
                Text(PlacesText.view.value)
                    .appFont(.small)
                    .foregroundColor(AppColor.accent)
            }
        }
        .foregroundColor(AppColor.textPrimary)
        .padding(.vertical, AppSpacing.xSmall)
        .frame(minHeight: 48)
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
                    .padding(AppSpacing.large).previewLayout(.sizeThatFits).previewDisplayName("地区摘要")
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
