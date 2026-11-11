import SwiftUI

/// 搜索页保留关键词和焦点；空关键词展示预置地区，查询取消与防抖由模型管理。
struct PlaceSearchView: View {
    @Environment(\.locale) private var locale
    @StateObject private var model: PlaceSearchModel
    @State private var query = ""
    @State private var hasAppeared = false
    @FocusState private var focused: Bool

    let preview: (Place) -> Void
    let close: () -> Void

    init(
        find: @escaping (String, String) async throws -> [Place], delay: UInt64,
        sleep: @escaping (UInt64) async throws -> Void, preview: @escaping (Place) -> Void,
        close: @escaping () -> Void = {}
    ) {
        _model = StateObject(wrappedValue: PlaceSearchModel(find: find, delay: delay, sleep: sleep))
        self.preview = preview
        self.close = close
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            heading
            searchField
            PlaceSearchResults(state: model.state, presets: presets, select: select, retry: retry)
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.bottom, AppSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.surfaceRaised)
        .onAppear(perform: focusOnFirstAppearance)
        .onChange(of: query) { model.search($0, language: language) }
        .onChange(of: language) { model.search(query, language: $0) }
    }

    private var heading: some View {
        HStack {
            Text(PlacesText.search.value)
                .appFont(.large, weight: .semibold)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: AppSpacing.small)
            Button(CommonText.cancel.value, action: close)
                .buttonStyle(AppButtonStyle(.plain))
                .fixedSize(horizontal: true, vertical: true)
        }
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.small) {
            TextField(PlacesText.query.value, text: $query)
                .appFont(.medium)
                .focused($focused)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .accessibilityIdentifier(PlacesIdentifier.query)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: AppSymbol.clear).accessibilityLabel(Text(PlacesText.clearSearch.value))
                }
                .foregroundColor(AppColor.textSecondary)
            }
        }
        .padding(AppSpacing.medium)
        .background(AppColor.fill, in: RoundedRectangle(cornerRadius: AppRadius.small))
    }

    private var language: String { JournalLocalization.language(for: locale) }
    private var presets: [Place] { PlacesPresets.items(language: language) }

    private func focusOnFirstAppearance() {
        // 从概览返回时保留原搜索，不重新抢占键盘焦点。
        guard !hasAppeared else { return }
        focused = true
        hasAppeared = true
    }

    private func select(_ place: Place) {
        focused = false
        preview(place)
    }

    private func retry() { model.search(query, language: language) }
}

/// 结果标题和行样式统一覆盖预置、在线结果与错误恢复。
private struct PlaceSearchResults: View {
    let state: PlaceSearchModel.State
    let presets: [Place]
    let select: (Place) -> Void
    let retry: () -> Void

    var body: some View {
        switch state {
        case .idle:
            results(presets, title: PlacesText.examples.value)
        case .loading:
            ProgressView(PlacesText.searching.value).frame(maxWidth: .infinity).padding(AppSpacing.large)
        case .failed:
            ScrollView { failureNotice }
        case .results(let items) where items.isEmpty:
            Text(PlacesText.noMatches.value)
                .appFont(.medium)
                .foregroundColor(AppColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.large)
        case .results(let items):
            results(items, title: PlacesText.results.value)
        }
    }

    private var failureNotice: some View {
        AppNotice(PlacesText.searchFailed.value) {
            Button(CommonText.retry.value, action: retry)
        }
    }

    private func results(_ items: [Place], title: LocalizedStringKey) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .appFont(.caption)
                    .foregroundColor(AppColor.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                resultRows(items)
            }
        }
    }

    private func resultRows(_ items: [Place]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { place in
                resultRow(place)
                if place.id != items.last?.id { Divider().overlay(AppColor.border) }
            }
        }
    }

    private func resultRow(_ place: Place) -> some View {
        Button {
            select(place)
        } label: {
            PlaceRow(place: place)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(PlacesIdentifier.candidate(place.id))
    }
}

#if DEBUG
    @MainActor
    private struct PlaceSearchView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                PlaceSearchView(
                    find: PlacesPreviewData.search, delay: PlacesPolicy.standard.searchDelayNanoseconds,
                    sleep: { try await Task.sleep(nanoseconds: $0) }, preview: { _ in }
                )
                .previewDisplayName("搜索 · 预置地区")
                PlaceSearchResults(
                    state: .results(PlacesPreviewData.saved), presets: [], select: { _ in }, retry: {}
                )
                .previewDisplayName("搜索结果")
                PlaceSearchResults(state: .results([]), presets: [], select: { _ in }, retry: {})
                    .previewLayout(.sizeThatFits).previewDisplayName("搜索 · 无匹配")
                PlaceSearchResults(state: .failed, presets: [], select: { _ in }, retry: {})
                    .previewLayout(.sizeThatFits).previewDisplayName("搜索 · 失败")
                PlaceSearchView(
                    find: PlacesPreviewData.search, delay: PlacesPolicy.standard.searchDelayNanoseconds,
                    sleep: { try await Task.sleep(nanoseconds: $0) }, preview: { _ in }
                )
                .environment(\.dynamicTypeSize, .accessibility3).previewDisplayName("搜索 · 大字号")
            }
            .journalPreview()
        }
    }
#endif
