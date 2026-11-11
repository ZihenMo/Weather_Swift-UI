import Combine
import Foundation

/// 每次关键词变化立即取消上一任务，防抖只延迟新请求，不延迟旧结果失效。
@MainActor
final class PlaceSearchModel: ObservableObject {
    enum State {
        case idle, loading
        case results([Place])
        case failed
    }

    @Published private(set) var state: State = .idle
    private let delay: UInt64
    private let sleep: (UInt64) async throws -> Void
    private let find: (String, String) async throws -> [Place]
    private var request: Task<Void, Never>?

    init(
        find: @escaping (String, String) async throws -> [Place], delay: UInt64,
        sleep: @escaping (UInt64) async throws -> Void
    ) {
        self.find = find
        self.delay = delay
        self.sleep = sleep
    }

    @discardableResult
    func search(_ raw: String, language: String) -> Task<Void, Never>? {
        request?.cancel()
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state = .idle
            request = nil
            return nil
        }
        state = .loading
        let task = Task { [weak self, find, delay, sleep] in
            do {
                try await sleep(delay)
                let items = try await find(query, language)
                guard !Task.isCancelled else { return }
                self?.state = .results(items)
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .failed
            }
        }
        request = task
        return task
    }

    deinit { request?.cancel() }
}
