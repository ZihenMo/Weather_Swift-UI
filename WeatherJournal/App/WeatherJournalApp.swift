import Foundation
import SwiftUI

@main
@MainActor
struct WeatherJournalApp: App {
    private let dependencies: Result<AppDependencies, Error>?

    init() {
        #if DEBUG
            if ProcessInfo.processInfo.environment[AppConstants.disableLiveServices] == AppConstants.enabledFlag {
                dependencies = nil
                return
            }
        #endif
        dependencies = Result {
            try AppDependencies.live(configuration: AppConfiguration.load(values: Bundle.main.infoDictionary ?? [:]))
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch dependencies {
                case .none: Color.clear
                case .some(.success(let dependencies)): JournalRoot(dependencies: dependencies)
                case .some(.failure): Text(CommonText.startupFailure.value).padding(AppSpacing.xLarge)
                }
            }
            .appFont(.medium)
            .foregroundColor(AppColor.textPrimary)
            .tint(AppColor.accent)
            .preferredColorScheme(.light)
        }
    }
}
