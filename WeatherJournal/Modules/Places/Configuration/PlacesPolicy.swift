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

/// 地区列表与底部搜索、概览沿用原型的尺寸和排版节奏。
enum PlacesStyle {
    static let titleSize: CGFloat = 30
    static let sectionSize: CGFloat = 15
    static let sheetTitleSize: CGFloat = 21
    static let previewTitleSize: CGFloat = 15
    static let bodySize: CGFloat = 15
    static let inputSize: CGFloat = 16
    static let noteSize: CGFloat = 12
    static let actionSize: CGFloat = 14
    static let resultActionSize: CGFloat = 13
    static let backSize: CGFloat = 16
    static let titleHeight: CGFloat = 49
    static let backHeight: CGFloat = 44
    static let rowHeight: CGFloat = 48
    static let resultHeight: CGFloat = 45
    static let rowInset: CGFloat = 13
    static let groupRadius: CGFloat = 16
    static let searchRadius: CGFloat = 13
    static let fieldRadius: CGFloat = 12
    static let iconSize: CGFloat = 20
    static let searchBottom: CGFloat = 22
    static let groupBottom: CGFloat = 20
    static let groupTop: CGFloat = 10
    static let panelInset: CGFloat = 18
    static let addRadius: CGFloat = 18
    static let addHorizontalInset: CGFloat = 15
    static let addVerticalInset: CGFloat = 6
}
