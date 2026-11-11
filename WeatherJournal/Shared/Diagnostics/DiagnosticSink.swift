import Foundation

/// 业务模块仅提交事件与错误，由装配层选择具体诊断方式。
struct DiagnosticSink {
    enum Event: String {
        case network, forecastDecode, forecastCacheRead, forecastCacheWrite
        case placesRead, placesWrite, placesRebuild, location, geocoding, sessionRead, sessionWrite, configuration
    }
    let record: (Event, Error) -> Void

    static let silent = DiagnosticSink { _, _ in }
}
