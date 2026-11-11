import Foundation

struct Coordinates: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

enum LocationProblem: Error, Equatable {
    case denied
    case unavailable
}

/// 权限检查与请求授权分开；未知状态只允许由用户操作发起系统授权。
enum LocationAuthorization: Equatable {
    case authorized
    case notDetermined
    case denied
}
