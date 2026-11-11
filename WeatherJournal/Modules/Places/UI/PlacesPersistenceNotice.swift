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
            ProgressView(PlacesText.saving.value).padding(AppSpacing.medium)
        } else if repository.recovery == .loading {
            ProgressView(PlacesText.loading.value).padding(AppSpacing.medium)
        }
    }

    private var warning: some View {
        AppNotice(repository.recovery == .failed ? PlacesText.recoveryFailed.value : PlacesText.unsaved.value) {
            recoveryActions
        }
    }

    private var recoveryActions: some View {
        VStack(alignment: .leading, spacing: 0) {
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

#if DEBUG
    @MainActor
    private struct PlacesPersistenceNotice_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                PlacesPreviewScene(.readFailure) { repository in
                    PlacesPersistenceNotice(repository: repository, allowsRebuild: true)
                }
                .previewDisplayName("收藏读取失败")
                PlacesPreviewScene(.writeFailure) { repository in
                    PlacesPersistenceNotice(repository: repository)
                }
                .previewDisplayName("收藏尚未保存")
            }
            .frame(width: JournalPreview.contentWidth)
            .previewLayout(.sizeThatFits)
        }
    }
#endif
