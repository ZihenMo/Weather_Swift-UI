import CoreLocation
import Foundation

/// 将系统代理回调转换为单次异步取位，并按时间戳排除过期位置。
@MainActor
final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    private var result: CheckedContinuation<Coordinates, Error>?
    private var deadline: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private let makeManager: @MainActor () -> CLLocationManager
    private let geocode: (CLLocation, Locale) async throws -> [CLPlacemark]
    private let policy: PlacesPolicy
    private let now: () -> Date
    private let sleep: (UInt64) async throws -> Void
    private let diagnostics: DiagnosticSink
    private lazy var authorizationReader = makeManager()

    var authorization: LocationAuthorization {
        switch (manager ?? authorizationReader).authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    init(
        makeManager: @escaping @MainActor () -> CLLocationManager,
        geocode: @escaping (CLLocation, Locale) async throws -> [CLPlacemark],
        policy: PlacesPolicy, now: @escaping () -> Date,
        sleep: @escaping (UInt64) async throws -> Void, diagnostics: DiagnosticSink
    ) {
        self.makeManager = makeManager
        self.geocode = geocode
        self.policy = policy
        self.now = now
        self.sleep = sleep
        self.diagnostics = diagnostics
        super.init()
    }

    func locate() async throws -> Coordinates {
        guard result == nil else { throw LocationProblem.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            result = continuation
            let request = makeManager()
            manager = request
            request.delegate = self
            request.desiredAccuracy = policy.locationAccuracy
            if request.authorizationStatus == .notDetermined {
                request.requestWhenInUseAuthorization()
            } else {
                locationManagerDidChangeAuthorization(request)
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager === self.manager else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            guard deadline == nil else { return }
            // 授权等待不计入取位期限，用户完成权限选择后再启动截止任务。
            deadline = Task {
                do { try await sleep(policy.locationTimeoutNanoseconds) } catch { return }
                finish(.failure(LocationProblem.unavailable))
            }
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(LocationProblem.denied))
        case .notDetermined:
            break
        @unknown default:
            finish(.failure(LocationProblem.unavailable))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard manager === self.manager else { return }
        guard authorization == .authorized else {
            finish(.failure(authorization == .denied ? LocationProblem.denied : LocationProblem.unavailable))
            return
        }
        guard
            let fix = locations.last(where: {
                $0.horizontalAccuracy >= 0 && CLLocationCoordinate2DIsValid($0.coordinate)
                    && (0...policy.maximumLocationAge).contains(now().timeIntervalSince($0.timestamp))
            })
        else {
            retry?.cancel()
            retry = Task { [weak self, sleep, policy] in
                do { try await sleep(policy.locationRetryNanoseconds) } catch { return }
                guard let self, manager === self.manager else { return }
                manager.requestLocation()
            }
            return
        }
        finish(.success(Coordinates(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard manager === self.manager else { return }
        diagnostics.record(.location, error)
        let denied = (error as? CLError)?.code == .denied
        finish(.failure(denied ? LocationProblem.denied : LocationProblem.unavailable))
    }

    private func finish(_ outcome: Result<Coordinates, Error>) {
        retry?.cancel()
        retry = nil
        deadline?.cancel()
        deadline = nil
        manager?.delegate = nil
        manager?.stopUpdatingLocation()
        manager = nil
        let pending = result
        result = nil
        pending?.resume(with: outcome)
    }

    func district(at point: Coordinates, language: String) async -> String? {
        let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let marks: [CLPlacemark]
        do { marks = try await geocode(location, Locale(identifier: language)) } catch {
            diagnostics.record(.geocoding, error)
            return nil
        }
        for mark in marks {
            for field in [mark.subLocality, mark.subAdministrativeArea, mark.locality, mark.administrativeArea] {
                if let name = field?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
            }
        }
        return nil
    }
}
