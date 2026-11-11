enum PlacesIdentifier {
    static let list = "places", search = "open-search", query = "query", device = "device-place"
    static let closePreview = "close-preview", add = "add-place"
    static func candidate(_ id: Int) -> String { "candidate-\(id)" }
    static func saved(_ id: Int) -> String { "saved-\(id)" }
    static func remove(_ id: Int) -> String { "remove-\(id)" }
}
