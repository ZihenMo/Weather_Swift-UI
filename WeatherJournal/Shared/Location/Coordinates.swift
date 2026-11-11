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
