import Foundation
import UIKit

struct AppConfiguration {
    enum Key {
        static let forecastURL = "ForecastServiceURL"
        static let searchURL = "PlaceSearchServiceURL"
        static let attributionURL = "WeatherAttributionURL"
    }

    let forecastURL: URL
    let searchURL: URL
    let attributionURL: URL
    let requestTimeout: TimeInterval

    static func load(values: [String: Any]) throws -> AppConfiguration {
        func url(_ key: String) throws -> URL {
            guard let raw = values[key] as? String, let value = URL(string: raw),
                value.scheme == NetworkContract.secureScheme, value.host != nil,
                value.user == nil, value.password == nil
            else { throw ConfigurationError.invalidValue(key) }
            return value
        }
        return try AppConfiguration(
            forecastURL: url(Key.forecastURL), searchURL: url(Key.searchURL),
            attributionURL: url(Key.attributionURL), requestTimeout: AppConstants.requestTimeout)
    }
}

enum ConfigurationError: Error { case invalidValue(String) }

enum AppConstants {
    static var settingsURL: URL? { URL(string: UIApplication.openSettingsURLString) }
    static let disableLiveServices = "WJ_DISABLE_LIVE_SERVICES"
    static let enabledFlag = "1"
    static let logSubsystem = "WeatherJournal"
    static let requestTimeout: TimeInterval = 15
    static let sessionFileName = "last_selection_v1.json"
    static let sessionVersion = 1
    static let diagnosticsCategory = "runtime"
}
