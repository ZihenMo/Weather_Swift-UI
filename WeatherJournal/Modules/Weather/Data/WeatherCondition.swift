enum WeatherCondition: Equatable {
    case clear, cloudy, fog, snow, thunderstorm, rain, unknown

    init(code: Int?) {
        switch code.flatMap(WMOCode.init(rawValue:)) {
        case .clear, .mainlyClear: self = .clear
        case .partlyCloudy, .overcast: self = .cloudy
        case .fog, .rimeFog: self = .fog
        case .slightSnow, .moderateSnow, .heavySnow, .snowGrains, .slightSnowShowers, .heavySnowShowers: self = .snow
        case .thunderstorm, .thunderstormSlightHail, .heavyThunderstorm, .thunderstormHeavyHail: self = .thunderstorm
        case .lightDrizzle, .moderateDrizzle, .denseDrizzle, .lightFreezingDrizzle, .denseFreezingDrizzle,
            .slightRain, .moderateRain, .heavyRain, .lightFreezingRain, .heavyFreezingRain,
            .slightShowers, .moderateShowers, .violentShowers:
            self = .rain
        case .none: self = .unknown
        }
    }
}
