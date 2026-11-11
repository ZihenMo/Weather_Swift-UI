import Foundation

/// 业务模块仅提交事件与错误，由装配层选择具体诊断方式。
struct DiagnosticSink {
    enum Event: String {
        case network, forecastDecode, forecastCacheRead, forecastCacheWrite
        case forecastCacheHit, forecastCacheSaved
        case placesRead, placesWrite, placesRebuild, location, geocoding, sessionRead, sessionWrite, configuration
    }
    let record: (Event, Error) -> Void
    let information: (Event) -> Void

    init(information: @escaping (Event) -> Void = { _ in }, record: @escaping (Event, Error) -> Void) {
        self.information = information
        self.record = record
    }

    static let silent = DiagnosticSink { _, _ in }
}
