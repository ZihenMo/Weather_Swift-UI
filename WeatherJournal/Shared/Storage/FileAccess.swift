import Foundation

/// 同步文件操作由存储 actor 执行，页面不直接接触磁盘。
struct FileAccess {
    let read: (URL) throws -> Data
    let write: (Data, URL) throws -> Void
    let copy: (URL, URL) throws -> Void
}

enum StorageError: Error {
    case unsupportedVersion(Int)
    case invalidRecord
    case missingDirectory
}
