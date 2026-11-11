import CoreLocation
import Foundation

struct PlacesPolicy {
    let locationTimeoutNanoseconds: UInt64
    let locationRetryNanoseconds: UInt64
    let maximumLocationAge: TimeInterval
    let locationAccuracy: CLLocationAccuracy
    let searchDelayNanoseconds: UInt64
    let nameCacheCapacity: Int
    let failedNameRetryInterval: TimeInterval

    static let standard = PlacesPolicy(
        locationTimeoutNanoseconds: 12_000_000_000, locationRetryNanoseconds: 1_000_000_000, maximumLocationAge: 60,
        locationAccuracy: kCLLocationAccuracyHundredMeters, searchDelayNanoseconds: 250_000_000,
        nameCacheCapacity: 128, failedNameRetryInterval: 60)
}

enum PlacesContract {
    // 沿用原文件路径，格式版本由文件内容声明，避免升级后遗漏旧收藏。
    static let fileName = "saved_places_v1.json"
    static let schemaVersion = 2
    static let backupExtension = "backup"
    static let searchLimit = 20
    static let regionSeparator = " · "
    static let languageSeparator = "-"
    enum Query {
        static let name = "name", language = "language", count = "count"
    }
}
