import Foundation
import SwiftUI

enum JournalLocalization {
    static let supportedLanguages = ["zh-Hans", "zh-Hant", "en"]
    static let fallbackLanguage = "zh-Hans"
    static func language(for locale: Locale) -> String {
        Bundle.preferredLocalizations(from: supportedLanguages, forPreferences: [locale.identifier]).first
            ?? fallbackLanguage
    }
}

struct LocalizedText {
    let key: String
    var value: LocalizedStringKey { LocalizedStringKey(key) }
    var string: String { NSLocalizedString(key, comment: "") }
    func format(_ arguments: CVarArg...) -> String {
        String(format: string, locale: Locale.current, arguments: arguments)
    }
}

enum CommonText {
    static let currentLocation = LocalizedText(key: "Current location")
    static let choosePlace = LocalizedText(key: "Choose a place")
    static let retry = LocalizedText(key: "Retry")
    static let close = LocalizedText(key: "Close")
    static let cancel = LocalizedText(key: "Cancel")
    static let startupFailure = LocalizedText(key: "Unable to start the app.")
}
