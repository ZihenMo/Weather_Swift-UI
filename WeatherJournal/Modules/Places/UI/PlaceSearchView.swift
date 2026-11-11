import SwiftUI

/// 搜索页保留关键词和焦点，查询结果与取消逻辑由模型管理。
struct PlaceSearchView: View {
    @Environment(\.locale) private var locale
    @StateObject private var model: PlaceSearchModel
    @State private var query = ""
    @State private var hasAppeared = false
    @FocusState private var focused: Bool

    let preview: (Place) -> Void

    init(
        find: @escaping (String, String) async throws -> [Place], delay: UInt64,
        sleep: @escaping (UInt64) async throws -> Void, preview: @escaping (Place) -> Void
    ) {
        _model = StateObject(wrappedValue: PlaceSearchModel(find: find, delay: delay, sleep: sleep))
        self.preview = preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JournalStyle.Space.card) {
            searchField
            PlaceSearchResults(state: model.state, select: select, retry: retry)
            Spacer(minLength: 0)
        }
        .padding(JournalStyle.Space.page)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(JournalStyle.Color.background.ignoresSafeArea())
        .navigationTitle(PlacesText.search.value)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: focusOnFirstAppearance)
        .onChange(of: query) { model.search($0, language: language) }
        .onChange(of: language) { model.search(query, language: $0) }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: JournalSymbol.search).foregroundColor(JournalStyle.Color.secondary)
            TextField(PlacesText.query.value, text: $query)
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
            }
        }
        .padding(JournalStyle.Space.card)
        .journalCard()
    }

    private var language: String { JournalLocalization.language(for: locale) }

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

/// 将搜索结果区域与输入框分开，便于独立检查空态和错误态。
private struct PlaceSearchResults: View {
    let state: PlaceSearchModel.State
    let select: (Place) -> Void
    let retry: () -> Void

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView(PlacesText.searching.value).frame(maxWidth: .infinity).padding()
        case .failed:
            Button(PlacesText.searchFailed.value, action: retry).frame(maxWidth: .infinity).padding()
        case .results(let items) where items.isEmpty:
            Text(PlacesText.noMatches.value)
                .foregroundColor(JournalStyle.Color.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        case .results(let items):
            results(items)
        }
    }

    private func results(_ items: [Place]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { place in
                    resultRow(place)
                    if place.id != items.last?.id { Divider() }
                }
            }
            .padding(.horizontal, JournalStyle.Space.card)
            .journalCard()
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
