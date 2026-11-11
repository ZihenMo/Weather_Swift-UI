import Foundation

struct Place: Identifiable, Equatable {
    let id: Int
    let name: String
    let region: String
    let point: Coordinates
}
