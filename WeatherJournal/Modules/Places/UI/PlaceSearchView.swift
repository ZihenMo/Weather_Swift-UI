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
        VStack(alignment: .leading, spacing: JournalStyle.Space.card) {
            heading
            searchField
            PlaceSearchResults(state: model.state, presets: presets, select: select, retry: retry)
        }
        .padding(.horizontal, PlacesStyle.panelInset)
        .padding(.bottom, PlacesStyle.panelInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(JournalStyle.Color.panel)
        .onAppear(perform: focusOnFirstAppearance)
        .onChange(of: query) { model.search($0, language: language) }
        .onChange(of: language) { model.search(query, language: $0) }
    }

    private var heading: some View {
        HStack {
            Text(PlacesText.search.value)
                .journalFont(size: PlacesStyle.sheetTitleSize, weight: .semibold, relativeTo: .title3)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: JournalStyle.Space.item)
            Button(CommonText.cancel.value, action: close)
                .journalFont(size: PlacesStyle.actionSize)
                .foregroundColor(JournalStyle.Color.accent)
                .frame(minHeight: JournalStyle.Size.touchTarget)
        }
    }

    private var searchField: some View {
        HStack(spacing: JournalStyle.Space.item) {
            TextField(PlacesText.query.value, text: $query)
                .journalFont(size: PlacesStyle.inputSize)
                .focused($focused)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .accessibilityIdentifier(PlacesIdentifier.query)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: JournalSymbol.clear).accessibilityLabel(Text(PlacesText.clearSearch.value))
                }
                .foregroundColor(JournalStyle.Color.secondary)
            }
        }
        .padding(JournalStyle.Space.card)
        .background(JournalStyle.Color.field, in: RoundedRectangle(cornerRadius: PlacesStyle.fieldRadius))
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
            ProgressView(PlacesText.searching.value).frame(maxWidth: .infinity).padding(JournalStyle.Space.page)
        case .failed:
            Button(PlacesText.searchFailed.value, action: retry)
                .frame(maxWidth: .infinity).padding(JournalStyle.Space.page)
        case .results(let items) where items.isEmpty:
            Text(PlacesText.noMatches.value)
                .journalFont(size: PlacesStyle.bodySize)
                .foregroundColor(JournalStyle.Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(JournalStyle.Space.page)
        case .results(let items):
            results(items, title: PlacesText.results.value)
        }
    }

    private func results(_ items: [Place], title: LocalizedStringKey) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .journalFont(size: PlacesStyle.noteSize, relativeTo: .caption)
                    .foregroundColor(JournalStyle.Color.secondary)
                    .accessibilityAddTraits(.isHeader)
                resultRows(items)
            }
        }
    }

    private func resultRows(_ items: [Place]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { place in
                resultRow(place)
                if place.id != items.last?.id { Divider().overlay(JournalStyle.Color.line) }
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
