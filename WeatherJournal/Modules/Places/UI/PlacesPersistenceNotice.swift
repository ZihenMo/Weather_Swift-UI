import SwiftUI

/// 首页与地点列表共用的保存提示；页面只负责展示和确认重建。
struct PlacesPersistenceNotice: View {
    @ObservedObject var repository: PlacesRepository
    @State private var confirmingRebuild = false

    var allowsRebuild = false

    var body: some View {
        noticeContent
            .alert(PlacesText.rebuild.value, isPresented: $confirmingRebuild) {
                Button(CommonText.cancel.value, role: .cancel) {}
                Button(PlacesText.rebuild.value, role: .destructive, action: rebuild)
            } message: {
                Text(PlacesText.rebuildMessage.value)
            }
    }

    @ViewBuilder private var noticeContent: some View {
        if repository.recovery == .failed || repository.persistence == .unsaved {
            warning
        } else if repository.persistence == .saving {
            ProgressView(PlacesText.saving.value).padding(JournalStyle.Space.card)
        } else if repository.recovery == .loading {
            ProgressView(PlacesText.loading.value).padding(JournalStyle.Space.card)
        }
    }

    private var warning: some View {
        VStack(alignment: .leading, spacing: JournalStyle.Space.item) {
            Text(repository.recovery == .failed ? PlacesText.recoveryFailed.value : PlacesText.unsaved.value)
                .font(JournalStyle.Font.callout)
            recoveryActions
        }
        .padding(JournalStyle.Space.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JournalStyle.Color.warning, in: RoundedRectangle(cornerRadius: JournalStyle.Radius.notice))
    }

    private var recoveryActions: some View {
        HStack {
            Button(
                repository.recovery == .failed ? PlacesText.retryRead.value : PlacesText.retrySave.value, action: retry)
            if allowsRebuild, repository.recovery == .failed {
                Button(PlacesText.rebuild.value, role: .destructive) { confirmingRebuild = true }
            }
        }
        .disabled(repository.recovery == .loading)
    }

    private func retry() { Task { await repository.retryPersistence() } }
    private func rebuild() { Task { await repository.rebuild() } }
}
