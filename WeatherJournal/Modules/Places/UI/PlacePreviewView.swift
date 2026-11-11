import SwiftUI

/// 地点概览的导航外壳，天气内容由 App 注入。
struct PlacePreviewView<Content: View>: View {
    @ObservedObject var repository: PlacesRepository
    @State private var adding = false

    let place: Place
    let close: () -> Void
    let added: (PlacesRepository.SaveResult) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .navigationTitle(PlacesText.preview.value)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { closeButton }
                ToolbarItem(placement: .navigationBarTrailing) { addButton }
            }
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: JournalSymbol.close).accessibilityLabel(Text(CommonText.close.value))
        }
        .disabled(adding)
        .accessibilityIdentifier(PlacesIdentifier.closePreview)
    }

    private var addButton: some View {
        Button(action: add) {
            if isSaved { Text(PlacesText.added.value) } else { Text(PlacesText.add.value) }
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
